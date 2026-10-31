import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server owns its schedule. This coordinator schedules local SQLite only.
class AutomaticBackupService {
  AutomaticBackupService({
    required this.prefix,
    required this.isServerMode,
    required this.serverUrl,
    required this.headers,
    required this.snapshot,
    this.client,
  });
  final String prefix;
  final bool Function() isServerMode;
  final String Function() serverUrl;
  final Map<String, String> Function() headers;
  final Future<void> Function(String target) snapshot;
  final http.Client? client;
  Timer? _timer;
  bool _busy = false;
  static const _key = 'automatic_database_backup_v1';
  String get sourceIdentity =>
      isServerMode() ? 'server:${serverUrl()}' : 'local';

  void start() {
    _timer ??= Timer.periodic(const Duration(minutes: 15), (_) => _tick());
    unawaited(Future<void>.delayed(const Duration(seconds: 10), _tick));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (isServerMode() || _busy) return;
    try {
      final settings = await load();
      final last = DateTime.tryParse(
        settings['lastSuccessUtc'] as String? ?? '',
      );
      if (settings['enabled'] != false &&
          (last == null ||
              DateTime.now().toUtc().difference(last) >=
                  const Duration(days: 1))) {
        await runNow();
      }
    } catch (e) {
      debugPrint('Automatic backup: $e');
    }
  }

  Future<Map<String, dynamic>> load() async {
    if (isServerMode()) {
      return {...await _request('GET', 'settings'), '_source': sourceIdentity};
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      return {
        ...Map<String, dynamic>.from(jsonDecode(raw) as Map),
        '_source': sourceIdentity,
      };
    }
    return {
      'enabled': true,
      '_source': sourceIdentity,
      'retention': 30,
      'directory': p.join(
        (await getApplicationDocumentsDirectory()).path,
        '${prefix}_Backups',
      ),
    };
  }

  Future<void> _saveLocal(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode(settings))) {
      throw StateError('تعذر حفظ إعدادات النسخ الاحتياطي.');
    }
  }

  Future<void> configure(Map<String, dynamic> value) async {
    if (value['_source'] != null && value['_source'] != sourceIdentity) {
      throw StateError('تغير وضع الاتصال. أعد تحميل إعدادات النسخ قبل الحفظ.');
    }
    if (_busy) throw StateError('انتظر انتهاء النسخة الحالية.');
    if (isServerMode()) {
      await _request('PUT', 'settings', value);
      return;
    }
    final directory = value['directory'] as String;
    final retention = value['retention'] as int;
    if (!p.isAbsolute(directory) || retention < 1 || retention > 365) {
      throw ArgumentError('مجلد الحفظ أو عدد النسخ غير صحيح.');
    }
    await Directory(directory).create(recursive: true);
    final probe = File(
      p.join(
        directory,
        '.backup-write-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await probe.writeAsString('test');
    await probe.delete();
    final previous = await load();
    await _saveLocal({
      ...previous,
      ...value,
      'lastError': null,
      if (previous['directory'] != directory) 'lastSuccessUtc': null,
    });
  }

  Future<String> runNow() async {
    if (_busy) throw StateError('هناك نسخة احتياطية قيد التنفيذ.');
    _busy = true;
    File? partial;
    try {
      if (isServerMode()) {
        final settings = await _request('POST', 'run');
        return settings['lastPath'] as String;
      }
      final settings = await load();
      final directory = Directory(settings['directory'] as String);
      await directory.create(recursive: true);
      final name =
          '${prefix}_sqlite_auto_${DateTime.now().toUtc().microsecondsSinceEpoch}.db';
      final target = File(p.join(directory.path, name));
      partial = File('${target.path}.partial');
      await snapshot(partial.path);
      await partial.rename(target.path);
      partial = null;
      await _saveLocal({
        ...settings,
        'lastSuccessUtc': DateTime.now().toUtc().toIso8601String(),
        'lastPath': target.path,
        'lastError': null,
      });
      final copies = await directory
          .list()
          .where(
            (entry) =>
                entry is File &&
                p.basename(entry.path).startsWith('${prefix}_sqlite_auto_') &&
                entry.path.endsWith('.db'),
          )
          .cast<File>()
          .toList();
      copies.sort((a, b) => b.path.compareTo(a.path));
      for (final old in copies.skip(settings['retention'] as int? ?? 30)) {
        await old.delete();
      }
      return target.path;
    } catch (e) {
      if (!isServerMode()) {
        final settings = await load();
        await _saveLocal({...settings, 'lastError': e.toString()});
      }
      rethrow;
    } finally {
      if (partial != null && await partial.exists()) await partial.delete();
      _busy = false;
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String action, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(
      method,
      Uri.parse('${serverUrl()}/api/backups/$action'),
    );
    request.headers.addAll({...headers(), 'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await (client?.send(request) ?? request.send()).timeout(
        const Duration(minutes: 30),
      ),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'تعذر تنفيذ النسخ على السيرفر (${response.statusCode}): ${response.body}',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
