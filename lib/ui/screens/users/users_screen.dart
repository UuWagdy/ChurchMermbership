import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/lookup_models.dart';
import '../../../data/repositories/auth_repository.dart';
import 'maintenance_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  User? _selectedUser;
  List<User> _allUsers = [];
  TabController? _tabController;
  bool _showMaintenance = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _checkMaintenancePermission();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _checkMaintenancePermission() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final hasPerm = auth.hasPermission('صيانة النظام');
    if (hasPerm != _showMaintenance) {
      setState(() {
        _showMaintenance = hasPerm;
        _tabController?.dispose();
        _tabController = _showMaintenance
            ? TabController(length: 2, vsync: this)
            : null;
      });
    }
  }

  Future<void> _loadUsers() async {
    final users = await Provider.of<AuthProvider>(context, listen: false).getAllUsers();
    setState(() => _allUsers = users);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // Recheck permission on rebuild
    final hasPerm = auth.hasPermission('صيانة النظام');
    if (hasPerm != _showMaintenance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showMaintenance = hasPerm;
          _tabController?.dispose();
          _tabController = _showMaintenance
              ? TabController(length: 2, vsync: this)
              : null;
        });
      });
    }

    if (_showMaintenance && _tabController != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المستخدمين والصلاحيات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showAddUserDialog(auth),
              tooltip: 'إضافة مستخدم جديد',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.people), text: 'المستخدمين'),
              Tab(icon: Icon(Icons.settings_backup_restore), text: 'صيانة النظام'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUsersContent(auth),
            const MaintenanceScreen(),
          ],
        ),
      );
    }

    // No maintenance permission — show only users
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين والصلاحيات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddUserDialog(auth),
            tooltip: 'إضافة مستخدم جديد',
          ),
        ],
      ),
      body: _buildUsersContent(auth),
    );
  }

  Widget _buildUsersContent(AuthProvider auth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final permissionMatrix = _selectedUser == null
            ? const Center(child: Text('اختر مستخدم لتعديل صلاحياته'))
            : FutureBuilder<List<Permission>>(
                future: AuthRepository().getPermissions(_selectedUser!.passId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final perms = snapshot.data!;
                  return Column(
                    children: [
                    if (_selectedUser != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmDeleteUser(auth, _selectedUser!),
                            icon: const Icon(Icons.person_remove, color: Colors.red),
                            label: const Text('حذف هذا المستخدم', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: perms.length,
                          itemBuilder: (context, index) {
                            final p = perms[index];
                            return CheckboxListTile(
                              title: Text(p.iconName ?? 'صلاحية غير معروفة'),
                              value: p.check1,
                              onChanged: (val) {
                                auth.updatePermission(p.interId!, val ?? false);
                                setState(() {}); // Refresh future builder
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );

        if (isMobile) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<User>(
                        value: _selectedUser,
                        decoration: const InputDecoration(labelText: 'اختر المستخدم', border: OutlineInputBorder()),
                        items: _allUsers.map((u) => DropdownMenuItem(value: u, child: Text(u.userName))).toList(),
                        onChanged: (val) => setState(() => _selectedUser = val),
                      ),
                    ),
                    if (_selectedUser != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteUser(auth, _selectedUser!),
                        tooltip: 'حذف المستخدم المختار',
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: permissionMatrix),
            ],
          );
        } else {
          return Row(
            children: [
              // User List Sidebar
              SizedBox(
                width: 250,
                child: ListView.builder(
                  itemCount: _allUsers.length,
                  itemBuilder: (context, index) {
                    final user = _allUsers[index];
                    return ListTile(
                      selected: _selectedUser?.passId == user.passId,
                      title: Text(user.userName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => _showEditUserDialog(auth, user),
                          ),
                          if (user.passId != null) 
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _confirmDeleteUser(auth, user),
                            ),
                        ],
                      ),
                      onTap: () => setState(() => _selectedUser = user),
                    );
                  },
                ),
              ),
              const VerticalDivider(),
              // Permission Matrix
              Expanded(child: permissionMatrix),
            ],
          );
        }
      },
    );
  }

  void _showAddUserDialog(AuthProvider auth) {
    final nameController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مستخدم جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
            TextField(controller: passController, decoration: const InputDecoration(labelText: 'كلمة السر'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && passController.text.isNotEmpty) {
                await auth.createUser(nameController.text, passController.text);
                _loadUsers();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(AuthProvider auth, User user) {
    final nameController = TextEditingController(text: user.userName);
    final passController = TextEditingController(text: user.passWord);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات المستخدم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
            TextField(controller: passController, decoration: const InputDecoration(labelText: 'كلمة السر'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && passController.text.isNotEmpty) {
                final updatedUser = User(
                  passId: user.passId,
                  userName: nameController.text,
                  passWord: passController.text,
                );
                await auth.updateUser(updatedUser);
                _loadUsers();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(AuthProvider auth, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مستخدم'),
        content: Text('هل أنت متأكد من حذف المستخدم "${user.userName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await auth.deleteUser(user.passId!);
              if (_selectedUser?.passId == user.passId) {
                setState(() => _selectedUser = null);
              }
              _loadUsers();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
