import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/financial_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/models/tracking_models.dart';
import '../../../data/models/family_models.dart';
import '../../../data/services/pdf_service.dart';


class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  int? _selectedOsraId;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _masrofController = TextEditingController();
  final _ayneeController = TextEditingController();
  final _familySearchController = TextEditingController();
  final _familyFocusNode = FocusNode();
  final _autocompleteKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FamilyProvider>(context, listen: false).loadFamilies();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _masrofController.dispose();
    _ayneeController.dispose();
    _familySearchController.dispose();
    _familyFocusNode.dispose();
    super.dispose();
  }

  void _addExpense() async {
    if (_selectedOsraId == null || _amountController.text.isEmpty) return;
    final expense = Expense(
      osraId: _selectedOsraId!,
      masrof: _masrofController.text,
      countValue: double.tryParse(_amountController.text) ?? 0.0,
      aynee: _ayneeController.text,
      notes: _notesController.text,
    );
    await Provider.of<FinancialProvider>(context, listen: false).addExpense(expense);
    _clearInputs();
  }

  void _clearInputs() {
    _amountController.clear();
    _notesController.clear();
    _masrofController.clear();
    _ayneeController.clear();
  }

  void _printExpenses() async {
    final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
    if (financialProvider.expenses.isEmpty || _selectedOsraId == null) return;
    
    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    final familyName = familyProvider.families.firstWhere((f) => f.osraId == _selectedOsraId).osraName;

    final headers = ['م', 'البند', 'المبلغ', 'عيني', 'الملاحظات'];
    final data = financialProvider.expenses.asMap().entries.map((e) {
      final exp = e.value;
      return [
        (e.key + 1).toString(),
        exp.masrof ?? '---',
        '${exp.countValue} ج.م',
        exp.aynee ?? '---',
        exp.notes ?? '---',
      ];
    }).toList();

    final pdfService = PdfService();
    await pdfService.generateTableReport(
      title: 'سجل مصروفات لأسرة: $familyName',
      headers: headers,
      data: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = Provider.of<FamilyProvider>(context);
    final financialProvider = Provider.of<FinancialProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المصروفات')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0), // Reduced from 20
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text('إضافة مصروف جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 650;

                        final familyAutocomplete = RawAutocomplete<Family>(
                          key: _autocompleteKey,
                          textEditingController: _familySearchController,
                          focusNode: _familyFocusNode,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            final families = familyProvider.families;
                            if (textEditingValue.text.isEmpty) {
                              return families;
                            }
                            return families.where((Family option) {
                              return option.osraName.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          displayStringForOption: (Family option) => option.osraName,
                          fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                            return TextFormField(
                              controller: fieldController,
                              focusNode: fieldFocusNode,
                              style: const TextStyle(fontSize: 12, color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'اختر الأسرة',
                                prefixIcon: const Icon(Icons.people, size: 18),
                                suffixIcon: _selectedOsraId != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                        onPressed: () {
                                          setState(() {
                                            _selectedOsraId = null;
                                            _familySearchController.clear();
                                          });
                                        },
                                      )
                                    : const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            );
                          },
                          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Family> onSelected, Iterable<Family> options) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final optionsWidth = isDesktop ? 350.0 : screenWidth - 64.0;
                            return Align(
                              alignment: Alignment.topRight,
                              child: Material(
                                elevation: 4.0,
                                borderRadius: BorderRadius.circular(8),
                                clipBehavior: Clip.antiAlias,
                                child: Container(
                                  width: optionsWidth,
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  color: Colors.white,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final Family option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                          decoration: BoxDecoration(
                                            border: index < options.length - 1
                                                ? Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5))
                                                : null,
                                          ),
                                          child: Text(
                                            option.osraName,
                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          onSelected: (Family selection) {
                            setState(() {
                              _selectedOsraId = selection.osraId;
                            });
                            if (selection.osraId != null) {
                              financialProvider.loadFinancials(selection.osraId!);
                            }
                          },
                        );

                        final masrofField = TextField(
                          controller: _masrofController,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'بند المصروف',
                            prefixIcon: Icon(Icons.category, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        );

                        final amountField = TextField(
                          controller: _amountController,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                            prefixIcon: Icon(Icons.attach_money, size: 16),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
                        );

                        final ayneeField = TextField(
                          controller: _ayneeController,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'عيني',
                            prefixIcon: Icon(Icons.inventory_2, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        );

                        final notesField = TextField(
                          controller: _notesController,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات إضافية',
                            prefixIcon: Icon(Icons.note, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        );

                        if (isDesktop) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(flex: 3, child: familyAutocomplete),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 3, child: masrofField),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 2, child: amountField),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(flex: 2, child: ayneeField),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 4, child: notesField),
                                ],
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              familyAutocomplete,
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(flex: 3, child: masrofField),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 2, child: amountField),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(flex: 2, child: ayneeField),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 3, child: notesField),
                                ],
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12.0,
                      runSpacing: 16.0,
                      alignment: WrapAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _selectedOsraId == null ? null : _addExpense,
                          icon: const Icon(Icons.add_task),
                          label: const Text('تسجيل المصروف'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: financialProvider.expenses.isEmpty ? null : _printExpenses,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('استخراج تقرير PDF'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedOsraId != null)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'إجمالي المصروفات: ${financialProvider.calculateTotalExpenses()} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: financialProvider.expenses.length,
                        itemBuilder: (context, index) {
                          final exp = financialProvider.expenses[index];
                          return ListTile(
                            leading: const Icon(Icons.money_off, color: Colors.red),
                            title: Text('${exp.masrof}: ${exp.countValue} ج.م'),
                            subtitle: Text('عيني: ${exp.aynee ?? '---'} | ${exp.notes ?? ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showEditExpenseDialog(exp)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirmDeleteExpense(exp)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditExpenseDialog(Expense exp) {
    final amountController = TextEditingController(text: exp.countValue.toString());
    final ayneeController = TextEditingController(text: exp.aynee);
    final notesController = TextEditingController(text: exp.notes);
    final masrofController = TextEditingController(text: exp.masrof);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل مصروف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: masrofController, decoration: const InputDecoration(labelText: 'بند المصروف')),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
              TextField(controller: ayneeController, decoration: const InputDecoration(labelText: 'عيني')),
              TextField(controller: notesController, decoration: const InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final updatedExpense = Expense(
                masrofatId: exp.masrofatId,
                osraId: exp.osraId,
                masrof: masrofController.text,
                countValue: double.tryParse(amountController.text) ?? 0.0,
                aynee: ayneeController.text,
                notes: notesController.text,
              );
              await Provider.of<FinancialProvider>(context, listen: false).updateExpense(updatedExpense);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(Expense exp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مصروف'),
        content: const Text('هل أنت متأكد من حذف هذا المصروف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await Provider.of<FinancialProvider>(context, listen: false).deleteExpense(exp.masrofatId!, exp.osraId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
