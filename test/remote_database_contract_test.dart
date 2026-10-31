import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:church_membership/sync/dotnet_postgres_database.dart';

class MockHttpClient extends http.BaseClient {
  final List<http.Request> recordedRequests = [];
  final List<Map<String, dynamic>> recordedBodies = [];
  String txIdToReturn = 'test-tx-777';
  bool throwOnCommit = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    recordedRequests.add(req);

    Map<String, dynamic> bodyJson = {};
    if (req.body.isNotEmpty) {
      try {
        bodyJson = jsonDecode(req.body) as Map<String, dynamic>;
        recordedBodies.add(bodyJson);
      } catch (_) {}
    }

    final path = req.url.path;

    if (path.endsWith('/api/storage/tx/begin')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'txId': txIdToReturn}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.endsWith('/api/storage/tx/commit')) {
      if (throwOnCommit) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'error': 'Commit forced failure'}))),
          500,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'status': 'committed'}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.endsWith('/api/storage/tx/rollback')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'status': 'rolled_back'}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.endsWith('/api/storage/insert')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'lastInsertRowId': 42}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.endsWith('/api/storage/execute')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'affectedRows': 1}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.endsWith('/api/storage/query')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'rows': [
            {'osra_id': 10, 'osra_name': 'أسرة مارمرقس', 'member_count': 5}
          ]
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.endsWith('/api/storage/batch')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'affectedRows': 3}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'status': 'ok'}))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('DotNetPostgresDatabase Contract Tests', () {
    test('1. CaseInsensitiveRowMap supports case-insensitive access, mutation, and removal', () {
      final map = CaseInsensitiveRowMap({
        'osra_id': 101,
        'OSRA_NAME': 'عائلة تجريبية',
        'Member_Count': 4,
      });

      // Reading case-insensitively
      expect(map['osra_id'], equals(101));
      expect(map['OSRA_ID'], equals(101));
      expect(map['OsRa_Id'], equals(101));
      expect(map['osra_name'], equals('عائلة تجريبية'));
      expect(map['OSRA_NAME'], equals('عائلة تجريبية'));
      expect(map['member_count'], equals(4));

      // Writing with different case
      map['member_count'] = 6;
      expect(map['MEMBER_COUNT'], equals(6));
      expect(map['member_count'], equals(6));

      // Removing case-insensitively
      final removed = map.remove('OSRA_ID');
      expect(removed, equals(101));
      expect(map['osra_id'], isNull);
    });

    test('2. encodeParams converts Dart data types to SqlParamDto accurately', () {
      final rawArgs = [
        null,
        123,
        45.67,
        true,
        'نص تجريبي',
        Uint8List.fromList([1, 2, 3]),
      ];

      final encoded = DotNetPostgresDatabase.encodeParams(rawArgs);

      expect(encoded.length, equals(6));
      expect(encoded[0], equals({'type': 'null', 'value': null}));
      expect(encoded[1], equals({'type': 'int', 'value': 123}));
      expect(encoded[2], equals({'type': 'double', 'value': 45.67}));
      expect(encoded[3], equals({'type': 'bool', 'value': true}));
      expect(encoded[4], equals({'type': 'string', 'value': 'نص تجريبي'}));
      expect(encoded[5], equals({'type': 'bytes', 'value': base64Encode([1, 2, 3])}));
    });

    test('3. insert strips null primary key columns automatically', () async {
      final mock = MockHttpClient();
      final db = DotNetPostgresDatabase(
        client: mock,
        baseUrlProvider: () => 'http://127.0.0.1:5060',
      );

      final rowId = await db.insert('osra', {
        'osra_id': null,
        'osra_name': 'أسرة جديدة',
        'code': 1001,
      });

      expect(rowId, equals(42));
      expect(mock.recordedBodies.isNotEmpty, isTrue);

      final lastBody = mock.recordedBodies.last;
      final sql = lastBody['sql'] as String;

      // osra_id must not be in the column list
      expect(sql.contains('"osra_id"'), isFalse);
      expect(sql.contains('"osra_name"'), isTrue);
      expect(sql.contains('"code"'), isTrue);
    });

    test('4. ConflictAlgorithm translates to INSERT OR IGNORE and INSERT OR REPLACE', () async {
      final mock = MockHttpClient();
      final db = DotNetPostgresDatabase(
        client: mock,
        baseUrlProvider: () => 'http://127.0.0.1:5060',
      );

      // Test ConflictAlgorithm.ignore
      await db.insert(
        'areas',
        {'area_id': null, 'area_name': 'المنطقة الأولى'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final ignoreSql = mock.recordedBodies.last['sql'] as String;
      expect(ignoreSql.startsWith('INSERT OR IGNORE INTO "areas"'), isTrue);

      // Test ConflictAlgorithm.replace
      await db.insert(
        'areas',
        {'area_id': null, 'area_name': 'المنطقة الثانية'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final replaceSql = mock.recordedBodies.last['sql'] as String;
      expect(replaceSql.startsWith('INSERT OR REPLACE INTO "areas"'), isTrue);
    });

    test('5. Transaction isolation propagates txId and commits cleanly', () async {
      final mock = MockHttpClient();
      mock.txIdToReturn = 'tx-iso-999';
      final db = DotNetPostgresDatabase(
        client: mock,
        baseUrlProvider: () => 'http://127.0.0.1:5060',
      );

      final result = await db.transaction<int>((txn) async {
        await txn.insert('fathers', {
          'father_id': null,
          'father_name': 'أبونا فليمون',
        });
        await txn.execute('UPDATE fathers SET father_mobile = ? WHERE father_name = ?', ['0123456789', 'أبونا فليمون']);
        return 99;
      });

      expect(result, equals(99));

      // Verify that begin was called
      expect(mock.recordedRequests.any((r) => r.url.path.endsWith('/api/storage/tx/begin')), isTrue);
      // Verify that commit was called with txId
      expect(mock.recordedRequests.any((r) => r.url.path.endsWith('/api/storage/tx/commit')), isTrue);
      final commitBody = mock.recordedBodies.firstWhere((b) => b['txId'] == 'tx-iso-999');
      expect(commitBody['txId'], equals('tx-iso-999'));

      // Verify that all statements inside the transaction carried txId
      final txStatements = mock.recordedBodies.where((b) => b.containsKey('sql')).toList();
      for (var stmt in txStatements) {
        expect(stmt['txId'], equals('tx-iso-999'));
      }
    });

    test('6. Transaction rolls back when an error is thrown inside transaction callback', () async {
      final mock = MockHttpClient();
      mock.txIdToReturn = 'tx-rollback-888';
      final db = DotNetPostgresDatabase(
        client: mock,
        baseUrlProvider: () => 'http://127.0.0.1:5060',
      );

      await expectLater(
        () => db.transaction((txn) async {
          await txn.execute('UPDATE osra SET osra_name = ?', ['test']);
          throw Exception('Simulated user cancellation or failure');
        }),
        throwsA(isA<Exception>()),
      );

      // Verify that rollback was called
      expect(mock.recordedRequests.any((r) => r.url.path.endsWith('/api/storage/tx/rollback')), isTrue);
    });
  });
}
