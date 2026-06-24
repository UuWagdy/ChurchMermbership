import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // List of dashboard items matching the original C# permissions/buttons
    final List<_DashboardItem> items = [
      _DashboardItem(title: 'إدراج أسر', icon: Icons.family_restroom, color: Colors.indigo, permission: 'إدراج أسر'),
      _DashboardItem(title: 'مناطق وشوارع', icon: Icons.map, color: Colors.blue, permission: 'مناطق وشوارع'),
      _DashboardItem(title: 'آباء كهنة', icon: Icons.person_pin, color: Colors.brown, permission: 'آباء كهنة'),
      _DashboardItem(title: 'مناسبات', icon: Icons.event, color: Colors.orange, permission: 'مناسبات'),
      _DashboardItem(title: 'الافتقاد', icon: Icons.transfer_within_a_station, color: Colors.amber, permission: 'الافتقاد'),
      _DashboardItem(title: 'الاعتراف', icon: Icons.church, color: Colors.deepPurple, permission: 'الاعتراف'),
      _DashboardItem(title: 'بحث', icon: Icons.search, color: Colors.teal, permission: 'بحث'),
      _DashboardItem(title: 'أعياد ميلاد', icon: Icons.cake, color: Colors.pink, permission: 'أعياد ميلاد'),
      _DashboardItem(title: 'صلاحيات', icon: Icons.security, color: Colors.red, permission: 'صلاحيات'),
      _DashboardItem(title: 'حساب مساعدات', icon: Icons.calculate, color: Colors.indigoAccent, permission: 'حساب مساعدات'),
      _DashboardItem(title: 'تقرير اخوة الرب', icon: Icons.picture_as_pdf, color: Colors.redAccent, permission: 'تقرير اخوة الرب'),
      _DashboardItem(title: 'خدمات', icon: Icons.settings_suggest, color: Colors.grey, permission: 'خدمات'),
      _DashboardItem(title: 'مصروفات', icon: Icons.payments, color: Colors.deepOrange, permission: 'مصروفات'),
      _DashboardItem(title: 'بحث مصروفات', icon: Icons.find_in_page, color: Colors.blueAccent, permission: 'بحث مصروفات'),
      _DashboardItem(title: 'إدارة القوائم', icon: Icons.list_alt, color: Colors.deepPurple, permission: 'إدارة القوائم'),
      _DashboardItem(title: 'طباعة كارنيه', icon: Icons.badge, color: Colors.teal.shade800, permission: 'طباعة كارنيه'),
      _DashboardItem(title: 'ترحيل المراحل', icon: Icons.upgrade_outlined, color: Colors.cyan, permission: 'ترحيل المراحل'),
    ];

    // Filter items based on user permissions
    final filteredItems = items.where((item) => auth.hasPermission(item.permission)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('العضوية الكنسية'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(auth.currentUser?.userName ?? 'مستخدم'),
              accountEmail: const Text('Church Membership'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.cover)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('الرئيسية'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ...filteredItems.map((item) => ListTile(
              leading: Icon(item.icon, color: item.color),
              title: Text(item.title),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _navigateToItem(context, item);
              },
            )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
              title: const Text('حول التطبيق'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showAboutDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
              onTap: () {
                auth.logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _DashboardCard(item: item, onNavigate: () => _navigateToItem(context, item));
          },
        ),
      ),
    );
  }

  void _navigateToItem(BuildContext context, _DashboardItem item) {
    if (item.title == 'إدراج أسر') {
      Navigator.of(context).pushNamed('/family-list');
    } else if (item.title == 'مناطق وشوارع') {
      Navigator.of(context).pushNamed('/areas');
    } else if (item.title == 'آباء كهنة') {
      Navigator.of(context).pushNamed('/fathers');
    } else if (item.title == 'الاعتراف' || item.title == 'اعتراف') {
      Navigator.of(context).pushNamed('/confession');
    } else if (item.title == 'حساب مساعدات') {
      Navigator.of(context).pushNamed('/aid');
    } else if (item.title == 'مصروفات') {
      Navigator.of(context).pushNamed('/expense');
    } else if (item.title == 'الافتقاد' || item.title == 'افتقاد') {
      Navigator.of(context).pushNamed('/visit');
    } else if (item.title == 'ترحيل المراحل') {
      Navigator.of(context).pushNamed('/promote-stages');
    } else if (item.title == 'مناسبات') {
      Navigator.of(context).pushNamed('/occasions');
    } else if (item.title == 'مراحل جديدة') {
      Navigator.of(context).pushNamed('/stages');
    } else if (item.title == 'خدمات') {
      Navigator.of(context).pushNamed('/services');
    } else if (item.title == 'أعياد ميلاد') {
      Navigator.of(context).pushNamed('/birthdays');
    } else if (item.title == 'تقرير اخوة الرب') {
      Navigator.of(context).pushNamed('/report');
    } else if (item.title.contains('صلاحيات')) {
      Navigator.of(context).pushNamed('/users');
    } else if (item.title.contains('بحث')) {
      Navigator.of(context).pushNamed('/search');
    } else if (item.title == 'إدارة القوائم') {
      Navigator.of(context).pushNamed('/lookups');
    } else if (item.title == 'طباعة كارنيه') {
      Navigator.of(context).pushNamed('/id-cards');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('سيتم تفعيل شاشة ${item.title} قريباً')),
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'حول التطبيق',
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 80),
              const SizedBox(height: 12),
              const Text(
                'برنامج العضوية الكنسية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Church Membership v1.0.0',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Divider(height: 24),
              const Text(
                'فريق التطوير والبرمجة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
              ),
              const SizedBox(height: 12),
              _buildDevCard(
                context,
                name: 'م. جورج منير',
                role: 'برمجة النسخة الأصلية (C#)',
                assetPath: 'assets/images/csharp_logo.png',
                color: const Color(0xFF512BD4),
              ),
              const SizedBox(height: 10),
              _buildDevCard(
                context,
                name: 'د. يوساب وجدي',
                role: 'تصميم وتطوير التطبيق الحالي (Flutter)\nلطلب التعديلات والتحديثات',
                assetPath: 'assets/images/flutter_logo.png',
                color: const Color(0xFF02569B),
                phone: '01036976446',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDevCard(
    BuildContext context, {
    required String name,
    required String role,
    required String assetPath,
    required Color color,
    String? phone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (phone != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () async {
                          final Uri launchUri = Uri(
                            scheme: 'tel',
                            path: phone,
                          );
                          try {
                            await launchUrl(
                              launchUri,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (_) {}
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_outlined, size: 12, color: color),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'نسخ الرقم',
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: phone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم نسخ الرقم بنجاح',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.content_copy_outlined,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final String permission;

  _DashboardItem({required this.title, required this.icon, required this.color, required this.permission});
}

class _DashboardCard extends StatelessWidget {
  final _DashboardItem item;
  final VoidCallback onNavigate;

  const _DashboardCard({required this.item, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onNavigate,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 48, color: item.color),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

