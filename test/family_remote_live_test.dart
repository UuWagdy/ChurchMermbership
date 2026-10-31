import 'package:flutter_test/flutter_test.dart';
import 'package:church_membership/sync/server_config.dart';
import 'package:church_membership/data/database/database_helper.dart';
import 'package:church_membership/data/repositories/family_repository.dart';
import 'package:church_membership/providers/lookup_provider.dart';
import 'dart:async';
import 'package:church_membership/sync/signalr_sync_service.dart';
import 'package:church_membership/sync/dotnet_postgres_database.dart';

void main() {
  const url = String.fromEnvironment('MEMBERSHIP_TEST_URL');
  test('installed server loads families, members and lookups', () async {
    ServerConfig.isServerMode = true;
    ServerConfig.baseUrl = url;
    addTearDown(() => DatabaseHelper().closeDatabase());
    final watch = Stopwatch()..start();
    final families = await FamilyRepository().getFamilies();
    final family = families.firstWhere((f) => f.memberCount > 0);
    final members = await PersonRepository().getPersonsByFamily(family.osraId!);
    expect(members.length, family.memberCount);
    expect(members.every((p) => p.osraId == family.osraId), isTrue);
    print('Families and members loaded in ${watch.elapsedMilliseconds} ms');
    watch.reset();
    final lookup = LookupProvider();
    await lookup.loadAllLookups();
    print('Lookups loaded in ${watch.elapsedMilliseconds} ms');
    lookup.dispose();
  }, skip: url.isEmpty);

  test(
    'a committed change reaches the production sync client and a second reader',
    () async {
      ServerConfig.isServerMode = true;
      ServerConfig.baseUrl = url;
      final service = SignalRSyncService.instance;
      final connected = Completer<void>();
      final states = service.onConnectionStateChanged.listen((value) {
        if (value && !connected.isCompleted) connected.complete();
      });
      final key = '_sync_probe_${DateTime.now().microsecondsSinceEpoch}';
      final writer = DotNetPostgresDatabase();
      final reader = DotNetPostgresDatabase();
      final changed = Completer<void>();
      final events = service.onTablesChanged.listen((tables) {
        if (tables.contains('settings') && !changed.isCompleted)
          changed.complete();
      });
      try {
        service.restart();
        await connected.future.timeout(const Duration(seconds: 10));
        // Stay connected beyond the server's 45-second receive timeout.
        await Future<void>.delayed(const Duration(seconds: 47));
        expect(service.isConnected, isTrue);
        await writer.rawInsert(
          'INSERT INTO settings (setting_key, setting_value) VALUES (?, ?)',
          [key, 'probe'],
        );
        await changed.future.timeout(const Duration(seconds: 8));
        final rows = await reader.rawQuery(
          'SELECT setting_value FROM settings WHERE setting_key = ?',
          [key],
        );
        expect(rows.single['setting_value'], 'probe');
        service.restart();
      } finally {
        await writer.rawDelete('DELETE FROM settings WHERE setting_key = ?', [
          key,
        ]);
        service.stop();
        await events.cancel();
        await states.cancel();
        await writer.close();
        await reader.close();
      }
    },
    skip: url.isEmpty,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
