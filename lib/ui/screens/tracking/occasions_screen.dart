import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/services/pdf_service.dart';
import '../../../data/models/tracking_models.dart';
import '../../../data/models/family_models.dart';

class OccasionsScreen extends StatefulWidget {
  const OccasionsScreen({super.key});

  @override
  State<OccasionsScreen> createState() => _OccasionsScreenState();
}

class _OccasionsScreenState extends State<OccasionsScreen> {
  int? _selectedOsraId;
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
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
    _nameController.dispose();
    _familySearchController.dispose();
    _familyFocusNode.dispose();
    super.dispose();
  }

  void _addOccasion() async {
    if (_selectedOsraId == null || _nameController.text.isEmpty) return;
    await Provider.of<TrackingProvider>(context, listen: false)
        .addOccasion(_selectedOsraId!, _nameController.text, _selectedDate);
    _nameController.clear();
  }

  void _printOccasions() async {
    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
    if (trackingProvider.occasions.isEmpty) return;

    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    final familyName = familyProvider.families.firstWhere((f) => f.osraId == _selectedOsraId).osraName;

    final headers = ['م', 'المناسبة', 'التاريخ', 'الشهر'];
    final data = trackingProvider.occasions.asMap().entries.map((e) {
      final occ = e.value;
      return [
        (e.key + 1).toString(),
        occ.monasbaName,
        occ.monasbaDate?.split('T')[0] ?? '---',
        occ.month ?? '---',
      ];
    }).toList();

    final pdfService = PdfService();
    await pdfService.generateTableReport(
      title: 'سجل مناسبات أسرة: $familyName',
      headers: headers,
      data: data,
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = Provider.of<FamilyProvider>(context);
    final trackingProvider = Provider.of<TrackingProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل المناسبات')),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_available, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        const Text('تسجيل مناسبة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 550;
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
                              trackingProvider.loadOccasions(selection.osraId!);
                            }
                          },
                        );

                        final nameField = TextField(
                          controller: _nameController,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'اسم المناسبة',
                            prefixIcon: Icon(Icons.celebration, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        );

                        final dateField = InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'التاريخ',
                              prefixIcon: Icon(Icons.calendar_month, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            child: Text(
                              _selectedDate.toLocal().toString().split(' ')[0],
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );

                        if (isDesktop) {
                          return Row(
                            children: [
                              Expanded(flex: 3, child: familyAutocomplete),
                              const SizedBox(width: 8),
                              Expanded(flex: 3, child: nameField),
                              const SizedBox(width: 8),
                              Expanded(flex: 3, child: dateField),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              familyAutocomplete,
                              const SizedBox(height: 12),
                              nameField,
                              const SizedBox(height: 12),
                              dateField,
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
                          onPressed: _selectedOsraId == null ? null : _addOccasion,
                          icon: const Icon(Icons.save_as),
                          label: const Text('تسجيل المناسبة'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: trackingProvider.occasions.isEmpty ? null : _printOccasions,
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('طباعة السجل'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            backgroundColor: Colors.blueGrey.shade700,
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
            Expanded(
              child: trackingProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedOsraId == null
                      ? const Center(child: Text('اختر أسرة لعرض سجل المناسبات'))
                      : ListView.builder(
                          itemCount: trackingProvider.occasions.length,
                          itemBuilder: (context, index) {
                            final occasion = trackingProvider.occasions[index];
                            return ListTile(
                              leading: const Icon(Icons.event_note, color: Colors.orange),
                              title: Text(occasion.monasbaName),
                              subtitle: Text(occasion.monasbaDate?.split('T')[0] ?? 'بدون تاريخ'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('شهر: ${occasion.month ?? "-"}'),
                                  const SizedBox(width: 8),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showEditOccasionDialog(occasion)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirmDeleteOccasion(occasion)),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOccasionDialog(Occasion occasion) {
    final nameController = TextEditingController(text: occasion.monasbaName);
    DateTime editDate = DateTime.parse(occasion.monasbaDate!);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل المناسبة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المناسبة')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('التاريخ: ${editDate.toLocal().toString().split(' ')[0]}')),
                  ElevatedButton(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: editDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setDialogState(() => editDate = picked);
                      }
                    },
                    child: const Text('تغيير'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final updatedOccasion = Occasion(
                    monasbaId: occasion.monasbaId,
                    osraId: occasion.osraId,
                    monasbaName: nameController.text,
                    monasbaDate: editDate.toIso8601String(),
                    month: editDate.month.toString(),
                  );
                  await Provider.of<TrackingProvider>(context, listen: false).updateOccasion(updatedOccasion);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteOccasion(Occasion occasion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مناسبة'),
        content: Text('هل أنت متأكد من حذف مناسبة "${occasion.monasbaName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await Provider.of<TrackingProvider>(context, listen: false).deleteOccasion(occasion.monasbaId!, occasion.osraId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
