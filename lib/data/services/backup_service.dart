import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_helper.dart';

class BackupService {
  /// Returns the path to the current database file.
  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'AbonaFlemoon', 'eakhow_elrab.db');
  }

  /// Creates a backup of the database to a user-chosen location.
  /// On desktop: uses saveFile dialog.
  /// On mobile: saves to Downloads/AbonaFlemoon/ or app documents.
  Future<String?> backupDatabase() async {
    try {
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('ملف قاعدة البيانات غير موجود');
      }

      final backupName = 'church_membership_backup_${DateTime.now().millisecondsSinceEpoch}.db';

      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile: save to a reliable directory
        String? savePath;

        if (Platform.isAndroid) {
          // Try external storage Downloads first
          try {
            final extDir = Directory('/storage/emulated/0/Download/ChurchMembership');
            if (!await extDir.exists()) {
              await extDir.create(recursive: true);
            }
            savePath = p.join(extDir.path, backupName);
          } catch (e) {
            // Fallback to app documents if Downloads creation fails (Android 11+ scoped storage)
            final dir = await getApplicationDocumentsDirectory();
            savePath = p.join(dir.path, backupName);
            debugPrint('Could not save to Downloads, falling back to app dir: $e');
          }
        } else {
          // iOS: use app documents
          final dir = await getApplicationDocumentsDirectory();
          savePath = p.join(dir.path, backupName);
        }

        await dbFile.copy(savePath);
        debugPrint('Backup created at: $savePath');
        return savePath;
      } else {
        // Desktop: use file picker save dialog
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
          fileName: backupName,
          type: FileType.custom,
          allowedExtensions: ['db'],
        );

        if (result == null) return null; // User cancelled

        String savePath = result;
        if (!savePath.endsWith('.db')) {
          savePath = '$savePath.db';
        }

        await dbFile.copy(savePath);
        debugPrint('Backup created at: $savePath');
        return savePath;
      }
    } catch (e) {
      debugPrint('Backup error: $e');
      rethrow;
    }
  }

  /// Restores the database from a user-chosen .db file.
  /// Returns true on success, false if cancelled.
  Future<bool> restoreDatabase() async {
    try {
      // Let the user pick a .db file
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف النسخة الاحتياطية (.db)',
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return false;

      final pickedPath = result.files.single.path;
      if (pickedPath == null) return false;

      final sourceFile = File(pickedPath);
      if (!await sourceFile.exists()) {
        throw Exception('الملف المختار غير موجود');
      }

      // Validate it's a valid SQLite file by checking the header
      final bytes = await sourceFile.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(15));
      if (!header.startsWith('SQLite format')) {
        throw Exception('الملف المختار ليس ملف قاعدة بيانات صالح');
      }

      final dbPath = await getDatabasePath();

      // Close the current database connection
      await DatabaseHelper().closeDatabase();

      // Replace the database file
      await sourceFile.copy(dbPath);

      // Check the user_version. If it's 0 (e.g. from the Python converter script),
      // we set it to 3 so that SQLite won't run onCreate again, but WILL run onUpgrade.
      final rawDb = await openDatabase(dbPath);
      final versionResult = await rawDb.rawQuery('PRAGMA user_version');
      int currentVersion = 0;
      if (versionResult.isNotEmpty) {
        currentVersion = versionResult.first.values.first as int;
      }
      if (currentVersion == 0) {
        await rawDb.execute('PRAGMA user_version = 3');
      }
      await rawDb.close();

      // Re-initialize the database
      await DatabaseHelper().database;

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
    // Tables to clear (everything except users, icon, inter_icon)
    final tablesToClear = [
      'masrofat', 'count_2', 'count_aid', 'monasba', 'visits', 'eatraf',
      'person', 'osra', 'fathers', 'streets', 'areas',
      'karaba', 'mostwa', 'hala_egtimaia', 'hala_sehia', 'e_s', 'stage', 'khdma',
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

