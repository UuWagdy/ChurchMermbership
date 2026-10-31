import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/lookup_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../sync/server_connection_dialog.dart';
import '../../../sync/server_connection_service.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_card.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passController = TextEditingController();
  String? _selectedUser;
  List<User> _users = [];
  bool _isLoadingUsers = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Provider.of<AuthProvider>(context);
    Provider.of<ServerConfigProvider>(context);
    _loadUsers();
  }

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final users = await auth.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
          if (_users.isNotEmpty) {
            if (_selectedUser == null || !_users.any((u) => u.userName == _selectedUser)) {
              _selectedUser = _users.first.userName;
            }
          } else {
            _selectedUser = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  void _handleLogin() async {
    if (_selectedUser == null || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('من فضلك اختر المستخدم وادخل كلمة السر'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(_selectedUser!, _passController.text);

    if (success) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة السر غير صحيحة'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    final churchName = settings.churchName.isNotEmpty
        ? settings.churchName
        : 'كنيسة الشهيدين العظيمين بطرس وبولس';
    final serviceName = settings.serviceName.isNotEmpty
        ? settings.serviceName
        : 'Church Membership - العضوية الكنسية';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: GlassBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 650;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ServerConnectionStatusButton(
                                compact: isCompact,
                                darkBackground: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const ThemeToggleButton(
                            compact: true,
                            darkBackground: false,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 36),
                        _buildLogo(churchName, serviceName, textPrimary, textSecondary),
                        const SizedBox(height: 24),
                        _buildLoginCard(context, primaryColor, textPrimary, textSecondary, isDark),
                        const SizedBox(height: 16),
                        Text(
                          'نظام إدارة العضوية الكنسية',
                          style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(
    String churchName,
    String serviceName,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 88,
              height: 88,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.church_rounded,
                size: 70,
                color: Color(0xFF1A237E),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          serviceName,
          style: TextStyle(
            color: textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          churchName,
          style: TextStyle(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginCard(
    BuildContext context,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final auth = Provider.of<AuthProvider>(context);
    final contrastTextColor = AppTheme.getContrastingTextColor(primaryColor);
    final fieldFillColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.95);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'إعدادات الاتصال بالسيرفر والمزامنة',
                  onPressed: () => ServerConnectionDialog.show(context),
                  icon: Icon(
                    Icons.settings_ethernet_rounded,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'يرجى اختيار اسم المستخدم وإدخال كلمة المرور',
              style: TextStyle(color: textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (_isLoadingUsers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: fieldFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                initialValue: _selectedUser,
                items: _users.map((u) {
                  return DropdownMenuItem(
                    value: u.userName,
                    child: Text(
                      u.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedUser = val),
              ),
            const SizedBox(height: 18),
            TextField(
              controller: _passController,
              obscureText: _obscurePassword,
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: fieldFillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: contrastTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: auth.isLoading ? null : _handleLogin,
                child: auth.isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: contrastTextColor,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 20, color: contrastTextColor),
                          const SizedBox(width: 8),
                          Text(
                            'دخول للنظام',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: contrastTextColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
