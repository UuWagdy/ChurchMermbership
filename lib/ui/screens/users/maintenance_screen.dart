import 'package:flutter/material.dart';
import '../../../data/services/backup_service.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final BackupService _backupService = BackupService();
  bool _isLoading = false;

  Future<void> _performBackup() async {
    setState(() => _isLoading = true);
    try {
      final path = await _backupService.backupDatabase();
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ النسخة الاحتياطية بنجاح في:\n$path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في النسخ الاحتياطي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performRestore() async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد استعادة البيانات'),
        content: const Text(
          'هل أنت متأكد أنك تريد استعادة البيانات من نسخة احتياطية؟\n\n'
          '⚠️ سيتم استبدال جميع البيانات الحالية بالبيانات الموجودة في الملف المختار.\n\n'
          'يُنصح بعمل نسخة احتياطية أولاً قبل الاستعادة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استعادة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await _backupService.restoreDatabase();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استعادة البيانات بنجاح! يُنصح بإعادة تشغيل التطبيق.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في استعادة البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performFactoryReset() async {
    // Double confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ ضبط المصنع'),
        content: const Text(
          'هل أنت متأكد أنك تريد حذف جميع البيانات؟\n\n'
          'سيتم حذف:\n'
          '• جميع الأسر والأفراد\n'
          '• المناطق والشوارع\n'
          '• المناسبات والافتقاد والاعتراف\n'
          '• المساعدات والمصروفات\n'
          '• القوائم المرجعية (القرابة، المستوى، الحالة...)\n\n'
          '⚠️ لن يتم حذف المستخدمين وصلاحياتهم.\n\n'
          'هذا الإجراء لا يمكن التراجع عنه!',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف كل البيانات', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Second confirmation
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد نهائي'),
        content: const Text('هل أنت متأكد تماماً؟ سيتم حذف كل البيانات نهائياً!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا، تراجع')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، احذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (doubleConfirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _backupService.factoryReset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم ضبط المصنع بنجاح! يُنصح بإعادة تشغيل التطبيق.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في ضبط المصنع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_backup_restore,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'صيانة النظام',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'إدارة النسخ الاحتياطي واستعادة البيانات',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Backup Card
                  _MaintenanceCard(
                    icon: Icons.backup,
                    iconColor: Colors.blue,
                    title: 'نسخ احتياطي',
                    description: 'حفظ نسخة من قاعدة البيانات الحالية في ملف .db',
                    buttonText: 'حفظ نسخة احتياطية',
                    buttonColor: Colors.blue,
                    onPressed: _isLoading ? null : _performBackup,
                  ),

                  const SizedBox(height: 20),

                  // Restore Card
                  _MaintenanceCard(
                    icon: Icons.restore,
                    iconColor: Colors.orange,
                    title: 'استعادة البيانات',
                    description: 'استعادة قاعدة البيانات من ملف .db سابق',
                    buttonText: 'استعادة من نسخة احتياطية',
                    buttonColor: Colors.orange,
                    onPressed: _isLoading ? null : _performRestore,
                  ),

                  const SizedBox(height: 20),

                  // Factory Reset Card
                  _MaintenanceCard(
                    icon: Icons.delete_forever,
                    iconColor: Colors.red,
                    title: 'ضبط المصنع',
                    description: 'حذف جميع البيانات ماعدا المستخدمين وصلاحياتهم',
                    buttonText: 'ضبط المصنع',
                    buttonColor: Colors.red,
                    onPressed: _isLoading ? null : _performFactoryReset,
                  ),

                  const SizedBox(height: 32),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'للتحويل من النظام القديم (Access)، استخدم أداة التحويل المرفقة (ConvertAccessToSQLite.exe)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جاري المعالجة...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback? onPressed;

  const _MaintenanceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.buttonColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: Text(buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
