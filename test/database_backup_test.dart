import 'package:flutter/material.dart';
import 'package:church_membership/ui/widgets/backup_settings_card.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:church_membership/data/services/automatic_backup_service.dart';
import 'package:church_membership/data/services/sqlite_backup_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('membership-backup-test-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test('SQLite snapshot includes committed WAL pages and Arabic', () async {
    final source = await openDatabase('${root.path}/live.db');
    try {
      await source.execute('PRAGMA journal_mode=WAL');
      await source.execute('PRAGMA wal_autocheckpoint=0');
      await source.execute(
        'CREATE TABLE probe (id INTEGER PRIMARY KEY, name TEXT)',
      );
      await source.execute('PRAGMA user_version=11');
      await source.execute('INSERT INTO probe VALUES (?, ?)', [
        1,
        'اختبار النسخ',
      ]);
      await createSqliteBackup(source, '${root.path}/snapshot.db');
      final restored = await openDatabase(
        '${root.path}/snapshot.db',
        readOnly: true,
      );
      try {
        expect(
          (await restored.rawQuery('SELECT name FROM probe')).single['name'],
          'اختبار النسخ',
        );
        expect(
          (await restored.rawQuery('PRAGMA user_version')).single.values.single,
          11,
        );
      } finally {
        await restored.close();
      }
    } finally {
      await source.close();
    }
  });
  test(
    'retention and failed snapshots preserve earlier copies and manual files',
    () async {
      final folder = Directory('${root.path}/chosen folder');
      await folder.create();
      final source = await openDatabase('${root.path}/source.db');
      await source.execute('CREATE TABLE probe (id INTEGER)');
      SharedPreferences.setMockInitialValues({
        'automatic_database_backup_v1': jsonEncode({
          'enabled': true,
          'directory': folder.path,
          'retention': 2,
        }),
      });
      final manual = File('${folder.path}/manual.db');
      await manual.writeAsString('keep');
      var fail = false;
      final service = AutomaticBackupService(
        prefix: 'ChurchMembership',
        isServerMode: () => false,
        serverUrl: () => '',
        headers: () => {},
        snapshot: (target) async {
          if (fail) {
            await File(target).writeAsString('partial');
            throw StateError('disk unavailable');
          }
          await createSqliteBackup(source, target);
        },
      );
      try {
        for (var i = 0; i < 3; i++) {
          await service.runNow();
        }
        final before = await service.load();
        expect((await folder.list().toList()).length, 3);
        fail = true;
        await expectLater(service.runNow(), throwsStateError);
        final after = await service.load();
        expect(after['lastSuccessUtc'], before['lastSuccessUtc']);
        expect(after['lastError'], contains('disk unavailable'));
        expect((await folder.list().toList()).length, 3);
        expect(await manual.readAsString(), 'keep');
      } finally {
        await source.close();
      }
    },
  );
  test('server mode never snapshots local SQLite', () async {
    var snapshots = 0;
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Basic test');
      return http.Response(
        jsonEncode({
          'directory': 'server-folder',
          'lastPath': 'server-folder/native.dump',
        }),
        200,
      );
    });
    final service = AutomaticBackupService(
      prefix: 'ChurchMembership',
      isServerMode: () => true,
      serverUrl: () => 'http://server',
      headers: () => {'Authorization': 'Basic test'},
      client: client,
      snapshot: (_) async {
        snapshots++;
      },
    );
    try {
      expect(await service.runNow(), endsWith('.dump'));
      expect(snapshots, 0);
    } finally {
      client.close();
    }
  });
  testWidgets('backup settings show engine and persist the daily toggle', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'automatic_database_backup_v1': jsonEncode({
        'enabled': true,
        'directory': root.path,
        'retention': 30,
      }),
    });
    final service = AutomaticBackupService(
      prefix: 'test',
      isServerMode: () => false,
      serverUrl: () => '',
      headers: () => {},
      snapshot: (_) async {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BackupSettingsCard(service: service),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SQLite'), findsOneWidget);
    expect(find.text('اختيار مجلد الحفظ'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byType(SwitchListTile));
      // The real directory write probe must complete outside the fake test clock.
      for (var i = 0; i < 100; i++) {
        if ((await service.load())['enabled'] == false) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect((await service.load())['enabled'], false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
