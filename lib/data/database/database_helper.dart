import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as mobile_sqflite;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Closes the database connection (used during restore).
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      path = join(exeDir, 'eakhow_elrab.db');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = join(dir.path, 'AbonaFlemoon', 'eakhow_elrab.db');
    }

    // Ensure directory exists
    final dbDir = Directory(dirname(path));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // Copy from assets if not exists
    if (!await File(path).exists()) {
      try {
        final byteData = await rootBundle.load('assets/database/eakhow_elrab.db');
        final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        await File(path).writeAsBytes(bytes);
        debugPrint('Copied database from assets to: $path');
      } catch (e) {
        debugPrint('Error copying database from assets: $e');
      }
    }

    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add صيانة النظام permission if it doesn't exist
      final existing = await db.query('icon', where: "icon_name = ?", whereArgs: ['صيانة النظام']);
      if (existing.isEmpty) {
        final iconId = await db.insert('icon', {'icon_name': 'صيانة النظام'});
        // Add permission entry for all existing users
        final users = await db.query('users');
        for (var user in users) {
          await db.insert('inter_icon', {
            'pass_id': user['pass_id'],
            'icon_id': iconId,
            'icon_name': 'صيانة النظام',
            'check_1': user['pass_id'] == 1 ? 1 : 0, // Admin gets it enabled by default
          });
        }
      }
    }
    if (oldVersion < 3) {
      // Add إدارة القوائم permission if it doesn't exist
      final existing = await db.query('icon', where: "icon_name = ?", whereArgs: ['إدارة القوائم']);
      if (existing.isEmpty) {
        final iconId = await db.insert('icon', {'icon_name': 'إدارة القوائم'});
        final users = await db.query('users');
        for (var user in users) {
          await db.insert('inter_icon', {
            'pass_id': user['pass_id'],
            'icon_id': iconId,
            'icon_name': 'إدارة القوائم',
            'check_1': user['pass_id'] == 1 ? 1 : 0,
          });
        }
      }
    }
    if (oldVersion < 4) {
      // Add new lookup columns to osra table
      try {
        await db.execute('ALTER TABLE osra ADD COLUMN hala_sehia_id INTEGER');
      } catch (e) {
        debugPrint('Column hala_sehia_id may already exist or error: $e');
      }
      try {
        await db.execute('ALTER TABLE osra ADD COLUMN mostwa_id INTEGER');
      } catch (e) {
        debugPrint('Column mostwa_id may already exist or error: $e');
      }
    }
    if (oldVersion < 5) {
      // Add national id to person table
      try {
        await db.execute('ALTER TABLE person ADD COLUMN rakm_komy TEXT');
      } catch (e) {
        debugPrint('Column rakm_komy may already exist in person: $e');
      }
      
      // Defensive check for osra rakm_komy if coming from very old conversion
      try {
        await db.execute('ALTER TABLE osra ADD COLUMN rakm_komy TEXT');
      } catch (e) {
        debugPrint('Column rakm_komy may already exist in osra: $e');
      }
    }
    if (oldVersion < 6) {
      // Add settings table for ID cards and other configurations
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            setting_key TEXT PRIMARY KEY,
            setting_value TEXT
          )
        ''');
      } catch (e) {
        debugPrint('Failed to create settings table or it already exists: $e');
      }
    }
    if (oldVersion < 7) {
      // Add print ID card permission
      try {
        int iconId = await db.insert('icon', {'icon_name': 'طباعة كارنيه'}, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (iconId == 0) {
          final res = await db.query('icon', where: 'icon_name = ?', whereArgs: ['طباعة كارنيه']);
          if (res.isNotEmpty) iconId = res.first['icon_id'] as int;
        }
        if (iconId > 0) {
          final users = await db.query('users');
          for (var user in users) {
             await db.insert('inter_icon', {
               'pass_id': user['pass_id'],
               'icon_id': iconId,
               'icon_name': 'طباعة كارنيه',
               'check_1': user['pass_id'] == 1 ? 1 : 0,
             }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      } catch (e) {
        debugPrint('Failed to insert طباعة كارنيه permission: $e');
      }
    }
    if (oldVersion < 8) {
      // Clean up old permissions and sync EXACTLY with Home Screen tabs
      try {
        await db.execute('DELETE FROM inter_icon');
        await db.execute('DELETE FROM icon');

        final exactTabs = [
          'إدراج أسر', 'مناطق وشوارع', 'آباء كهنة', 'مناسبات',
          'بحث', 'أعياد ميلاد', 'صلاحيات', 'حساب مساعدات',
          'تقرير اخوة الرب', 'خدمات', 'مصروفات', 'بحث مصروفات',
          'إدارة القوائم', 'طباعة كارنيه', 'صيانة النظام'
        ];

        for (var tab in exactTabs) {
          int iconId = await db.insert('icon', {'icon_name': tab});
          
          final users = await db.query('users');
          for (var user in users) {
             await db.insert('inter_icon', {
               'pass_id': user['pass_id'],
               'icon_id': iconId,
               'icon_name': tab,
               'check_1': user['pass_id'] == 1 ? 1 : 0, // only admin auto-enabled
             });
          }
        }
      } catch (e) {
        debugPrint('Failed to sync exact tabs permissions: $e');
      }
    }
    if (oldVersion < 9) {
      try {
        final newTabs = ['الافتقاد', 'ترحيل المراحل'];
        for (var tab in newTabs) {
          int iconId = await db.insert('icon', {'icon_name': tab}, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (iconId == 0) {
            final res = await db.query('icon', where: 'icon_name = ?', whereArgs: [tab]);
            if (res.isNotEmpty) iconId = res.first['icon_id'] as int;
          }
          if (iconId > 0) {
            final users = await db.query('users');
            for (var user in users) {
               await db.insert('inter_icon', {
                 'pass_id': user['pass_id'],
                 'icon_id': iconId,
                 'icon_name': tab,
                 'check_1': user['pass_id'] == 1 ? 1 : 0, // only admin auto-enabled
               }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to insert new permissions for version 9: $e');
      }
    }
    if (oldVersion < 10) {
      try {
        final tab = 'الاعتراف';
        int iconId = await db.insert('icon', {'icon_name': tab}, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (iconId == 0) {
          final res = await db.query('icon', where: 'icon_name = ?', whereArgs: [tab]);
          if (res.isNotEmpty) iconId = res.first['icon_id'] as int;
        }
        if (iconId > 0) {
          final users = await db.query('users');
          for (var user in users) {
             await db.insert('inter_icon', {
               'pass_id': user['pass_id'],
               'icon_id': iconId,
               'icon_name': tab,
               'check_1': 1, // enabled for all accounts automatically as requested
             }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      } catch (e) {
        debugPrint('Failed to insert الاعتراف permission for version 10: $e');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // ═══════════════════════════════════════════
    // Lookup Tables
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE IF NOT EXISTS areas (
        area_id INTEGER PRIMARY KEY AUTOINCREMENT,
        area_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS streets (
        street_id INTEGER PRIMARY KEY AUTOINCREMENT,
        street_name TEXT NOT NULL,
        area_id INTEGER NOT NULL,
        FOREIGN KEY (area_id) REFERENCES areas(area_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS karaba (
        karaba_id INTEGER PRIMARY KEY AUTOINCREMENT,
        karaba_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mostwa (
        mostwa_id INTEGER PRIMARY KEY AUTOINCREMENT,
        mostwa_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS hala_egtimaia (
        hala_egtimaia_id INTEGER PRIMARY KEY AUTOINCREMENT,
        hala_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS hala_sehia (
        hala_sehia_id INTEGER PRIMARY KEY AUTOINCREMENT,
        hala_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS e_s (
        e_s_id INTEGER PRIMARY KEY AUTOINCREMENT,
        e_s_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stage (
        stage_id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fathers (
        father_id INTEGER PRIMARY KEY AUTOINCREMENT,
        father_name TEXT NOT NULL,
        father_mobile TEXT,
        birth_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS khdma (
        khdma_id INTEGER PRIMARY KEY AUTOINCREMENT,
        khdma_name TEXT NOT NULL UNIQUE
      )
    ''');

    // ═══════════════════════════════════════════
    // Core Tables
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE IF NOT EXISTS osra (
        osra_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_name TEXT NOT NULL,
        karaba_id INTEGER,
        e_s_id INTEGER,
        area_id INTEGER,
        street_id INTEGER,
        dalil_name TEXT,
        emara TEXT,
        door TEXT,
        shaka TEXT,
        r_o TEXT,
        phone TEXT,
        number INTEGER DEFAULT 0,
        hala_egtimaia_id INTEGER,
        rakm_komy TEXT,
        code INTEGER,
        hala_sehia_id INTEGER,
        mostwa_id INTEGER,
        FOREIGN KEY (karaba_id) REFERENCES karaba(karaba_id),
        FOREIGN KEY (e_s_id) REFERENCES e_s(e_s_id),
        FOREIGN KEY (area_id) REFERENCES areas(area_id),
        FOREIGN KEY (street_id) REFERENCES streets(street_id),
        FOREIGN KEY (hala_egtimaia_id) REFERENCES hala_egtimaia(hala_egtimaia_id),
        FOREIGN KEY (hala_sehia_id) REFERENCES hala_sehia(hala_sehia_id),
        FOREIGN KEY (mostwa_id) REFERENCES mostwa(mostwa_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS person (
        person_id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_name TEXT NOT NULL,
        osra_id INTEGER NOT NULL,
        karaba_id INTEGER,
        birth_date TEXT,
        mostwa_id INTEGER,
        moahil TEXT,
        date_moiahil TEXT,
        hala_egtimaia_id INTEGER,
        hala_sehia_id INTEGER,
        wazefa TEXT,
        place_work TEXT,
        mobile TEXT,
        facebook TEXT,
        father TEXT,
        stage_id INTEGER,
        father_id INTEGER,
        month TEXT,
        age TEXT,
        rakm_komy TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id),
        FOREIGN KEY (karaba_id) REFERENCES karaba(karaba_id),
        FOREIGN KEY (mostwa_id) REFERENCES mostwa(mostwa_id),
        FOREIGN KEY (hala_egtimaia_id) REFERENCES hala_egtimaia(hala_egtimaia_id),
        FOREIGN KEY (hala_sehia_id) REFERENCES hala_sehia(hala_sehia_id),
        FOREIGN KEY (stage_id) REFERENCES stage(stage_id),
        FOREIGN KEY (father_id) REFERENCES fathers(father_id)
      )
    ''');

    // ═══════════════════════════════════════════
    // Tracking Tables
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE IF NOT EXISTS eatraf (
        eatraf_id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (person_id) REFERENCES person(person_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS visits (
        visit_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monasba (
        monasba_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        monasba_name TEXT NOT NULL,
        monasba_date TEXT,
        month TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id)
      )
    ''');

    // ═══════════════════════════════════════════
    // Financial Tables
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE IF NOT EXISTS count_aid (
        count_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        khdma_id INTEGER,
        count_value REAL DEFAULT 0,
        aynee TEXT,
        notes TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id),
        FOREIGN KEY (khdma_id) REFERENCES khdma(khdma_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS count_2 (
        count_2_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        type TEXT,
        count_add REAL DEFAULT 0,
        notes TEXT,
        date_1 TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS masrofat (
        masrofat_id INTEGER PRIMARY KEY AUTOINCREMENT,
        osra_id INTEGER NOT NULL,
        masrof TEXT,
        count_value REAL DEFAULT 0,
        aynee TEXT,
        notes TEXT,
        FOREIGN KEY (osra_id) REFERENCES osra(osra_id)
      )
    ''');

    // ═══════════════════════════════════════════
    // Auth & Permissions
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        pass_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_name TEXT NOT NULL UNIQUE,
        pass_word TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS icon (
        icon_id INTEGER PRIMARY KEY AUTOINCREMENT,
        icon_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inter_icon (
        inter_id INTEGER PRIMARY KEY AUTOINCREMENT,
        pass_id INTEGER NOT NULL,
        icon_id INTEGER,
        icon_name TEXT,
        check_1 INTEGER DEFAULT 1,
        FOREIGN KEY (pass_id) REFERENCES users(pass_id)
      )
    ''');

    // ═══════════════════════════════════════════
    // App Settings
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT
      )
    ''');

    // ═══════════════════════════════════════════
    // Seed Default Data
    // ═══════════════════════════════════════════
    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    // 1. Default permissions (icons) EXACTLY matching Home Screen tabs
    final iconList = [
      'إدراج أسر', 'مناطق وشوارع', 'آباء كهنة', 'مناسبات',
      'بحث', 'أعياد ميلاد', 'صلاحيات', 'حساب مساعدات',
      'تقرير اخوة الرب', 'خدمات', 'مصروفات', 'بحث مصروفات',
      'إدارة القوائم', 'طباعة كارنيه', 'صيانة النظام', 'الافتقاد', 'ترحيل المراحل', 'الاعتراف'
    ];
    for (var ic in iconList) {
      await db.insert('icon', {'icon_name': ic}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 2. Default User (admin)
    // pass_id will be 1
    await db.insert('users', {
      'user_name': 'admin',
      'pass_word': '1234'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 3. Admin permissions mapped to all icons
    final icons = await db.query('icon');
    for (var ic in icons) {
      await db.insert('inter_icon', {
        'pass_id': 1,
        'icon_id': ic['icon_id'],
        'icon_name': ic['icon_name'],
        'check_1': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 4. Default Lookups
    final karabaList = ['أب', 'أم', 'ابن', 'ابنة', 'زوج', 'زوجة', 'أخ', 'أخت', 'عم', 'عمة', 'خال', 'خالة', 'جد', 'جدة', 'حفيد', 'حفيدة', 'أخرى'];
    for (var k in karabaList) {
      await db.insert('karaba', {'karaba_name': k}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final halaList = ['أعزب', 'متزوج', 'مطلق', 'أرمل'];
    for (var h in halaList) {
      await db.insert('hala_egtimaia', {'hala_name': h}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final healthList = ['سليم', 'مريض', 'معاق', 'مزمن'];
    for (var h in healthList) {
      await db.insert('hala_sehia', {'hala_name': h}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final esList = ['ممتاز', 'جيدة', 'متوسط', 'ضعيف', 'معدم'];
    for (var e in esList) {
      await db.insert('e_s', {'e_s_name': e}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final mostwaList = ['أمي', 'يقرأ ويكتب', 'ابتدائي', 'اعدادي', 'ثانوي', 'دبلوم', 'معهد', 'جامعي', 'ماجستير', 'دكتوراه', 'حضانة', 'أخرى'];
    for (var m in mostwaList) {
      await db.insert('mostwa', {'mostwa_name': m}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final khdmaList = ['مساعدات شهرية', 'علاج', 'أدوية', 'عمليات', 'لحوم', 'مدارس', 'جامعة', 'زواج', 'وفاة'];
    for (var k in khdmaList) {
      await db.insert('khdma', {'khdma_name': k}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final stageList = [
      'تمهيدى', 'KG1', 'KG2', 'أولى إبتدائى', 'ثانية ب', 'ثالثة ب', 'رابعة ب', 'خامسة ب', 'سادسة ب',
      'اولى ع', 'ثانية ع', 'ثالثة ع', 'اولي ث', 'ثانية ث', 'ثالثة ث',
      'اولي ج', 'ثانية ج', 'ثالثة ج', 'رابعة ج', 'خامسة ج', 'سادسة ج',
      'خريج', 'موظف', 'أعمال حرة', 'معاش', 'متوفى', 'رب الأسرة', 'ربة منزل'
    ];
    for (var s in stageList) {
      await db.insert('stage', {'stage_name': s}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
