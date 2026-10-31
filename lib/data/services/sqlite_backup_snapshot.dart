import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> createSqliteBackup(Database source, String target) async {
  await source.execute('VACUUM INTO ?', [target]);
  final copy = await databaseFactory.openDatabase(
    target,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );
  try {
    final check = await copy.rawQuery('PRAGMA quick_check');
    if (check.first.values.first != 'ok')
      throw StateError('فشل التحقق من سلامة النسخة.');
  } finally {
    await copy.close();
  }
}
