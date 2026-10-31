import 'package:flutter/material.dart';
import 'app.dart';
import 'data/services/backup_service.dart';
import 'data/database/database_helper.dart';
import 'sync/server_config.dart';
import 'sync/server_connection_service.dart';
import 'sync/signalr_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerBootstrap.initialize();
  if (ServerConfig.isServerMode) {
    SignalRSyncService.instance.start();
  }
  await DatabaseHelper().database;
  BackupService.automatic.start();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(
      'FLUTTER ERROR: ${details.exceptionAsString()}\n${details.stack}',
    );
  };
  runApp(const ChurchMembershipApp());
}
