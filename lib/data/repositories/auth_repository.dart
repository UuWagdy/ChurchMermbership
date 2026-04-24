import '../database/database_helper.dart';
import '../models/lookup_models.dart';

class AuthRepository {
  final _dbHelper = DatabaseHelper();

  Future<User?> login(String userName, String passWord) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'user_name = ? AND pass_word = ?',
      whereArgs: [userName, passWord],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getUsers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromMap(maps[i]));
  }

  Future<int> insertUser(User user) async {
    final db = await _dbHelper.database;
    return await db.insert('users', user.toMap());
  }

  Future<int> updateUser(User user) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'pass_id = ?',
      whereArgs: [user.passId],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await _dbHelper.database;
    await db.delete('inter_icon', where: 'pass_id = ?', whereArgs: [id]);
    return await db.delete('users', where: 'pass_id = ?', whereArgs: [id]);
  }

  Future<List<Permission>> getPermissions(int passId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT ii.inter_id, ii.pass_id, ii.icon_id, 
             COALESCE(i.icon_name, ii.icon_name) AS icon_name, 
             ii.check_1
      FROM inter_icon ii
      LEFT JOIN icon i ON ii.icon_id = i.icon_id
      WHERE ii.pass_id = ?
    ''', [passId]);
    return List.generate(maps.length, (i) => Permission.fromMap(maps[i]));
  }

  Future<void> updatePermission(int interId, bool checked) async {
    final db = await _dbHelper.database;
    await db.update(
      'inter_icon',
      {'check_1': checked ? 1 : 0},
      where: 'inter_id = ?',
      whereArgs: [interId],
    );
  }

  Future<void> initPermissionsForUser(int passId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> icons = await db.query('icon');
    for (var ic in icons) {
      await db.insert('inter_icon', {
        'pass_id': passId,
        'icon_id': ic['icon_id'],
        'icon_name': ic['icon_name'],
        'check_1': 1,
      });
    }
  }
}
