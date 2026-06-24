import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../data/services/pdf_service.dart';
import '../../../data/models/family_models.dart';

class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Scroll and Header States
  late ScrollController _groupScrollController;
  late ScrollController _singleScrollController;
  bool _showGroupHeader = true;
  bool _showSingleHeader = true;

  // Tab 1: Group Visits States
  List<int> _selectedAreaIds = [];
  List<Map<String, dynamic>> _filteredFamilies = [];
  final Set<int> _checkedFamilyIds = {};
  DateTime _visitDate = DateTime.now();
  final _groupNotesController = TextEditingController();
  bool _isGroupLoading = false;
  String _searchQuery = '';

  // Tab 2: Single Family States
  int? _selectedOsraId;
  final _singleNotesController = TextEditingController();
  DateTime _singleVisitDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _groupScrollController = ScrollController();
    _singleScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lookup = Provider.of<LookupProvider>(context, listen: false);
      lookup.loadAllLookups();
      Provider.of<FamilyProvider>(context, listen: false).loadFamilies();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNotesController.dispose();
    _singleNotesController.dispose();
    _groupScrollController.dispose();
    _singleScrollController.dispose();
    super.dispose();
  }

  // Load families with their last visit dates based on selected areas
  Future<void> _loadGroupFamilies() async {
    if (_selectedAreaIds.isEmpty) {
      setState(() {
        _filteredFamilies = [];
        _checkedFamilyIds.clear();
      });
      return;
    }

    setState(() => _isGroupLoading = true);
    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    final data = await familyProvider.getFamiliesWithLastVisit(_selectedAreaIds);
    setState(() {
      _filteredFamilies = data;
      _checkedFamilyIds.clear();
      _isGroupLoading = false;
    });
  }

  void _saveGroupVisits() async {
    if (_checkedFamilyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك اختر أسرة واحدة على الأقل لتسجيل الافتقاد')),
      );
      return;
    }

    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
    setState(() => _isGroupLoading = true);

    try {
      await trackingProvider.addBatchVisits(
        osraIds: _checkedFamilyIds.toList(),
        notes: _groupNotesController.text,
        date: _visitDate,
      );
      _groupNotesController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الافتقاد للأسر المحددة بنجاح')),
      );
      await _loadGroupFamilies();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التسجيل: $e')),
      );
    } finally {
      setState(() => _isGroupLoading = false);
    }
  }

  void _addSingleVisit() async {
    if (_selectedOsraId == null) return;
    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
    await trackingProvider.addVisitWithDate(
      _selectedOsraId!,
      _singleNotesController.text,
      _singleVisitDate,
    );
    _singleNotesController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الزيارة بنجاح')),
    );
  }

  void _printVisits() async {
    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
    if (trackingProvider.visits.isEmpty) return;

    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    final familyName = familyProvider.families.firstWhere((f) => f.osraId == _selectedOsraId).osraName;

    final headers = ['م', 'التاريخ', 'ملاحظات الزيارة'];
    final data = trackingProvider.visits.asMap().entries.map((e) {
      final visit = e.value;
      return [
        (e.key + 1).toString(),
        visit.date.split('T')[0],
        visit.notes ?? '---',
      ];
    }).toList();

    final pdfService = PdfService();
    await pdfService.generateTableReport(
      title: 'سجل زيارات وافتقاد أسرة: $familyName',
      headers: headers,
      data: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);
    final familyProvider = Provider.of<FamilyProvider>(context);
    final trackingProvider = Provider.of<TrackingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الافتقاد والزيارات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.group_add), text: 'الافتقاد الجماعي بالفلاتر'),
            Tab(icon: Icon(Icons.person_pin), text: 'زيارات أسرة محددة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupVisitsTab(lookup),
          _buildSingleFamilyTab(familyProvider, trackingProvider),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Tab 1: Group Visits Layout
  // ═══════════════════════════════════════════
  Widget _buildGroupVisitsTab(LookupProvider lookup) {
    final query = _searchQuery.trim().toLowerCase();
    final displayedFamilies = _filteredFamilies.where((f) {
      if (query.isEmpty) return true;
      final name = (f['osra_name'] as String).toLowerCase();
      final code = (f['code']?.toString() ?? '').toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        Widget buildAreaSelect() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('المناطق المفتقدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final List<int> tempSelected = List.from(_selectedAreaIds);
                  final result = await showDialog<List<int>>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (context, setDialogState) {
                        return AlertDialog(
                          title: const Text('اختر المناطق'),
                          content: SizedBox(
                            width: 300,
                            height: 400,
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  title: const Text('تحديد الكل'),
                                  value: tempSelected.length == lookup.areas.length,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        tempSelected.clear();
                                        tempSelected.addAll(lookup.areas.map((a) => a.areaId!));
                                      } else {
                                        tempSelected.clear();
                                      }
                                    });
                                  },
                                ),
                                const Divider(),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: lookup.areas.length,
                                    itemBuilder: (c, idx) {
                                      final area = lookup.areas[idx];
                                      final isChecked = tempSelected.contains(area.areaId);
                                      return CheckboxListTile(
                                        title: Text(area.areaName),
                                        value: isChecked,
                                        onChanged: (val) {
                                          setDialogState(() {
                                            if (val == true) {
                                              tempSelected.add(area.areaId!);
                                            } else {
                                              tempSelected.remove(area.areaId!);
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('إلغاء')),
                            TextButton(onPressed: () => Navigator.pop(ctx, tempSelected), child: const Text('موافق')),
                          ],
                        );
                      },
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _selectedAreaIds = result;
                    });
                    _loadGroupFamilies();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedAreaIds.isEmpty
                              ? 'اختر المناطق لبدء الفلترة'
                              : _selectedAreaIds.length == lookup.areas.length
                                  ? 'كل المناطق'
                                  : lookup.areas
                                      .where((a) => _selectedAreaIds.contains(a.areaId))
                                      .map((a) => a.areaName)
                                      .join('، '),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        Widget buildDatePicker() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تاريخ الافتقاد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _visitDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _visitDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_visitDate.toLocal().toString().split(' ')[0]),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.reverse) {
              if (notification.metrics.pixels > 100 && _showGroupHeader) {
                setState(() => _showGroupHeader = false);
              }
            } else if (notification.direction == ScrollDirection.forward) {
              if (!_showGroupHeader) {
                setState(() => _showGroupHeader = true);
              }
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _groupScrollController,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter Area & Visit Settings
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showGroupHeader
                      ? Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                if (isMobile) ...[
                                  buildAreaSelect(),
                                  const SizedBox(height: 12),
                                  buildDatePicker(),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(child: buildAreaSelect()),
                                      const SizedBox(width: 16),
                                      Expanded(child: buildDatePicker()),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                                // Notes Input
                                TextField(
                                  controller: _groupNotesController,
                                  decoration: const InputDecoration(
                                    labelText: 'ملاحظات الافتقاد المشتركة للأسر المحددة (مثال: زيارة دورية / توزيع لحوم)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                // Search Input Field
                if (_filteredFamilies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'بحث بالاسم أو الكود لتصفية القائمة...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                // Checkbox controls
                if (_filteredFamilies.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: displayedFamilies.isNotEmpty && displayedFamilies.every((f) => _checkedFamilyIds.contains(f['osra_id'] as int)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  for (var f in displayedFamilies) {
                                    _checkedFamilyIds.add(f['osra_id'] as int);
                                  }
                                } else {
                                  for (var f in displayedFamilies) {
                                    _checkedFamilyIds.remove(f['osra_id'] as int);
                                  }
                                }
                              });
                            },
                          ),
                          const Text('تحديد معروض الكل', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text('المعروض: ${displayedFamilies.length} (المحدد: ${_checkedFamilyIds.length} إجماليًا)'),
                    ],
                  ),
                // Families List Table
                if (_isGroupLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filteredFamilies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: Text('من فضلك اختر منطقة واحدة على الأقل لعرض الأسر')),
                  )
                else if (displayedFamilies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: Text('لا توجد نتائج بحث تطابق استعلامك')),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedFamilies.length,
                    itemBuilder: (ctx, index) {
                      final family = displayedFamilies[index];
                      final id = family['osra_id'] as int;
                      final code = family['code']?.toString() ?? 'بدون كود';
                      final isChecked = _checkedFamilyIds.contains(id);
                      final lastVisit = family['last_visit_date'] != null
                          ? (family['last_visit_date'] as String).split('T')[0]
                          : 'لم يفتقد من قبل';
  
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: CheckboxListTile(
                          title: Row(
                            children: [
                              Text(family['osra_name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('(# كود: $code)', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                          subtitle: Text(
                            'العنوان: ${family['area_name'] ?? ""} - ${family['street_name'] ?? ""} ${family['dalil_name'] != null ? "(${family['dalil_name']})" : ""}\nآخر افتقاد: $lastVisit',
                            style: const TextStyle(fontSize: 13),
                          ),
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _checkedFamilyIds.add(id);
                              } else {
                                _checkedFamilyIds.remove(id);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                // Save Button
                if (_filteredFamilies.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _isGroupLoading ? null : _saveGroupVisits,
                    icon: const Icon(Icons.done_all),
                    label: const Text('تسجيل الافتقاد للمحددين', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // Tab 2: Single Family Visits Layout
  // ═══════════════════════════════════════════
  Widget _buildSingleFamilyTab(FamilyProvider familyProvider, TrackingProvider trackingProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        Widget buildDatePicker() {
          return InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _singleVisitDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _singleVisitDate = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_singleVisitDate.toLocal().toString().split(' ')[0]),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          );
        }

        Widget buildAutocomplete() {
          return Autocomplete<Family>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return familyProvider.families;
              }
              return familyProvider.families.where((Family option) {
                final name = option.osraName.toLowerCase();
                final code = (option.code?.toString() ?? '').toLowerCase();
                final query = textEditingValue.text.toLowerCase();
                return name.contains(query) || code.contains(query);
              });
            },
            displayStringForOption: (Family option) => '${option.osraName} (كود: ${option.code ?? "---"})',
            optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Family> onSelected, Iterable<Family> options) {
              return Align(
                alignment: Alignment.topRight,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 300,
                      maxWidth: isMobile ? constraints.maxWidth - 32 : constraints.maxWidth * 0.5,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Family option = options.elementAt(index);
                        return ListTile(
                          title: Text('${option.osraName} (كود: ${option.code ?? "---"})'),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
              if (_selectedOsraId != null && textEditingController.text.isEmpty) {
                final selectedFamily = familyProvider.families.firstWhere(
                  (f) => f.osraId == _selectedOsraId,
                  orElse: () => Family(osraName: ''),
                );
                if (selectedFamily.osraName.isNotEmpty) {
                  textEditingController.text = '${selectedFamily.osraName} (كود: ${selectedFamily.code ?? "---"})';
                }
              }
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'اختر الأسرة (بحث بالاسم أو الكود)',
                  prefixIcon: Icon(Icons.people),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  if (val.isEmpty) {
                    setState(() {
                      _selectedOsraId = null;
                    });
                  } else {
                    final currentFamily = familyProvider.families.firstWhere(
                      (f) => f.osraId == _selectedOsraId,
                      orElse: () => Family(osraName: ''),
                    );
                    final expectedText = '${currentFamily.osraName} (كود: ${currentFamily.code ?? "---"})';
                    if (val != expectedText) {
                      setState(() {
                        _selectedOsraId = null;
                      });
                    }
                  }
                },
              );
            },
            onSelected: (Family selection) {
              setState(() {
                _selectedOsraId = selection.osraId;
              });
              if (selection.osraId != null) {
                trackingProvider.loadVisits(selection.osraId!);
              }
            },
          );
        }

        Widget buildNotesField() {
          return TextField(
            controller: _singleNotesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات الزيارة',
              prefixIcon: Icon(Icons.note),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          );
        }

        Widget buildSaveButton() {
          return ElevatedButton.icon(
            onPressed: _selectedOsraId == null ? null : _addSingleVisit,
            icon: const Icon(Icons.add),
            label: const Text('تسجيل زيارة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          );
        }

        Widget buildPrintButton() {
          return ElevatedButton.icon(
            onPressed: trackingProvider.visits.isEmpty ? null : _printVisits,
            icon: const Icon(Icons.print),
            label: const Text('طباعة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          );
        }

        return NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.reverse) {
              if (notification.metrics.pixels > 100 && _showSingleHeader) {
                setState(() => _showSingleHeader = false);
              }
            } else if (notification.direction == ScrollDirection.forward) {
              if (!_showSingleHeader) {
                setState(() => _showSingleHeader = true);
              }
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _singleScrollController,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showSingleHeader
                      ? Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isMobile) ...[
                                  buildAutocomplete(),
                                  const SizedBox(height: 12),
                                  buildDatePicker(),
                                  const SizedBox(height: 12),
                                  buildNotesField(),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: buildSaveButton()),
                                      const SizedBox(width: 8),
                                      Expanded(child: buildPrintButton()),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(flex: 3, child: buildAutocomplete()),
                                      const SizedBox(width: 16),
                                      Expanded(flex: 2, child: buildDatePicker()),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(child: buildNotesField()),
                                      const SizedBox(width: 12),
                                      buildSaveButton(),
                                      const SizedBox(width: 12),
                                      buildPrintButton(),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                // Visits History
                if (trackingProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_selectedOsraId == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: Text('اختر أسرة لعرض سجل زياراتها تفصيلياً')),
                  )
                else if (trackingProvider.visits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: Text('لم يتم تسجيل زيارات لهذه الأسرة من قبل')),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: trackingProvider.visits.length,
                    itemBuilder: (context, index) {
                      final visit = trackingProvider.visits[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.calendar_month, color: Colors.amber),
                          title: Text(visit.date.split('T')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(visit.notes ?? 'بدون ملاحظات'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('حذف الزيارة'),
                                  content: const Text('هل أنت متأكد من حذف هذا السجل بشكل نهائي؟'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                                    TextButton(
                                      onPressed: () async {
                                        await trackingProvider.deleteVisit(visit.visitId!, _selectedOsraId!);
                                        if (mounted) Navigator.pop(ctx);
                                      },
                                      child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
