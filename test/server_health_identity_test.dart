import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_membership/sync/server_connection_service.dart';

void main() {
  for (final app in [
    'ChurchMembership.SyncServer',
    'AbonaFlemoon.SyncServer',
    'SundaySchool.SyncServer',
    'unknown',
  ]) {
    test('connection test rejects another application: $app', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'app': app, 'engine': 'PostgreSQL'}),
        );
        await request.response.close();
      });
      try {
        final result = await ServerConnectionService.checkConnection(
          'http://127.0.0.1:${server.port}',
        );
        expect(
          result.isReachable,
          [
            'ChurchMembership.SyncServer',
            'AbonaFlemoon.SyncServer',
          ].contains(app),
        );
      } finally {
        await requests.cancel();
        await server.close(force: true);
      }
    });
  }
}
