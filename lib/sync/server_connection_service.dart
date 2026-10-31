import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/database_helper.dart';
import 'server_config.dart';
import 'signalr_sync_service.dart';

class ServerConnectionCheckResult {
  final bool isReachable;
  final int? statusCode;
  final String? engine;
  final String message;

  const ServerConnectionCheckResult({
    required this.isReachable,
    this.statusCode,
    this.engine,
    required this.message,
  });
}

class ServerConnectionService {
  static Future<ServerConnectionCheckResult> checkConnection(
    String rawUrl,
  ) async {
    try {
      final normalized = ServerConfig.normalizeUrl(rawUrl);
      final uri = Uri.parse('$normalized/api/auth/ping');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        String? engine;
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map) {
            if (![
              'ChurchMembership.SyncServer',
              'AbonaFlemoon.SyncServer',
            ].contains(data['app'])) {
              return const ServerConnectionCheckResult(
                isReachable: false,
                message:
                    'الرابط لا يخص العضوية الكنسية. استخدم المنفذ 5060 للعضوية الكنسية و5050 لمدارس الأحد.',
              );
            }
            engine = data['engine']?.toString();
          } else {
            throw const FormatException('Invalid server response');
          }
        } catch (_) {
          return const ServerConnectionCheckResult(
            isReachable: false,
            message: 'استجابة غير صالحة من سيرفر العضوية الكنسية.',
          );
        }
        return ServerConnectionCheckResult(
          isReachable: true,
          statusCode: 200,
          engine: engine,
          message: 'الاتصال بالسيرفر ناجح وقاعدة البيانات جاهزة ($engine)',
        );
      } else {
        return ServerConnectionCheckResult(
          isReachable: false,
          statusCode: response.statusCode,
          message: 'استجاب السيرفر برمز (${response.statusCode})',
        );
      }
    } catch (e) {
      return ServerConnectionCheckResult(
        isReachable: false,
        message: 'تعذر الوصول إلى السيرفر: $e',
      );
    }
  }
}

class ServerBootstrap {
  static Future<void> initialize() async {
    await ServerConfig.load();
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isWindows) {
      final installRoot = File(Platform.resolvedExecutable).parent.path;
      final backend = File(
        '$installRoot/Server/backend/ChurchMembership.SyncServer.exe',
      );
      if (await backend.exists() &&
          prefs.getString('sync_host_installation') != installRoot) {
        await ServerConfig.save(enabled: true, url: 'http://127.0.0.1:5060');
        await prefs.setString('sync_host_installation', installRoot);
        return;
      }
    }
    if (!prefs.containsKey('sync_server_enabled') && Platform.isWindows) {
      final check = await ServerConnectionService.checkConnection(
        'http://127.0.0.1:5060',
      );
      if (check.isReachable) {
        await ServerConfig.save(enabled: true, url: 'http://127.0.0.1:5060');
      }
    }
  }
}

class ServerConfigProvider extends ChangeNotifier {
  bool get isServerMode => ServerConfig.isServerMode;
  String get baseUrl => ServerConfig.baseUrl;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _lastError;
  String? get lastError => _lastError;

  ServerConfigProvider() {
    _initStatus();
  }

  Future<void> _initStatus() async {
    if (isServerMode) {
      final res = await ServerConnectionService.checkConnection(baseUrl);
      _isConnected = res.isReachable;
      _lastError = res.isReachable ? null : res.message;
      notifyListeners();
    }
  }

  Future<bool> applySettings({
    required bool enabled,
    required String url,
  }) async {
    final normalized = ServerConfig.normalizeUrl(url);

    if (enabled) {
      final check = await ServerConnectionService.checkConnection(normalized);
      if (!check.isReachable) {
        _lastError = check.message;
        _isConnected = false;
        notifyListeners();
        return false;
      }
      _isConnected = true;
      _lastError = null;
    } else {
      _isConnected = false;
      _lastError = null;
    }

    SignalRSyncService.instance.stop();
    await ServerConfig.save(enabled: enabled, url: normalized);

    // تبديل قاعدة البيانات فوراً
    await DatabaseHelper().reopenDatabase();

    // تشغيل أو إيقاف SignalR
    if (enabled) {
      SignalRSyncService.instance.start();
    } else {
      SignalRSyncService.instance.stop();
    }

    notifyListeners();
    return true;
  }
}
