import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/financial_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../data/models/tracking_models.dart';
import '../../../data/services/pdf_service.dart';

class AidScreen extends StatefulWidget {
  const AidScreen({super.key});

  @override
  State<AidScreen> createState() => _AidScreenState();
}

class _AidScreenState extends State<AidScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedOsraId;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _ayneeController = TextEditingController();
  int? _selectedService;
  String? _selectedVariableType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FamilyProvider>(context, listen: false).loadFamilies();
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  void _addFixedAid() async {
    if (_selectedOsraId == null || _amountController.text.isEmpty) return;
    final aid = FixedAid(
      osraId: _selectedOsraId!,
      khdmaId: _selectedService,
      countValue: double.tryParse(_amountController.text) ?? 0.0,
      aynee: _ayneeController.text,
      notes: _notesController.text,
    );
    await Provider.of<FinancialProvider>(context, listen: false).addFixedAid(aid);
    _clearInputs();
  }

  void _addVariableAid() async {
    if (_selectedOsraId == null || _amountController.text.isEmpty) return;
    final aid = VariableAid(
      osraId: _selectedOsraId!,
      type: _selectedVariableType,
      countAdd: double.tryParse(_amountController.text) ?? 0.0,
      notes: _notesController.text,
      date1: DateTime.now().toIso8601String(),
    );
    await Provider.of<FinancialProvider>(context, listen: false).addVariableAid(aid);
    _clearInputs();
  }

  void _clearInputs() {
    _amountController.clear();
    _notesController.clear();
    _ayneeController.clear();
  }

  void _printFixedAids(FinancialProvider financial, LookupProvider lookup) async {
    if (financial.fixedAids.isEmpty || _selectedOsraId == null) return;
    
    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    final familyName = familyProvider.families.firstWhere((f) => f.osraId == _selectedOsraId).osraName;

    final headers = ['م', 'نوع الخدمة', 'المبلغ', 'عيني', 'الملاحظات'];
    final data = financial.fixedAids.asMap().entries.map((e) {
      final aid = e.value;
      final serviceName = lookup.services.firstWhere((s) => s['khdma_id'] == aid.khdmaId, orElse: () => {'khdma_name': '---'})['khdma_name'];
      return [
        (e.key + 1).toString(),
        serviceName as String,
        '${aid.countValue} ج.م',
        aid.aynee ?? '---',
        aid.notes ?? '---',
      ];
    }).toList();

    final pdfService = PdfService();
    await pdfService.generateTableReport(
      title: 'سجل المساعدات الثابتة لأسرة: $familyName',
      headers: headers,
      data: data,
    );
  }

  void _printVariableAids(FinancialProvider financial) async {
    if (financial.variableAids.isEmpty || _selectedOsraId == null) return;
    
    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    final familyName = familyProvider.families.firstWhere((f) => f.osraId == _selectedOsraId).osraName;

    final headers = ['م', 'النوع', 'المبلغ', 'التاريخ', 'الملاحظات'];
    final data = financial.variableAids.asMap().entries.map((e) {
      final aid = e.value;
      return [
        (e.key + 1).toString(),
        aid.type ?? '---',
        '${aid.countAdd} ج.م',
        aid.date1?.split('T')[0] ?? '---',
        aid.notes ?? '---',
      ];
    }).toList();

    final pdfService = PdfService();
    await pdfService.generateTableReport(
      title: 'سجل المساعدات المتغيرة لأسرة: $familyName',
      headers: headers,
      data: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = Provider.of<FamilyProvider>(context);
    final financialProvider = Provider.of<FinancialProvider>(context);
    final lookup = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حساب المساعدات'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.push_pin), text: 'مساعدات ثابتة'),
            Tab(icon: Icon(Icons.autorenew), text: 'مساعدات متغيرة'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedOsraId,
                  decoration: InputDecoration(
                    labelText: 'اختر الأسرة للمتابعة',
                    prefixIcon: const Icon(Icons.family_restroom, color: Colors.indigo),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: familyProvider.families.map((f) => DropdownMenuItem(value: f.osraId, child: Text(f.osraName))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedOsraId = val);
                    if (val != null) financialProvider.loadFinancials(val);
                  },
                ),
                if (_selectedOsraId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'إجمالي المساعدات: ${financialProvider.calculateTotalAids()} ج.م',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFixedAidTab(financialProvider, lookup),
                _buildVariableAidTab(financialProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedAidTab(FinancialProvider financial, LookupProvider lookup) {
    return Column(
      children: [
        _buildEntryForm(
          title: 'إضافة مساعدة ثابتة',
          icon: Icons.add_moderator,
          color: Colors.teal.shade700,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 650;
              final dropdown = DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedService,
                decoration: const InputDecoration(
                  labelText: 'الخدمة',
                  prefixIcon: Icon(Icons.settings_suggest, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12, color: Colors.black),
                items: lookup.services.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['khdma_id'] as int, child: Text(s['khdma_name'] as String, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => setState(() => _selectedService = val),
              );
              
              final amount = TextField(
                controller: _amountController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                keyboardType: TextInputType.number,
              );
              
              final aynee = TextField(
                controller: _ayneeController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'عيني',
                  prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              );
              
              final notes = TextField(
                controller: _notesController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.notes, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              );

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: dropdown),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: amount),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: aynee),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: notes),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dropdown,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: amount),
                        const SizedBox(width: 12),
                        Expanded(child: aynee),
                      ],
                    ),
                    const SizedBox(height: 12),
                    notes,
                  ],
                );
              }
            },
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: _selectedOsraId == null ? null : _addFixedAid,
              icon: const Icon(Icons.add_task),
              label: const Text('تسجيل المساعدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: financial.fixedAids.isEmpty ? null : () => _printFixedAids(financial, lookup),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('طباعة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: financial.fixedAids.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final aid = financial.fixedAids[index];
              final serviceName = lookup.services.firstWhere((s) => s['khdma_id'] == aid.khdmaId, orElse: () => {'khdma_name': '---'})['khdma_name'];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: Icon(Icons.check_circle, color: Colors.teal.shade700),
                  ),
                  title: Text(
                    '$serviceName: ${aid.countValue} ج.م',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (aid.aynee != null && aid.aynee!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.inventory, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('عيني: ${aid.aynee}', style: const TextStyle(color: Colors.blueGrey)),
                            ],
                          ),
                        if (aid.notes != null && aid.notes!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.sticky_note_2, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text('ملاحظات: ${aid.notes}', style: const TextStyle(fontStyle: FontStyle.italic))),
                            ],
                          ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.blue),
                        onPressed: () => _showEditFixedAidDialog(aid),
                        tooltip: 'تعديل',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.red),
                        onPressed: () => _confirmDeleteFixedAid(aid),
                        tooltip: 'حذف',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditFixedAidDialog(FixedAid aid) {
    final amountController = TextEditingController(text: aid.countValue.toString());
    final ayneeController = TextEditingController(text: aid.aynee);
    final notesController = TextEditingController(text: aid.notes);
    int? editService = aid.khdmaId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_document, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              const Text('تعديل مساعدة ثابتة'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: editService,
                  decoration: const InputDecoration(
                    labelText: 'نوع الخدمة',
                    prefixIcon: Icon(Icons.settings_suggest),
                    border: OutlineInputBorder(),
                  ),
                  items: Provider.of<LookupProvider>(context, listen: false).services.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['khdma_id'] as int, child: Text(s['khdma_name'] as String))).toList(),
                  onChanged: (val) => setDialogState(() => editService = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: Icon(Icons.payments),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ayneeController,
                  decoration: const InputDecoration(
                    labelText: 'عيني',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedAid = FixedAid(
                  countId: aid.countId,
                  osraId: aid.osraId,
                  khdmaId: editService,
                  countValue: double.tryParse(amountController.text) ?? 0.0,
                  aynee: ayneeController.text,
                  notes: notesController.text,
                );
                await Provider.of<FinancialProvider>(context, listen: false).updateFixedAid(updatedAid);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFixedAid(FixedAid aid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد الحذف'),
          ],
        ),
        content: const Text('هل أنت متأكد من حذف هذه المساعدة بشكل نهائي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<FinancialProvider>(context, listen: false).deleteFixedAid(aid.countId!, aid.osraId);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  void _showEditVariableAidDialog(VariableAid aid) {
    final amountController = TextEditingController(text: aid.countAdd.toString());
    final notesController = TextEditingController(text: aid.notes);
    String? editType = aid.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_calendar, color: Colors.blueGrey.shade700),
              const SizedBox(width: 8),
              const Text('تعديل مساعدة متغيرة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: editType,
                decoration: const InputDecoration(
                  labelText: 'نوع المساعدة',
                  prefixIcon: Icon(Icons.merge_type),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'علاج', child: Text('علاج')),
                  DropdownMenuItem(value: 'مدرسة', child: Text('مدرسة')),
                  DropdownMenuItem(value: 'طوارئ', child: Text('طوارئ')),
                  DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                ],
                onChanged: (val) => setDialogState(() => editType = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  prefixIcon: Icon(Icons.price_change),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedAid = VariableAid(
                  count2Id: aid.count2Id,
                  osraId: aid.osraId,
                  type: editType,
                  countAdd: double.tryParse(amountController.text) ?? 0.0,
                  notes: notesController.text,
                  date1: aid.date1,
                );
                await Provider.of<FinancialProvider>(context, listen: false).updateVariableAid(updatedAid);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteVariableAid(VariableAid aid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مساعدة'),
        content: const Text('هل أنت متأكد من حذف هذه المساعدة المتغيرة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await Provider.of<FinancialProvider>(context, listen: false).deleteVariableAid(aid.count2Id!, aid.osraId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildVariableAidTab(FinancialProvider financial) {
    return Column(
      children: [
        _buildEntryForm(
          title: 'إضافة مساعدة متغيرة',
          icon: Icons.add_to_photos,
          color: Colors.blueGrey.shade700,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 650;
              final dropdown = DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedVariableType,
                decoration: const InputDecoration(
                  labelText: 'النوع',
                  prefixIcon: Icon(Icons.merge_type, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12, color: Colors.black),
                items: const [
                  DropdownMenuItem(value: 'علاج', child: Text('علاج', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'مدرسة', child: Text('مدرسة', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'طوارئ', child: Text('طوارئ', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'أخرى', child: Text('أخرى', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) => setState(() => _selectedVariableType = val),
              );

              final amount = TextField(
                controller: _amountController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                keyboardType: TextInputType.number,
              );

              final notes = TextField(
                controller: _notesController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.description_outlined, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              );

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: dropdown),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: amount),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: notes),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 3, child: dropdown),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: amount),
                      ],
                    ),
                    const SizedBox(height: 12),
                    notes,
                  ],
                );
              }
            },
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: _selectedOsraId == null ? null : _addVariableAid,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('تسجيل المساعدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: financial.variableAids.isEmpty ? null : () => _printVariableAids(financial),
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة السجل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: financial.variableAids.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final aid = financial.variableAids[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade50,
                    child: Icon(Icons.history_toggle_off, color: Colors.blueGrey.shade700),
                  ),
                  title: Text(
                    '${aid.type}: ${aid.countAdd} ج.م',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('التاريخ: ${aid.date1?.split('T')[0]}', style: const TextStyle(color: Colors.blueGrey)),
                          ],
                        ),
                        if (aid.notes != null && aid.notes!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text('ملاحظات: ${aid.notes}', style: const TextStyle(fontStyle: FontStyle.italic))),
                            ],
                          ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_location_alt, color: Colors.blue),
                        onPressed: () => _showEditVariableAidDialog(aid),
                        tooltip: 'تعديل',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => _confirmDeleteVariableAid(aid),
                        tooltip: 'حذف',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntryForm({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    required List<Widget> actions,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 24),
              child,
              const SizedBox(height: 24),
              Wrap(
                spacing: 12.0,
                runSpacing: 16.0,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
