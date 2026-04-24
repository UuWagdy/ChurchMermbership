import 'package:flutter/material.dart';
import '../data/models/lookup_models.dart';
import '../data/repositories/auth_repository.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  User? _currentUser;
  List<Permission> _permissions = [];
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  List<Permission> get permissions => _permissions;
  bool get isLoading => _isLoading;

  Future<bool> login(String userName, String passWord) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authRepo.login(userName, passWord);
      if (user != null) {
        _currentUser = user;
        _permissions = await _authRepo.getPermissions(user.passId!);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void logout() {
    _currentUser = null;
    _permissions = [];
    notifyListeners();
  }

  bool hasPermission(String iconName) {
    if (_currentUser?.passId == 1) return true; // Admin has all permissions
    return _permissions.any((p) => p.iconName == iconName && p.check1);
  }

  Future<List<User>> getAllUsers() => _authRepo.getUsers();

  Future<void> createUser(String name, String password) async {
    final newUser = User(userName: name, passWord: password);
    final id = await _authRepo.insertUser(newUser);
    await _authRepo.initPermissionsForUser(id);
    notifyListeners();
  }

  Future<void> deleteUser(int id) async {
    await _authRepo.deleteUser(id);
    notifyListeners();
  }

  Future<void> updateUser(User user) async {
    await _authRepo.updateUser(user);
    notifyListeners();
  }

  Future<void> updatePermission(int interId, bool checked) async {
    await _authRepo.updatePermission(interId, checked);
    if (_currentUser != null) {
      _permissions = await _authRepo.getPermissions(_currentUser!.passId!);
    }
    notifyListeners();
  }
}
