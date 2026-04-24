import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/search_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../data/models/family_models.dart';
import '../../../data/models/lookup_models.dart';
import '../../../data/services/id_card_pdf_service.dart';
import 'id_card_settings_dialog.dart';

class IdCardGeneratorScreen extends StatefulWidget {
  const IdCardGeneratorScreen({super.key});

  @override
  State<IdCardGeneratorScreen> createState() => _IdCardGeneratorScreenState();
}

class _IdCardGeneratorScreenState extends State<IdCardGeneratorScreen> {
  final _nameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _mobileController = TextEditingController();
  final _jobController = TextEditingController();
  
  int? _selectedArea;
  int? _selectedStreet;
  int? _selectedSocial;
  int? _selectedEconomic;
  int? _selectedStage;
  int? _selectedHealth;
  int? _selectedMostwa;
  int? _selectedKaraba;

  bool _isLoading = false;
  
  // Search results
  List<Person> _searchResults = [];
  final Set<int> _selectedPersonIds = {};

  // Configuration toggles
  bool _showName = true;
  bool _showNationalId = true;
  bool _showMobile = true;
  bool _showJob = true;
  bool _showStage = true;
  bool _showBirthDate = false;
  String _barcodeType = 'qr'; // 'qr' or '1d'
  int _cardsPerRow = 2;
  int _cardsPerCol = 4;

  bool _printBack = false;
  final TextEditingController _backTopTextController = TextEditingController();
  final TextEditingController _backBottomTextController = TextEditingController();
  String? _backLogoBase64;

