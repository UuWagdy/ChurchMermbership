import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../data/models/family_models.dart';
import '../../../data/models/lookup_models.dart';

class FamilyListScreen extends StatefulWidget {
  const FamilyListScreen({super.key});

  @override
  State<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends State<FamilyListScreen> {
  final _searchController = TextEditingController();
  
  // Search Filters State
  bool _filtersVisible = false;
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _jobController = TextEditingController();
  final _personCountController = TextEditingController();
  final _ageMinController = TextEditingController();
  final _ageMaxController = TextEditingController();

  List<int> _selectedAreaIds = [];
  int? _selectedStreet;
  List<int> _selectedSocialIds = [];
  List<int> _selectedEconomicIds = [];
  List<int> _selectedStageIds = [];
  List<int> _selectedHealthIds = [];
  int? _selectedFather;
  List<int> _selectedMostwaIds = [];
  List<int> _selectedKarabaIds = [];
  List<String> _selectedMonths = [];

  // National ID filters
  String? _nidGovCode;
  String? _nidGender;
  final _nidAgeMinController = TextEditingController();
  final _nidAgeMaxController = TextEditingController();
  DateTime? _nidBirthDateMin;
  DateTime? _nidBirthDateMax;

  static const Map<String, String> _governorates = {
    "01": "القاهرة",
    "02": "الإسكندرية",
    "03": "بورسعيد",
    "04": "السويس",
    "11": "دمياط",
    "12": "الدقهلية",
    "13": "الشرقية",
    "14": "القليوبية",
    "15": "كفر الشيخ",
    "16": "الغربية",
    "17": "المنوفية",
    "18": "البحيرة",
    "19": "الإسماعيلية",
    "21": "الجيزة",
    "22": "بني سويف",
    "23": "الفيوم",
    "24": "المنيا",
    "25": "أسيوط",
    "26": "سوهاج",
    "27": "قنا",
    "28": "أسوان",
    "29": "الأقصر",
    "31": "البحر الأحمر",
    "32": "الوادي الجديد",
    "33": "مطروح",
    "34": "شمال سيناء",
    "35": "جنوب سيناء",
    "88": "خارج الجمهورية",
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FamilyProvider>(context, listen: false).loadFamilies();
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _jobController.dispose();
    _personCountController.dispose();
    _ageMinController.dispose();
    _ageMaxController.dispose();
    _nidAgeMinController.dispose();
    _nidAgeMaxController.dispose();
    super.dispose();
  }

  void _onSearch() {
    Provider.of<FamilyProvider>(context, listen: false).loadFamilies(query: _searchController.text);
  }

  void _onComplexSearch() {
    Provider.of<FamilyProvider>(context, listen: false).loadFamiliesWithComplexFilters(
      areaIds: _selectedAreaIds,
      streetId: _selectedStreet,
      mobile: _mobileController.text,
      birthMonths: _selectedMonths.isEmpty ? null : _selectedMonths,
      personCount: int.tryParse(_personCountController.text),
      socialStatusIds: _selectedSocialIds.isEmpty ? null : _selectedSocialIds,
      economicStatusIds: _selectedEconomicIds.isEmpty ? null : _selectedEconomicIds,
      stageIds: _selectedStageIds.isEmpty ? null : _selectedStageIds,
      job: _jobController.text,
      ageMin: int.tryParse(_ageMinController.text),
      ageMax: int.tryParse(_ageMaxController.text),
      name: _nameController.text.isNotEmpty ? _nameController.text : (_searchController.text.isNotEmpty ? _searchController.text : null),
      healthStatusIds: _selectedHealthIds.isEmpty ? null : _selectedHealthIds,
      fatherId: _selectedFather,
      mostwaIds: _selectedMostwaIds.isEmpty ? null : _selectedMostwaIds,
      karabaIds: _selectedKarabaIds.isEmpty ? null : _selectedKarabaIds,
      nidGov: _nidGovCode,
      nidGender: _nidGender,
      nidAgeMin: int.tryParse(_nidAgeMinController.text),
      nidAgeMax: int.tryParse(_nidAgeMaxController.text),
      nidBirthDateMin: _nidBirthDateMin?.toIso8601String().split('T')[0],
      nidBirthDateMax: _nidBirthDateMax?.toIso8601String().split('T')[0],
    );
  }

  void _clearFilters() {
    setState(() {
      _nameController.clear();
      _mobileController.clear();
      _jobController.clear();
      _personCountController.clear();
      _ageMinController.clear();
      _ageMaxController.clear();
      _selectedAreaIds.clear();
      _selectedStreet = null;
      _selectedSocialIds.clear();
      _selectedEconomicIds.clear();
      _selectedStageIds.clear();
      _selectedHealthIds.clear();
      _selectedFather = null;
      _selectedMostwaIds.clear();
      _selectedKarabaIds.clear();
      _selectedMonths.clear();
      _nidGovCode = null;
      _nidGender = null;
      _nidAgeMinController.clear();
      _nidAgeMaxController.clear();
      _nidBirthDateMin = null;
      _nidBirthDateMax = null;
    });
    _onSearch();
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = Provider.of<FamilyProvider>(context);
    final lookupProvider = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأسر'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_filtersVisible ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() {
                _filtersVisible = !_filtersVisible;
              });
            },
            tooltip: 'تصفية وبحث متقدم',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, size: 28),
            onPressed: () => Navigator.of(context).pushNamed('/family-form'),
            tooltip: 'إضافة أسرة جديدة',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: 'بحث باسم الأسرة',
                      hintText: 'اكتب اسم الأسرة أو رقم التليفون...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: _filtersVisible ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _filtersVisible = !_filtersVisible;
                      });
                    },
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _filtersVisible ? Colors.transparent : Colors.grey.shade400,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.filter_alt_rounded,
                        color: _filtersVisible ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _filtersVisible
                ? SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: _buildFiltersCard(lookupProvider),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: familyProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : familyProvider.families.isEmpty
                    ? const Center(
                        child: Text(
                          'لا يوجد أسر مطابقة للبحث',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24, top: 8),
                        itemCount: familyProvider.families.length,
                        itemBuilder: (context, index) {
                          final family = familyProvider.families[index];
                          return _buildFamilyCard(context, family, lookupProvider, familyProvider);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard(LookupProvider lookup) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم (أسرة أو فرد)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: [
                  _buildModernField(
                    label: 'المناطق',
                    child: _ListMultiSelectField<int>(
                      label: 'المناطق',
                      title: 'اختر المناطق',
                      items: lookup.areas.map((a) => a.areaId!).toList(),
                      selectedItems: _selectedAreaIds,
                      itemLabel: (id) => lookup.areas.firstWhere((a) => a.areaId == id).areaName,
                      onSaved: (result) {
                        setState(() {
                          _selectedAreaIds = result;
                          _selectedStreet = null;
                        });
                        if (_selectedAreaIds.isNotEmpty) {
                          lookup.loadStreetsForAreas(_selectedAreaIds);
                        } else {
                          lookup.loadStreetsForAreas([]);
                        }
                      },
                    ),
                  ),
                  _buildModernField(
                    label: 'الشارع',
                    child: DropdownButtonFormField<int>(
                      value: _selectedStreet,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: lookup.streets.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s.streetId as int, child: Text(s.streetName))).toList(),
                      onChanged: (val) => setState(() => _selectedStreet = val),
                    ),
                  ),
                  _buildModernField(
                    label: 'شهر الميلاد',
                    child: _ListMultiSelectField<String>(
                      label: 'شهر الميلاد',
                      title: 'اختر شهر الميلاد',
                      items: List.generate(12, (i) => (i + 1).toString()),
                      selectedItems: _selectedMonths,
                      itemLabel: (m) => m,
                      onSaved: (result) {
                        setState(() {
                          _selectedMonths = result;
                        });
                      },
                    ),
                  ),
                  _buildModernField(
                    label: 'رقم الموبايل',
                    child: TextField(controller: _mobileController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                  ),
                  _buildModernField(
                    label: 'الوظيفة',
                    child: TextField(controller: _jobController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                  ),
                  _buildModernField(
                    label: 'عدد الأفراد',
                    child: TextField(controller: _personCountController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                  ),
                  _buildModernField(
                    label: 'السن من',
                    child: TextField(controller: _ageMinController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                  ),
                  _buildModernField(
                    label: 'السن إلى',
                    child: TextField(controller: _ageMaxController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                  ),
                  _buildModernField(
                    label: 'الحالة الاجتماعية',
                    child: _ListMultiSelectField<int>(
                      label: 'الحالة الاجتماعية',
                      title: 'اختر الحالة الاجتماعية',
                      items: lookup.socialStatus.map<int>((s) => s['hala_egtimaia_id'] as int).toList(),
                      selectedItems: _selectedSocialIds,
                      itemLabel: (id) => lookup.socialStatus.firstWhere((s) => s['hala_egtimaia_id'] == id)['hala_name'] as String,
                      onSaved: (result) {
                        setState(() {
                          _selectedSocialIds = result;
                        });
                      },
                    ),
                  ),
                  _buildModernField(
                    label: 'الحالة الاقتصادية',
                    child: _ListMultiSelectField<int>(
                      label: 'الحالة الاقتصادية',
                      title: 'اختر الحالة الاقتصادية',
                      items: lookup.economicStatus.map<int>((e) => e['e_s_id'] as int).toList(),
                      selectedItems: _selectedEconomicIds,
                      itemLabel: (id) => lookup.economicStatus.firstWhere((e) => e['e_s_id'] == id)['e_s_name'] as String,
                      onSaved: (result) {
                        setState(() {
                          _selectedEconomicIds = result;
                        });
                      },
                    ),
                  ),
                  _buildModernField(
                    label: 'الحالة الصحية',
                    child: _ListMultiSelectField<int>(
                      label: 'الحالة الصحية',
                      title: 'اختر الحالة الصحية',
                      items: lookup.healthStatus.map<int>((h) => h['hala_sehia_id'] as int).toList(),
                      selectedItems: _selectedHealthIds,
                      itemLabel: (id) => lookup.healthStatus.firstWhere((h) => h['hala_sehia_id'] == id)['hala_name'] as String,
                      onSaved: (result) {
                        setState(() {
                          _selectedHealthIds = result;
                        });
                      },
                    ),
                  ),
                  _buildModernField(
                    label: 'المرحلة',
                    child: _ListMultiSelectField<int>(
                      label: 'المرحلة',
                      title: 'اختر المرحلة',
                      items: lookup.stages.map<int>((s) => s['stage_id'] as int).toList(),
                      selectedItems: _selectedStageIds,
                      itemLabel: (id) => lookup.stages.firstWhere((s) => s['stage_id'] == id)['stage_name'] as String,
                      onSaved: (result) {
                        setState(() {
                          _selectedStageIds = result;
                        });
                      },
                    ),
                  ),
                  _buildModernField(
                    label: 'المؤهل (التعليم)',
                    child: _ListMultiSelectField<int>(
                      label: 'المؤهل (التعليم)',
                      title: 'اختر المؤهل (التعليم)',
                      items: lookup.educationLevels.map<int>((m) => m['mostwa_id'] as int).toList(),
                      selectedItems: _selectedMostwaIds,
                      itemLabel: (id) => lookup.educationLevels.firstWhere((m) => m['mostwa_id'] == id)['mostwa_name'] as String,
                      onSaved: (result) {
                        setState(() {
                          _selectedMostwaIds = result;
                        });
                      },
                    ),
                  ),
                  _buildModernField(
                    label: 'أب الاعتراف / الكاهن',
                    child: DropdownButtonFormField<int>(
                      value: _selectedFather,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: lookup.fathers.map<DropdownMenuItem<int>>((f) => DropdownMenuItem<int>(value: f.fatherId as int, child: Text(f.fatherName))).toList(),
                      onChanged: (val) => setState(() => _selectedFather = val),
                    ),
                  ),
                  _buildModernField(
                    label: 'صلة القرابة',
                    child: _ListMultiSelectField<int>(
                      label: 'صلة القرابة',
                      title: 'اختر صلة القرابة',
                      items: lookup.karaba.map<int>((k) => k['karaba_id'] as int).toList(),
                      selectedItems: _selectedKarabaIds,
                      itemLabel: (id) => lookup.karaba.firstWhere((k) => k['karaba_id'] == id)['karaba_name'] as String,
                      onSaved: (result) {
                        setState(() {
                          _selectedKarabaIds = result;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ═══ National ID Filters Section ═══
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade50, Colors.cyan.shade50],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.badge, color: Colors.teal.shade700, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'الناتج من الرقم القومي',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12.0,
                      runSpacing: 12.0,
                      children: [
                        _buildModernField(
                          label: 'المحافظة (من الرقم القومي)',
                          child: DropdownButtonFormField<String>(
                            value: _nidGovCode,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('الكل')),
                              ..._governorates.entries.map((e) => DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(e.value),
                              )),
                            ],
                            onChanged: (val) => setState(() => _nidGovCode = val),
                          ),
                        ),
                        _buildModernField(
                          label: 'النوع (من الرقم القومي)',
                          child: DropdownButtonFormField<String>(
                            value: _nidGender,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem<String>(value: null, child: Text('الكل')),
                              DropdownMenuItem<String>(value: 'ذكر', child: Text('ذكر')),
                              DropdownMenuItem<String>(value: 'أنثى', child: Text('أنثى')),
                            ],
                            onChanged: (val) => setState(() => _nidGender = val),
                          ),
                        ),
                        _buildModernField(
                          label: 'السن من (الرقم القومي)',
                          child: TextField(
                            controller: _nidAgeMinController,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        _buildModernField(
                          label: 'السن إلى (الرقم القومي)',
                          child: TextField(
                            controller: _nidAgeMaxController,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        _buildModernField(
                          label: 'تاريخ الميلاد من',
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _nidBirthDateMin ?? DateTime(2000),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) setState(() => _nidBirthDateMin = d);
                            },
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _nidBirthDateMin == null
                                      ? 'اختر التاريخ'
                                      : _nidBirthDateMin!.toIso8601String().split('T')[0],
                                    style: TextStyle(fontSize: 14, color: _nidBirthDateMin == null ? Colors.grey : Colors.black),
                                  ),
                                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _buildModernField(
                          label: 'تاريخ الميلاد إلى',
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _nidBirthDateMax ?? DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) setState(() => _nidBirthDateMax = d);
                            },
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _nidBirthDateMax == null
                                      ? 'اختر التاريخ'
                                      : _nidBirthDateMax!.toIso8601String().split('T')[0],
                                    style: TextStyle(fontSize: 14, color: _nidBirthDateMax == null ? Colors.grey : Colors.black),
                                  ),
                                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _onComplexSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('تطبيق الفلاتر'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('مسح الفلاتر'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernField({required String label, required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 600 ? 250.0 : (constraints.maxWidth - 24) / 2;
        return SizedBox(
          width: width.clamp(140.0, 400.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 4),
              child,
            ],
          ),
        );
      }
    );
  }

  Widget _buildFamilyCard(BuildContext context, Family family, LookupProvider lookup, FamilyProvider familyProvider) {
    final karabaName = lookup.getKarabaName(family.karabaId);
    final esName = lookup.getEconomicStatusName(family.eSId);
    final halaName = lookup.getHalaEgtimaiaName(family.halaEgtimaiaId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pushNamed('/family-form', arguments: family);
        },
        onLongPress: () => _confirmDelete(context, family, familyProvider),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    radius: 24,
                    child: Icon(Icons.family_restroom, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          family.osraName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.numbers, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'كود: ${family.code ?? 'غير مسجل'}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context, family, familyProvider),
                    tooltip: 'حذف الأسرة',
                  ),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.people, 'الأفراد: ${family.memberCount}', Colors.blue),
                  if (karabaName != '---') _buildInfoChip(Icons.diversity_3, karabaName, Colors.teal),
                  if (halaName != '---') _buildInfoChip(Icons.favorite, halaName, Colors.deepPurple),
                  if (esName != '---') _buildInfoChip(Icons.account_balance_wallet, esName, Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (family.phone != null && family.phone!.isNotEmpty) ...[
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(family.phone!, style: TextStyle(color: Colors.grey[800])),
                    const SizedBox(width: 16),
                  ],
                  if (family.rakmKomy != null && family.rakmKomy!.isNotEmpty) ...[
                    Icon(Icons.credit_card, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(family.rakmKomy!, style: TextStyle(color: Colors.grey[800])),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color.shade900, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Family family, FamilyProvider familyProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الأسرة'),
        content: Text('هل أنت متأكد من حذف أسرة ${family.osraName} وكل البيانات المتعلقة بها (أفراد، افتقادات، مساعدات، إلخ)؟\n\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              familyProvider.deleteFamily(family.osraId!);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ListMultiSelectField<T> extends StatelessWidget {
  final String label;
  final String title;
  final List<T> items;
  final List<T> selectedItems;
  final String Function(T) itemLabel;
  final void Function(List<T>) onSaved;

  const _ListMultiSelectField({
    super.key,
    required this.label,
    required this.title,
    required this.items,
    required this.selectedItems,
    required this.itemLabel,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final List<T> tempSelected = List.from(selectedItems);
        final result = await showDialog<List<T>>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: 300,
                  height: 400,
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('تحديد الكل'),
                        value: tempSelected.length == items.length && items.isNotEmpty,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSelected.clear();
                              tempSelected.addAll(items);
                            } else {
                              tempSelected.clear();
                            }
                          });
                        },
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (c, idx) {
                            final item = items[idx];
                            final isChecked = tempSelected.contains(item);
                            return CheckboxListTile(
                              title: Text(itemLabel(item)),
                              value: isChecked,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    tempSelected.add(item);
                                  } else {
                                    tempSelected.remove(item);
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
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, tempSelected),
                    child: const Text('موافق'),
                  ),
                ],
              );
            },
          ),
        );
        if (result != null) {
          onSaved(result);
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedItems.isEmpty
                    ? 'اختر $label'
                    : selectedItems.length == items.length
                        ? 'كل $label'
                        : selectedItems.map(itemLabel).join('، '),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
