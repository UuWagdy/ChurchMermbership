import 'dart:io';
import 'dart:convert';
import 'automatic_backup_service.dart';
import 'sqlite_backup_snapshot.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../sync/server_config.dart';
import '../database/database_helper.dart';

class BackupService {
  static Map<String, String> serverHeaders = {};
  static void setServerCredentials(String username, String password) {
    serverHeaders = {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    };
  }

  static final automatic = AutomaticBackupService(
    prefix: 'ChurchMembership',
    isServerMode: () => ServerConfig.isServerMode,
    serverUrl: () => ServerConfig.baseUrl,
    headers: () => serverHeaders,
    snapshot: createLocalSnapshot,
  );
  static Future<void> createLocalSnapshot(String target) async {
    if (ServerConfig.isServerMode)
      throw StateError('SQLite متاح في الوضع المحلي فقط.');
    final db = await DatabaseHelper().database;
    await createSqliteBackup(db, target);
  }

  Future<String> getDatabasePath() async => ServerConfig.isServerMode
      ? 'PostgreSQL (${ServerConfig.baseUrl})'
      : DatabaseHelper.getLocalDatabasePath();

  Future<String?> backupDatabase() async {
    final server = ServerConfig.isServerMode;
    final suffix = server ? 'dump' : 'db';
    final backupName =
        'ChurchMembership_${server ? 'postgresql' : 'sqlite'}_${DateTime.now().millisecondsSinceEpoch}.$suffix';
    final temp = await Directory.systemTemp.createTemp('membership-backup-');
    try {
      final snapshot = File(p.join(temp.path, backupName));
      if (server) {
        final response = await http
            .get(
              Uri.parse('${ServerConfig.baseUrl}/api/backups/download'),
              headers: serverHeaders,
            )
            .timeout(const Duration(minutes: 30));
        if (response.statusCode != 200)
          throw StateError(
            'فشل إنشاء نسخة PostgreSQL (${response.statusCode}): ${response.body}',
          );
        await snapshot.writeAsBytes(response.bodyBytes, flush: true);
      } else {
        await createLocalSnapshot(snapshot.path);
      }
      final bytes = await snapshot.readAsBytes();
      final target = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
        fileName: backupName,
        type: FileType.custom,
        allowedExtensions: [suffix],
        bytes: bytes,
      );
      if (target == null) return null;
      if (Platform.isAndroid || Platform.isIOS) return target;
      final output = target.toLowerCase().endsWith('.$suffix')
          ? target
          : '$target.$suffix';
      if (!server &&
          p.equals(
            p.normalize(File(output).absolute.path),
            p.normalize(
              File(await DatabaseHelper.getLocalDatabasePath()).absolute.path,
            ),
          ))
        throw StateError('اختر ملفًا مختلفًا عن قاعدة البيانات الحالية.');
      await File(output).writeAsBytes(bytes, flush: true);
      return output;
    } finally {
      await temp.delete(recursive: true);
    }
  }

  /// Restores the database from a user-chosen .db file.
  /// Returns true on success, false if cancelled.
  Future<bool> restoreDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر نسخة SQLite (.db) أو PostgreSQL (.dump)',
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return false;

      final pickedPath = result.files.single.path;
      if (pickedPath == null) return false;

      final sourceFile = File(pickedPath);
      if (!await sourceFile.exists()) {
        throw Exception('الملف المختار غير موجود');
      }

      final magic = await sourceFile
          .openRead(0, 16)
          .fold<List<int>>([], (a, b) => a..addAll(b));
      if (String.fromCharCodes(magic.take(5)) == 'PGDMP') {
        if (!ServerConfig.isServerMode)
          throw StateError('فعّل وضع السيرفر لاستعادة نسخة PostgreSQL.');
        final response = await http
            .post(
              Uri.parse('${ServerConfig.baseUrl}/api/backups/restore'),
              headers: {
                ...serverHeaders,
                'Content-Type': 'application/octet-stream',
              },
              body: await sourceFile.readAsBytes(),
            )
            .timeout(const Duration(minutes: 30));
        if (response.statusCode != 200)
          throw StateError('فشل استعادة PostgreSQL: ${response.body}');
        await DatabaseHelper().reopenDatabase();
        return true;
      }
      // Legacy SQLite backups remain accepted by the existing import route.
      final bytes = await sourceFile.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(15));
      if (!header.startsWith('SQLite format')) {
        throw Exception('الملف المختار ليس ملف قاعدة بيانات SQLite صالح');
      }

      // 1. في وضع السيرفر: رفع الملف إلى السيرفر
      if (ServerConfig.isServerMode) {
        final fileBytes = await sourceFile.readAsBytes();
        final url = Uri.parse(
          '${ServerConfig.baseUrl}/api/storage/sqlite/import',
        );
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/octet-stream'},
              body: fileBytes,
            )
            .timeout(const Duration(minutes: 5));

        if (response.statusCode != 200) {
          throw Exception(
            'فشل استيراد قاعدة البيانات إلى السيرفر: ${response.body}',
          );
        }
        return true;
      }

      // 2. في الوضع المحلي: استبدال الملف المحلي
      final dbPath = await getDatabasePath();

      // Close current connection
      await DatabaseHelper().closeDatabase();

      // Replace database file
      await sourceFile.copy(dbPath);

      // Verify or fix user_version
      try {
        final rawDb = await openDatabase(dbPath);
        final versionResult = await rawDb.rawQuery('PRAGMA user_version');
        int currentVersion = 0;
        if (versionResult.isNotEmpty) {
          currentVersion =
              (versionResult.first.values.first as num?)?.toInt() ?? 0;
        }
        if (currentVersion == 0) {
          await rawDb.execute('PRAGMA user_version = 10');
        }
        await rawDb.close();
      } catch (_) {}

      // Re-initialize database
      await DatabaseHelper().reopenDatabase();

      debugPrint('Database restored from: $pickedPath');
      return true;
    } catch (e) {
      debugPrint('Restore error: $e');
      rethrow;
    }
  }

  /// Factory reset: deletes all data except users and their permissions.
  Future<void> factoryReset() async {
    final db = await DatabaseHelper().database;
    final tablesToClear = [
      'masrofat',
      'count_2',
      'count_aid',
      'monasba',
      'visits',
      'eatraf',
      'person',
      'osra',
      'fathers',
      'streets',
      'areas',
      'karaba',
      'mostwa',
      'hala_egtimaia',
      'hala_sehia',
      'e_s',
      'stage',
      'khdma',
    ];

    for (final table in tablesToClear) {
      try {
        await db.delete(table);
        debugPrint('Cleared table: $table');
      } catch (e) {
        debugPrint('Error clearing $table: $e');
      }
    }
  }
}
