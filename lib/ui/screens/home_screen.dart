import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    ];

    // Filter items based on user permissions
    final filteredItems = items.where((item) => auth.hasPermission(item.permission)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامج العضوية الكنسية'),
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
    } else if (item.title == 'اعتراف') {
      Navigator.of(context).pushNamed('/confession');
    } else if (item.title == 'حساب مساعدات') {
      Navigator.of(context).pushNamed('/aid');
    } else if (item.title == 'مصروفات') {
      Navigator.of(context).pushNamed('/expense');
    } else if (item.title == 'افتقاد') {
      Navigator.of(context).pushNamed('/visit');
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

