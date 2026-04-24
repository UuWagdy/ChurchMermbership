import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/lookup_provider.dart';

/// A unified screen for managing all lookup tables (القرابة، الحالة الاجتماعية، إلخ).
class LookupManagementScreen extends StatefulWidget {
  const LookupManagementScreen({super.key});

  @override
  State<LookupManagementScreen> createState() => _LookupManagementScreenState();
}

class _LookupManagementScreenState extends State<LookupManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة القوائم'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'القرابة'),
            Tab(icon: Icon(Icons.favorite_outline, size: 18), text: 'الحالة الاجتماعية'),
            Tab(icon: Icon(Icons.health_and_safety_outlined, size: 18), text: 'الحالة الصحية'),
            Tab(icon: Icon(Icons.trending_up, size: 18), text: 'الحالة الاقتصادية'),
            Tab(icon: Icon(Icons.school_outlined, size: 18), text: 'المستوى التعليمي'),
          ],
        ),
      ),
      body: Consumer<LookupProvider>(
        builder: (context, lookup, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _LookupTab(
                title: 'القرابة',
                icon: Icons.people,
                color: Colors.indigo,
                items: lookup.karaba,
                idKey: 'karaba_id',
                nameKey: 'karaba_name',
                onAdd: (name) => lookup.addKaraba(name),
                onUpdate: (id, name) => lookup.updateKaraba(id, name),
                onDelete: (id) => lookup.deleteKaraba(id),
              ),
              _LookupTab(
                title: 'الحالة الاجتماعية',
                icon: Icons.favorite,
                color: Colors.pink,
                items: lookup.socialStatus,
                idKey: 'hala_egtimaia_id',
                nameKey: 'hala_name',
                onAdd: (name) => lookup.addSocialStatus(name),
                onUpdate: (id, name) => lookup.updateSocialStatus(id, name),
                onDelete: (id) => lookup.deleteSocialStatus(id),
              ),
              _LookupTab(
                title: 'الحالة الصحية',
                icon: Icons.health_and_safety,
                color: Colors.teal,
                items: lookup.healthStatus,
                idKey: 'hala_sehia_id',
                nameKey: 'hala_name',
                onAdd: (name) => lookup.addHealthStatus(name),
                onUpdate: (id, name) => lookup.updateHealthStatus(id, name),
                onDelete: (id) => lookup.deleteHealthStatus(id),
              ),
              _LookupTab(
                title: 'الحالة الاقتصادية',
                icon: Icons.trending_up,
                color: Colors.orange,
                items: lookup.economicStatus,
                idKey: 'e_s_id',
                nameKey: 'e_s_name',
                onAdd: (name) => lookup.addEconomicStatus(name),
                onUpdate: (id, name) => lookup.updateEconomicStatus(id, name),
                onDelete: (id) => lookup.deleteEconomicStatus(id),
              ),
              _LookupTab(
                title: 'المستوى التعليمي',
                icon: Icons.school,
                color: Colors.blue,
                items: lookup.educationLevels,
                idKey: 'mostwa_id',
                nameKey: 'mostwa_name',
                onAdd: (name) => lookup.addEducationLevel(name),
                onUpdate: (id, name) => lookup.updateEducationLevel(id, name),
                onDelete: (id) => lookup.deleteEducationLevel(id),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A reusable tab widget for managing a single lookup table.
class _LookupTab extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final String idKey;
  final String nameKey;
  final Future<void> Function(String name) onAdd;
  final Future<void> Function(int id, String name) onUpdate;
  final Future<void> Function(int id) onDelete;

  const _LookupTab({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.idKey,
    required this.nameKey,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_LookupTab> createState() => _LookupTabState();
}

class _LookupTabState extends State<_LookupTab> with AutomaticKeepAliveClientMixin {
  final _addController = TextEditingController();
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await widget.onAdd(name);
      _addController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showEditDialog(int id, String currentName) {
    final editController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: widget.color, size: 22),
            const SizedBox(width: 8),
            const Text('تعديل', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            labelText: 'الاسم الجديد',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          autofocus: true,
          onSubmitted: (_) async {
            final newName = editController.text.trim();
            if (newName.isNotEmpty) {
              await widget.onUpdate(id, newName);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('حفظ'),
            style: FilledButton.styleFrom(backgroundColor: widget.color),
            onPressed: () async {
              final newName = editController.text.trim();
              if (newName.isEmpty) return;
              await widget.onUpdate(id, newName);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('تأكيد الحذف', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text('هل تريد حذف "$name"؟\nقد يؤثر ذلك على السجلات المرتبطة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('حذف'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.onDelete(id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        final addCard = Card(
          margin: const EdgeInsets.all(12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'إضافة ${widget.title}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _addController,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    hintText: 'أدخل الاسم هنا...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _addItem,
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, size: 18),
                  label: const Text('إضافة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );

        final listCard = Card(
          margin: const EdgeInsets.all(12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.list_alt, color: widget.color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.title} (${widget.items.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: widget.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('لا توجد بيانات', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: widget.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final id = item[widget.idKey] as int;
                          final name = (item[widget.nameKey] ?? '') as String;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: widget.color.withOpacity(0.1),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.color),
                              ),
                            ),
                            title: Text(name, style: const TextStyle(fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: widget.color, size: 18),
                                  onPressed: () => _showEditDialog(id, name),
                                  tooltip: 'تعديل',
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  onPressed: () => _confirmDelete(id, name),
                                  tooltip: 'حذف',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 340, child: addCard),
              Expanded(child: listCard),
            ],
          );
        } else {
          return Column(
            children: [
              addCard,
              Expanded(child: listCard),
            ],
          );
        }
      },
    );
  }
}