  // Mobile: toggle filter panel visibility
  bool _showFiltersOnMobile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
      
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      _backTopTextController.text = await settingsProvider.getSetting('id_card_back_top_text') ?? '';
      _backBottomTextController.text = await settingsProvider.getSetting('id_card_back_bottom_text') ?? '';
      _backLogoBase64 = await settingsProvider.getSetting('id_card_back_logo');
      final printBackSetting = await settingsProvider.getSetting('id_card_print_back');
      if (printBackSetting == 'true') {
        _printBack = true;
      }
      if (mounted) {
        setState(() {});
        _onSearch(); // Load all persons by default
      }
    });
  }

  void _onSearch() async {
    setState(() => _isLoading = true);
    
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    
    final results = await searchProvider.searchPersons(
      name: _nameController.text.isNotEmpty ? _nameController.text : null,
      nationalId: _nationalIdController.text.isNotEmpty ? _nationalIdController.text : null,
      mobile: _mobileController.text.isNotEmpty ? _mobileController.text : null,
      job: _jobController.text.isNotEmpty ? _jobController.text : null,
      areaId: _selectedArea,
      streetId: _selectedStreet,
      socialStatusId: _selectedSocial,
      economicStatusId: _selectedEconomic,
      stageId: _selectedStage,
      healthStatusId: _selectedHealth,
      mostwaId: _selectedMostwa,
      karabaId: _selectedKaraba,
    );

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedPersonIds.addAll(_searchResults.map((p) => p.personId!));
      } else {
        _selectedPersonIds.clear();
      }
    });
  }

  void _togglePersonSelection(int personId, bool? value) {
    setState(() {
      if (value == true) {
        _selectedPersonIds.add(personId);
      } else {
        _selectedPersonIds.remove(personId);
      }
    });
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => const IdCardSettingsDialog(),
    );
  }

  void _showConfigPanel() {
    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to manage state inside the dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إعدادات الطباعة', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('البيانات المعروضة في الكارنيه:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    SwitchListTile(title: const Text('الاسم'), value: _showName, onChanged: (v) { setDialogState(() => _showName = v); setState((){}); }),
                    SwitchListTile(title: const Text('الرقم القومي'), value: _showNationalId, onChanged: (v) { setDialogState(() => _showNationalId = v); setState((){}); }),
                    SwitchListTile(title: const Text('رقم الموبايل'), value: _showMobile, onChanged: (v) { setDialogState(() => _showMobile = v); setState((){}); }),
                    SwitchListTile(title: const Text('الوظيفة'), value: _showJob, onChanged: (v) { setDialogState(() => _showJob = v); setState((){}); }),
                    SwitchListTile(title: const Text('المرحلة'), value: _showStage, onChanged: (v) { setDialogState(() => _showStage = v); setState((){}); }),
                    SwitchListTile(title: const Text('تاريخ الميلاد'), value: _showBirthDate, onChanged: (v) { setDialogState(() => _showBirthDate = v); setState((){}); }),
                    const Divider(height: 24),
                    const Text('نوع الباركود:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 100, child: Text('النوع:')),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _barcodeType,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'qr', child: Text('بطاقة QR (مربع)')),
                              DropdownMenuItem(value: '1d', child: Text('باركود خطي (أعمدة)')),
                            ],
                            onChanged: (v) { setDialogState(() => _barcodeType = v!); setState((){}); },
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('تخطيط الصفحة (A4):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 100, child: Text('أعمدة:')),
                        Expanded(
                          child: DropdownButton<int>(
                            value: _cardsPerRow,
                            isExpanded: true,
                            items: [1, 2, 3].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                            onChanged: (v) { setDialogState(() => _cardsPerRow = v!); setState((){}); },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 100, child: Text('صفوف:')),
                        Expanded(
                          child: DropdownButton<int>(
                            value: _cardsPerCol,
                            isExpanded: true,
                            items: [2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                            onChanged: (v) { setDialogState(() => _cardsPerCol = v!); setState((){}); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'عدد الكارنيهات في الصفحة: ${_cardsPerRow * _cardsPerCol}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
                      ),
                    ),
                    const Divider(height: 24),
                    const Text('إعدادات ظهر الكارنيه:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SwitchListTile(
                      title: const Text('طباعة الظهر بعد كل صفحة', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: _printBack,
                      onChanged: (v) {
                        setDialogState(() => _printBack = v);
                        setState((){});
                        Provider.of<SettingsProvider>(context, listen: false).saveSetting('id_card_print_back', v ? 'true' : 'false');
                      },
                    ),
                    if (_printBack) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _backTopTextController,
                        decoration: const InputDecoration(labelText: 'الكتابة العلوية', border: OutlineInputBorder()),
                        onChanged: (val) {
                          Provider.of<SettingsProvider>(context, listen: false).saveSetting('id_card_back_top_text', val);
                        }
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _backBottomTextController,
                        decoration: const InputDecoration(labelText: 'الكتابة السفلية', border: OutlineInputBorder()),
                        onChanged: (val) {
                          Provider.of<SettingsProvider>(context, listen: false).saveSetting('id_card_back_bottom_text', val);
                        }
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.image),
                              label: const Text('اختيار اللوجو الخلفي'),
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(type: FileType.image);
                                if (result != null && result.files.single.path != null) {
                                  final bytes = await File(result.files.single.path!).readAsBytes();
                                  final base64String = base64Encode(bytes);
                                  setDialogState(() => _backLogoBase64 = base64String);
                                  setState((){});
                                  Provider.of<SettingsProvider>(context, listen: false).saveSetting('id_card_back_logo', base64String);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_backLogoBase64 != null && _backLogoBase64!.isNotEmpty) ...[
                            Container(
                              height: 48,
                              width: 48,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Image.memory(base64Decode(_backLogoBase64!), fit: BoxFit.contain),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'حذف اللوجو',
                              onPressed: () {
                                setDialogState(() => _backLogoBase64 = null);
                                setState((){});
                                Provider.of<SettingsProvider>(context, listen: false).deleteSetting('id_card_back_logo');
                              },
                            )
                          ]
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('تم', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _generatePdf() async {
    if (_selectedPersonIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد شخص واحد على الأقل')),
      );
      return;
    }
    
    final selectedPersons = _searchResults.where((p) => _selectedPersonIds.contains(p.personId)).toList();
    
    final lookupProvider = Provider.of<LookupProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    final config = IdCardConfig(
      showName: _showName,
      showNationalId: _showNationalId,
      showMobile: _showMobile,
      showJob: _showJob,
      showStage: _showStage,
      showBirthDate: _showBirthDate,
      barcodeType: _barcodeType,
      cardsPerRow: _cardsPerRow,
      cardsPerCol: _cardsPerCol,
      printBack: _printBack,
      backTopText: _backTopTextController.text,
      backBottomText: _backBottomTextController.text,
      backLogoBase64: _backLogoBase64,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('جاري إنشاء الكارنيهات لعدد ${selectedPersons.length} شخص...')),
    );

    try {
      await IdCardPdfService.generateAndPrint(selectedPersons, lookupProvider, settingsProvider, config);
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء معاينة الطباعة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    bool isAllSelected = _searchResults.isNotEmpty && 
        _searchResults.every((p) => _selectedPersonIds.contains(p.personId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('طباعة الكارنيهات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (isMobile)
            IconButton(
              icon: Icon(_showFiltersOnMobile ? Icons.filter_list_off : Icons.filter_list),
              tooltip: 'إظهار/إخفاء الفلاتر',
              onPressed: () => setState(() => _showFiltersOnMobile = !_showFiltersOnMobile),
            ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'إعدادات الطباعة (الحقول والمقاس)',
            onPressed: _showConfigPanel,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'اللوجو',
            onPressed: _showSettings,
          ),
        ],
      ),
      // Mobile: FAB for printing
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: _generatePdf,
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.print),
              label: Text('طباعة (${_selectedPersonIds.length})'),
            )
          : null,
      body: isMobile ? _buildMobileLayout(lookup, isAllSelected) : _buildDesktopLayout(lookup, isAllSelected),
    );
  }

  // ═══════════════════════════════════════════
  // DESKTOP LAYOUT (side-by-side)
  // ═══════════════════════════════════════════
  Widget _buildDesktopLayout(LookupProvider lookup, bool isAllSelected) {
    return Row(
      children: [
        // Left Side: Filters
        Container(
          width: 280,
          color: Colors.grey.shade50,
          child: Column(
            children: [
              Expanded(child: _buildFiltersList(lookup)),
              _buildSearchButton(),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // Right Side: Results & Multi-select
        Expanded(
          child: Column(
            children: [
              _buildToolbar(isAllSelected, showPrintButton: true),
              const Divider(height: 1, thickness: 1),
              Expanded(child: _buildResultsList(lookup)),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // MOBILE LAYOUT (stacked, filters in drawer)
  // ═══════════════════════════════════════════
  Widget _buildMobileLayout(LookupProvider lookup, bool isAllSelected) {
    return Column(
      children: [
        // Collapsible Filter Section
        if (_showFiltersOnMobile)
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: _buildFiltersList(lookup)),
                _buildSearchButton(),
              ],
            ),
          ),
        _buildToolbar(isAllSelected, showPrintButton: false),
        const Divider(height: 1, thickness: 1),
        Expanded(child: _buildResultsList(lookup)),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // SHARED COMPONENTS
  // ═══════════════════════════════════════════

  Widget _buildFiltersList(LookupProvider lookup) {
    return ListView(
      padding: const EdgeInsets.all(12),
      shrinkWrap: true,
      children: [
        const Text(
          'بحث شامل عن الأشخاص',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
        const SizedBox(height: 12),
        _buildTextField('الاسم', _nameController, Icons.person),
        const SizedBox(height: 8),
        _buildTextField('الرقم القومي', _nationalIdController, Icons.credit_card),
        const SizedBox(height: 8),
        _buildTextField('رقم الموبايل', _mobileController, Icons.phone),
        const SizedBox(height: 8),
        _buildTextField('الوظيفة', _jobController, Icons.work),
        const Divider(height: 24),
        _buildDropdown<int>('القرابة', lookup.karaba.map((k) => DropdownMenuItem(value: k['karaba_id'] as int, child: Text(k['karaba_name'] as String))).toList(), _selectedKaraba, (val) => setState(() => _selectedKaraba = val)),
        _buildDropdown<int>('المرحلة', lookup.stages.map((s) => DropdownMenuItem(value: s['stage_id'] as int, child: Text(s['stage_name'] as String))).toList(), _selectedStage, (val) => setState(() => _selectedStage = val)),
        _buildDropdown<int>('المستوى التعليمي', lookup.educationLevels.map((m) => DropdownMenuItem(value: m['mostwa_id'] as int, child: Text(m['mostwa_name'] as String))).toList(), _selectedMostwa, (val) => setState(() => _selectedMostwa = val)),
        _buildDropdown<int>('الحالة الاجتماعية', lookup.socialStatus.map((h) => DropdownMenuItem(value: h['hala_egtimaia_id'] as int, child: Text(h['hala_name'] as String))).toList(), _selectedSocial, (val) => setState(() => _selectedSocial = val)),
        _buildDropdown<int>('الحالة الصحية', lookup.healthStatus.map((h) => DropdownMenuItem(value: h['hala_sehia_id'] as int, child: Text(h['hala_name'] as String))).toList(), _selectedHealth, (val) => setState(() => _selectedHealth = val)),
        _buildDropdown<int>('المنطقة', lookup.areas.map((a) => DropdownMenuItem(value: a.areaId, child: Text(a.areaName))).toList(), _selectedArea, (val) {
          setState(() { _selectedArea = val; _selectedStreet = null; });
          lookup.loadStreets(val!);
        }),
        if (_selectedArea != null)
          _buildDropdown<int>('الشارع', lookup.streets.map((s) => DropdownMenuItem(value: s.streetId, child: Text(s.streetName))).toList(), _selectedStreet, (val) => setState(() => _selectedStreet = val)),
      ],
    );
  }

  Widget _buildSearchButton() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            _onSearch();
            // On mobile, close filters after search
            if (MediaQuery.of(context).size.width < 700) {
              setState(() => _showFiltersOnMobile = false);
            }
          },
          icon: const Icon(Icons.search),
          label: const Text('بحث', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(bool isAllSelected, {required bool showPrintButton}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Checkbox(
            value: isAllSelected,
            onChanged: _searchResults.isEmpty ? null : _toggleSelectAll,
          ),
          Expanded(
            child: Text(
              'الكل (${_searchResults.length}) | تم تحديد: ${_selectedPersonIds.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showPrintButton)
            ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 18),
              label: const Text('طباعة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: _generatePdf,
            ),
        ],
      ),
    );
  }

  Widget _buildResultsList(LookupProvider lookup) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد نتائج. استخدم الفلاتر للبحث.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final person = _searchResults[index];
        final isSelected = _selectedPersonIds.contains(person.personId);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (val) => _togglePersonSelection(person.personId!, val),
            title: Text(person.personName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'المرحلة: ${lookup.getStageName(person.stageId)} | الوظيفة: ${person.wazefa ?? "---"}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            secondary: CircleAvatar(
              backgroundColor: Colors.indigo.shade50,
              child: const Icon(Icons.person, color: Colors.indigo),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        isDense: true,
      ),
    );
  }

  Widget _buildDropdown<T>(String label, List<DropdownMenuItem<T>> items, T? value, void Function(T?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          isDense: true,
        ),
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }
}
