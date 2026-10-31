import 'dart:async';
import '../../../data/models/tracking_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/search_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/models/lookup_models.dart';
import '../../../data/repositories/financial_repository.dart';
import '../../../data/services/pdf_service.dart';
import '../../widgets/theme_toggle_button.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  bool _isLoading = false;
  bool _expensesOnly = false;
  Timer? _searchTimer;
  final Map<int, Future<List<Expense>>> _expenseResults = {};
  bool _showMembers = true;
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
      if (!mounted) return;
      Provider.of<SearchProvider>(context, listen: false).clearResults();
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expensesOnly = ModalRoute.of(context)?.settings.arguments == 'expenses';
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    for (final controller in [
      _nameController,
      _mobileController,
      _jobController,
      _personCountController,
      _ageMinController,
      _ageMaxController,
      _nidAgeMinController,
      _nidAgeMaxController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scheduleSearch(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _onSearch();
    });
  }

  void _onSearch() {
    _searchTimer?.cancel();
    _expenseResults.clear();
    Provider.of<SearchProvider>(context, listen: false).performSearch(
      expensesOnly: _expensesOnly,
      areaIds: _selectedAreaIds,
      streetId: _selectedStreet,
      mobile: _mobileController.text,
      birthMonths: _selectedMonths.isEmpty ? null : _selectedMonths,
      personCount: int.tryParse(_personCountController.text),
      socialStatusIds: _selectedSocialIds.isEmpty ? null : _selectedSocialIds,
      economicStatusIds: _selectedEconomicIds.isEmpty
          ? null
          : _selectedEconomicIds,
      stageIds: _selectedStageIds.isEmpty ? null : _selectedStageIds,
      job: _jobController.text,
      ageMin: int.tryParse(_ageMinController.text),
      ageMax: int.tryParse(_ageMaxController.text),
      name: _nameController.text,
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
    _searchTimer?.cancel();
    _nameController.clear();
    _mobileController.clear();
    _jobController.clear();
    _personCountController.clear();
    _ageMinController.clear();
    _ageMaxController.clear();
    _nidAgeMinController.clear();
    _nidAgeMaxController.clear();
    setState(() {
      _selectedAreaIds = [];
      _selectedStreet = null;
      _selectedSocialIds = [];
      _selectedEconomicIds = [];
      _selectedStageIds = [];
      _selectedHealthIds = [];
      _selectedFather = null;
      _selectedMostwaIds = [];
      _selectedKarabaIds = [];
      _selectedMonths = [];
      _nidGovCode = null;
      _nidGender = null;
      _nidBirthDateMin = null;
      _nidBirthDateMax = null;
      _expenseResults.clear();
    });
    Provider.of<SearchProvider>(context, listen: false).clearResults();
  }

  void _printResults() async {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final lookup = Provider.of<LookupProvider>(context, listen: false);
    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);

    final results = searchProvider.results;
    if (results.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> familiesData = [];

      for (final family in results) {
        // 1. Get Area Name
        final area = lookup.areas.firstWhere(
          (a) => a.areaId == family.areaId,
          orElse: () => Area(areaId: 0, areaName: 'غير محدد'),
        );

        // 2. Get Street Name
        final street = lookup.streets.firstWhere(
          (s) => s.streetId == family.streetId,
          orElse: () => Street(streetId: 0, streetName: '', areaId: 0),
        );

        // 3. Format Address Detail
        final fullAddress =
            '${area.areaName} - ${street.streetName} - ${family.dalilName ?? ""}';

        if (_showMembers) {
          final members = await familyProvider.getPersons(family.osraId!);

          final membersDetails = members
              .map(
                (p) => [
                  p.personName,
                  lookup.getKarabaName(p.karabaId),
                  p.age ?? '---',
                  lookup.getStageName(p.stageId),
                  p.wazefa ?? '---',
                  p.mobile ?? '---',
                ],
              )
              .toList();

          // Fetch Financial Data
          final financialRepo = FinancialRepository();

          final fixedAids = await financialRepo.getFixedAidByFamily(
            family.osraId!,
          );
          final fixedAidsDetails = fixedAids.map((a) {
            final serviceName = lookup.getServiceName(a.khdmaId);
            return [
              serviceName,
              '${a.countValue} ج.م',
              a.aynee ?? '---',
              a.notes ?? '---',
            ];
          }).toList();

          final variableAids = await financialRepo.getVariableAidByFamily(
            family.osraId!,
          );
          final variableAidsDetails = variableAids
              .map(
                (a) => [
                  a.type ?? '---',
                  '${a.countAdd} ج.م',
                  a.date1?.split('T')[0] ?? '---',
                  a.notes ?? '---',
                ],
              )
              .toList();

          final expenses = await financialRepo.getExpensesByFamily(
            family.osraId!,
          );
          final expensesDetails = expenses
              .map(
                (e) => [
                  e.masrof ?? '---',
                  '${e.countValue} ج.م',
                  e.aynee ?? '---',
                  e.notes ?? '---',
                ],
              )
              .toList();

          familiesData.add({
            'family': family,
            'areaName': area.areaName,
            'address': fullAddress,
            'members': membersDetails,
            'fixedAids': fixedAidsDetails,
            'variableAids': variableAidsDetails,
            'expenses': expensesDetails,
          });
        } else {
          // Even if members are hidden, we might want financial summary here?
          // For now keep it as per original logic but ensure the key exists
          familiesData.add({
            'family': family,
            'areaName': area.areaName,
            'address': fullAddress,
            'members': <List<String>>[],
            'fixedAids': <List<String>>[],
            'variableAids': <List<String>>[],
            'expenses':
                (await FinancialRepository().getExpensesByFamily(
                      family.osraId!,
                    ))
                    .map(
                      (e) => [
                        e.masrof ?? '---',
                        '${e.countValue} ج.م',
                        e.aynee ?? '---',
                        e.notes ?? '---',
                      ],
                    )
                    .toList(),
          });
        }
      }

      final pdfService = PdfService();
      await pdfService.generateDetailedSearchReport(
        title: 'تقرير نتائج البحث التفصيلي',
        familiesData: familiesData,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context);
    final lookup = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_expensesOnly ? 'بحث المصروفات' : 'البحث المتقدم'),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text(
                'فلاتر البحث',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 760;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. قسم البحث بالاسم والتقرير
                          _buildFilterSection(
                            title: 'البحث بالاسم والتقرير',
                            icon: Icons.person_search_rounded,
                            children: [
                              TextField(
                                controller: _nameController,
                                onChanged: _scheduleSearch,
                                onSubmitted: (_) => _onSearch(),
                                decoration: InputDecoration(
                                  labelText: 'الاسم (أسرة أو فرد)',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _nameController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _nameController.clear();
                                            _onSearch();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                ),
                              ),
                              if (_nameController.text.trim().isNotEmpty &&
                                  searchProvider.results.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF334155)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(maxHeight: 180),
                                  child: ListView(
                                    shrinkWrap: true,
                                    primary: false,
                                    children: searchProvider.results
                                        .take(20)
                                        .map(
                                          (f) => ListTile(
                                            dense: true,
                                            leading: const Icon(Icons.family_restroom, size: 20),
                                            title: Text(f.osraName),
                                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                            onTap: () => Navigator.pushNamed(
                                              context,
                                              '/family-form',
                                              arguments: f,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              if (searchProvider.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    searchProvider.error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'إظهار أفراد الأسرة في التقرير',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                value: _showMembers,
                                onChanged: (val) => setState(() => _showMembers = val),
                              ),
                            ],
                          ),

                          // 2. الموقع والسكن
                          _buildFilterSection(
                            title: 'الموقع والسكن',
                            icon: Icons.location_on_outlined,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildModernField(
                                      label: 'المناطق',
                                      icon: Icons.map_outlined,
                                      child: _MultiSelectField<int>(
                                        label: 'المناطق',
                                        title: 'اختر المناطق',
                                        items: lookup.areas.map((a) => a.areaId!).toList(),
                                        selectedItems: _selectedAreaIds,
                                        itemLabel: (id) => lookup.areas
                                            .firstWhere((a) => a.areaId == id)
                                            .areaName,
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
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildModernField(
                                      label: 'الشارع',
                                      icon: Icons.add_road_outlined,
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          isExpanded: true,
                                          value: _selectedStreet,
                                          hint: const Text('كل الشوارع', style: TextStyle(fontSize: 13)),
                                          items: [
                                            const DropdownMenuItem<int>(
                                              value: null,
                                              child: Text('الكل'),
                                            ),
                                            ...lookup.streets.map<DropdownMenuItem<int>>(
                                              (s) => DropdownMenuItem<int>(
                                                value: s.streetId as int,
                                                child: Text(s.streetName),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) => setState(() => _selectedStreet = val),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // 3. الحالة الاجتماعية والتعليمية والكنسية
                          _buildFilterSection(
                            title: 'الحالة الاجتماعية والتعليمية والكنسية',
                            icon: Icons.volunteer_activism_outlined,
                            children: [
                              if (isDesktop) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'الحالة الاجتماعية',
                                        icon: Icons.favorite_border,
                                        child: _MultiSelectField<int>(
                                          label: 'الحالة الاجتماعية',
                                          title: 'اختر الحالة الاجتماعية',
                                          items: lookup.socialStatus
                                              .map<int>((s) => s['hala_egtimaia_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedSocialIds,
                                          itemLabel: (id) => lookup.socialStatus.firstWhere(
                                            (s) => s['hala_egtimaia_id'] == id,
                                          )['hala_name'] as String,
                                          onSaved: (result) => setState(() => _selectedSocialIds = result),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'الحالة الاقتصادية',
                                        icon: Icons.attach_money,
                                        child: _MultiSelectField<int>(
                                          label: 'الحالة الاقتصادية',
                                          title: 'اختر الحالة الاقتصادية',
                                          items: lookup.economicStatus
                                              .map<int>((e) => e['e_s_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedEconomicIds,
                                          itemLabel: (id) => lookup.economicStatus.firstWhere(
                                            (e) => e['e_s_id'] == id,
                                          )['e_s_name'] as String,
                                          onSaved: (result) => setState(() => _selectedEconomicIds = result),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'الحالة الصحية',
                                        icon: Icons.medical_services_outlined,
                                        child: _MultiSelectField<int>(
                                          label: 'الحالة الصحية',
                                          title: 'اختر الحالة الصحية',
                                          items: lookup.healthStatus
                                              .map<int>((h) => h['hala_sehia_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedHealthIds,
                                          itemLabel: (id) => lookup.healthStatus.firstWhere(
                                            (h) => h['hala_sehia_id'] == id,
                                          )['hala_name'] as String,
                                          onSaved: (result) => setState(() => _selectedHealthIds = result),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'صلة القرابة',
                                        icon: Icons.people_outline,
                                        child: _MultiSelectField<int>(
                                          label: 'صلة القرابة',
                                          title: 'اختر صلة القرابة',
                                          items: lookup.karaba
                                              .map<int>((k) => k['karaba_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedKarabaIds,
                                          itemLabel: (id) => lookup.karaba.firstWhere(
                                            (k) => k['karaba_id'] == id,
                                          )['karaba_name'] as String,
                                          onSaved: (result) => setState(() => _selectedKarabaIds = result),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'المرحلة المقيد بها',
                                        icon: Icons.class_outlined,
                                        child: _MultiSelectField<int>(
                                          label: 'المرحلة',
                                          title: 'اختر المرحلة',
                                          items: lookup.stages
                                              .map<int>((s) => s['stage_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedStageIds,
                                          itemLabel: (id) => lookup.stages.firstWhere(
                                            (s) => s['stage_id'] == id,
                                          )['stage_name'] as String,
                                          onSaved: (result) => setState(() => _selectedStageIds = result),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'المؤهل (التعليم)',
                                        icon: Icons.school_outlined,
                                        child: _MultiSelectField<int>(
                                          label: 'المؤهل (التعليم)',
                                          title: 'اختر المؤهل (التعليم)',
                                          items: lookup.educationLevels
                                              .map<int>((m) => m['mostwa_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedMostwaIds,
                                          itemLabel: (id) => lookup.educationLevels.firstWhere(
                                            (m) => m['mostwa_id'] == id,
                                          )['mostwa_name'] as String,
                                          onSaved: (result) => setState(() => _selectedMostwaIds = result),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'أب الاعتراف / الكاهن',
                                        icon: Icons.person_pin,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            isExpanded: true,
                                            value: _selectedFather,
                                            hint: const Text('الكل', style: TextStyle(fontSize: 13)),
                                            items: [
                                              const DropdownMenuItem<int>(
                                                value: null,
                                                child: Text('الكل'),
                                              ),
                                              ...lookup.fathers.map<DropdownMenuItem<int>>(
                                                (f) => DropdownMenuItem<int>(
                                                  value: f.fatherId as int,
                                                  child: Text(f.fatherName),
                                                ),
                                              ),
                                            ],
                                            onChanged: (val) => setState(() => _selectedFather = val),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                // Mobile: 2-column pairs
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'الحالة الاجتماعية',
                                        icon: Icons.favorite_border,
                                        child: _MultiSelectField<int>(
                                          label: 'الاجتماعية',
                                          title: 'اختر الحالة الاجتماعية',
                                          items: lookup.socialStatus
                                              .map<int>((s) => s['hala_egtimaia_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedSocialIds,
                                          itemLabel: (id) => lookup.socialStatus.firstWhere(
                                            (s) => s['hala_egtimaia_id'] == id,
                                          )['hala_name'] as String,
                                          onSaved: (result) => setState(() => _selectedSocialIds = result),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'الحالة الاقتصادية',
                                        icon: Icons.attach_money,
                                        child: _MultiSelectField<int>(
                                          label: 'الاقتصادية',
                                          title: 'اختر الحالة الاقتصادية',
                                          items: lookup.economicStatus
                                              .map<int>((e) => e['e_s_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedEconomicIds,
                                          itemLabel: (id) => lookup.economicStatus.firstWhere(
                                            (e) => e['e_s_id'] == id,
                                          )['e_s_name'] as String,
                                          onSaved: (result) => setState(() => _selectedEconomicIds = result),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'الحالة الصحية',
                                        icon: Icons.medical_services_outlined,
                                        child: _MultiSelectField<int>(
                                          label: 'الصحية',
                                          title: 'اختر الحالة الصحية',
                                          items: lookup.healthStatus
                                              .map<int>((h) => h['hala_sehia_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedHealthIds,
                                          itemLabel: (id) => lookup.healthStatus.firstWhere(
                                            (h) => h['hala_sehia_id'] == id,
                                          )['hala_name'] as String,
                                          onSaved: (result) => setState(() => _selectedHealthIds = result),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'صلة القرابة',
                                        icon: Icons.people_outline,
                                        child: _MultiSelectField<int>(
                                          label: 'القرابة',
                                          title: 'اختر صلة القرابة',
                                          items: lookup.karaba
                                              .map<int>((k) => k['karaba_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedKarabaIds,
                                          itemLabel: (id) => lookup.karaba.firstWhere(
                                            (k) => k['karaba_id'] == id,
                                          )['karaba_name'] as String,
                                          onSaved: (result) => setState(() => _selectedKarabaIds = result),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'المرحلة',
                                        icon: Icons.class_outlined,
                                        child: _MultiSelectField<int>(
                                          label: 'المرحلة',
                                          title: 'اختر المرحلة',
                                          items: lookup.stages
                                              .map<int>((s) => s['stage_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedStageIds,
                                          itemLabel: (id) => lookup.stages.firstWhere(
                                            (s) => s['stage_id'] == id,
                                          )['stage_name'] as String,
                                          onSaved: (result) => setState(() => _selectedStageIds = result),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'المؤهل (التعليم)',
                                        icon: Icons.school_outlined,
                                        child: _MultiSelectField<int>(
                                          label: 'المؤهل',
                                          title: 'اختر المؤهل (التعليم)',
                                          items: lookup.educationLevels
                                              .map<int>((m) => m['mostwa_id'] as int)
                                              .toList(),
                                          selectedItems: _selectedMostwaIds,
                                          itemLabel: (id) => lookup.educationLevels.firstWhere(
                                            (m) => m['mostwa_id'] == id,
                                          )['mostwa_name'] as String,
                                          onSaved: (result) => setState(() => _selectedMostwaIds = result),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildModernField(
                                  label: 'أب الاعتراف / الكاهن',
                                  icon: Icons.person_pin,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      isExpanded: true,
                                      value: _selectedFather,
                                      hint: const Text('الكل', style: TextStyle(fontSize: 13)),
                                      items: [
                                        const DropdownMenuItem<int>(
                                          value: null,
                                          child: Text('الكل'),
                                        ),
                                        ...lookup.fathers.map<DropdownMenuItem<int>>(
                                          (f) => DropdownMenuItem<int>(
                                            value: f.fatherId as int,
                                            child: Text(f.fatherName),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) => setState(() => _selectedFather = val),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // 4. بيانات الاتصال والعمل والسن
                          _buildFilterSection(
                            title: 'بيانات الاتصال والعمل والأعمار',
                            icon: Icons.contact_phone_outlined,
                            children: [
                              if (isDesktop) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'رقم الموبايل',
                                        icon: Icons.phone_android,
                                        child: TextField(
                                          controller: _mobileController,
                                          keyboardType: TextInputType.phone,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'رقم الهاتف',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'الوظيفة',
                                        icon: Icons.work_outline,
                                        child: TextField(
                                          controller: _jobController,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'المهنة أو الوظيفة',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'عدد الأفراد',
                                        icon: Icons.group_outlined,
                                        child: TextField(
                                          controller: _personCountController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'العدد',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'شهر الميلاد',
                                        icon: Icons.event,
                                        child: _MultiSelectField<String>(
                                          label: 'شهر الميلاد',
                                          title: 'اختر شهر الميلاد',
                                          items: List.generate(12, (i) => (i + 1).toString()),
                                          selectedItems: _selectedMonths,
                                          itemLabel: (m) => 'شهر $m',
                                          onSaved: (result) => setState(() => _selectedMonths = result),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'السن من',
                                        icon: Icons.cake_outlined,
                                        child: TextField(
                                          controller: _ageMinController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'الحد الأدنى للسن',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'السن إلى',
                                        icon: Icons.cake_outlined,
                                        child: TextField(
                                          controller: _ageMaxController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'الحد الأقصى للسن',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                // Mobile
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'رقم الموبايل',
                                        icon: Icons.phone_android,
                                        child: TextField(
                                          controller: _mobileController,
                                          keyboardType: TextInputType.phone,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'المحمول',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'الوظيفة',
                                        icon: Icons.work_outline,
                                        child: TextField(
                                          controller: _jobController,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'الوظيفة',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'عدد الأفراد',
                                        icon: Icons.group_outlined,
                                        child: TextField(
                                          controller: _personCountController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'العدد',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'شهر الميلاد',
                                        icon: Icons.event,
                                        child: _MultiSelectField<String>(
                                          label: 'شهر الميلاد',
                                          title: 'اختر شهر الميلاد',
                                          items: List.generate(12, (i) => (i + 1).toString()),
                                          selectedItems: _selectedMonths,
                                          itemLabel: (m) => 'شهر $m',
                                          onSaved: (result) => setState(() => _selectedMonths = result),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'السن من',
                                        icon: Icons.cake_outlined,
                                        child: TextField(
                                          controller: _ageMinController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'الحد الأدنى',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildModernField(
                                        label: 'السن إلى',
                                        icon: Icons.cake_outlined,
                                        child: TextField(
                                          controller: _ageMaxController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(bottom: 8),
                                            hintText: 'الحد الأقصى',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),

                          // 5. قسم الناتج من الرقم القومي (6 حقول متوازنة تماماً - لا حقول يتيمة!)
                          _buildNationalIdSection(isDesktop),

                          const SizedBox(height: 20),

                          // 6. أزرار الإجراءات
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _onSearch,
                                  icon: const Icon(Icons.search, size: 20),
                                  label: const Text(
                                    'بدء البحث',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _clearFilters,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('مسح الفلاتر', style: TextStyle(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: (searchProvider.results.isEmpty || _isLoading)
                                      ? null
                                      : _printResults,
                                  icon: const Icon(Icons.print, size: 20),
                                  label: const Text(
                                    'طباعة النتائج',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (searchProvider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (searchProvider.results.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'لا توجد نتائج بحث لعرضها',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final family = searchProvider.results[index];
                final socialName = lookup.getHalaEgtimaiaName(
                  family.halaEgtimaiaId,
                );
                final economicName = lookup.getEconomicStatusName(family.eSId);
                final karaba = lookup.getKarabaName(family.karabaId);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 3,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/family-form',
                      arguments: family,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: isDark ? Colors.blue.shade900.withValues(alpha: 0.5) : Colors.blue.shade50,
                                child: Icon(
                                  Icons.family_restroom,
                                  color: isDark ? const Color(0xFF60A5FA) : Colors.blue.shade700,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      family.osraName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: isDark ? const Color(0xFFF8FAFC) : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '# كود: ${family.code ?? '---'}',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFamilyChip(
                                label: 'الأفراد: ${family.memberCount}',
                                icon: Icons.people_outline,
                                color: Colors.blue,
                              ),
                              if (karaba != '---')
                                _buildFamilyChip(
                                  label: karaba,
                                  icon: Icons.person_outline,
                                  color: Colors.teal,
                                ),
                              if (socialName != '---')
                                _buildFamilyChip(
                                  label: socialName,
                                  icon: Icons.favorite_border,
                                  color: Colors.purple,
                                ),
                              if (economicName != '---')
                                _buildFamilyChip(
                                  label: economicName,
                                  icon: Icons.account_balance_wallet_outlined,
                                  color: Colors.orange,
                                ),
                            ],
                          ),
                          if (_expensesOnly)
                            FutureBuilder<List<Expense>>(
                              future: _expenseResults.putIfAbsent(
                                family.osraId!,
                                () => FinancialRepository().getExpensesByFamily(
                                  family.osraId!,
                                ),
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return const Text('تعذر تحميل المصروفات');
                                }
                                if (!snapshot.hasData) {
                                  return const LinearProgressIndicator();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: snapshot.data!
                                      .map(
                                        (e) => ListTile(
                                          title: Text(
                                            '${e.masrof ?? 'مصروف'}: ${e.countValue} ج.م',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : Colors.black87),
                                          ),
                                          subtitle: Text(
                                            [e.aynee, e.notes]
                                                .whereType<String>()
                                                .where((s) => s.isNotEmpty)
                                                .join(' — '),
                                                style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black54),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                          if (family.rakmKomy != null &&
                              family.rakmKomy!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  family.rakmKomy!,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600,
                                    fontSize: 13,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.badge_outlined,
                                  size: 16,
                                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: searchProvider.results.length),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildFamilyChip({
    required String label,
    required IconData icon,
    required MaterialColor color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.25) : color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? color.shade400 : color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? color.shade300 : color.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : color.shade900,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildNationalIdSection(bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : null,
        gradient: isDark
            ? null
            : LinearGradient(
                colors: [Colors.teal.shade50, Colors.cyan.shade50],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF0D9488) : Colors.teal.shade200,
        ),
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
                  color: isDark
                      ? const Color(0xFF0F766E).withValues(alpha: 0.3)
                      : Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.badge,
                  color: isDark ? const Color(0xFF5EEAD4) : Colors.teal.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'الناتج من الرقم القومي (فلاتر دقيقة)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? const Color(0xFFF0FDFA) : Colors.teal.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 balanced pairs: Pair 1: Gov & Gender, Pair 2: Age Min & Max, Pair 3: Date Min & Max
          Row(
            children: [
              Expanded(
                child: _buildModernField(
                  label: 'المحافظة (من الرقم القومي)',
                  icon: Icons.location_city,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _nidGovCode,
                      hint: const Text('الكل', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ..._governorates.entries.map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _nidGovCode = val),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernField(
                  label: 'النوع (من الرقم القومي)',
                  icon: Icons.wc,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _nidGender,
                      hint: const Text('الكل', style: TextStyle(fontSize: 13)),
                      items: const [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'ذكر',
                          child: Text('ذكر'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'أنثى',
                          child: Text('أنثى'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _nidGender = val),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildModernField(
                  label: 'السن من (الرقم القومي)',
                  icon: Icons.cake,
                  child: TextField(
                    controller: _nidAgeMinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(bottom: 8),
                      hintText: 'الحد الأدنى',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernField(
                  label: 'السن إلى (الرقم القومي)',
                  icon: Icons.cake,
                  child: TextField(
                    controller: _nidAgeMaxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(bottom: 8),
                      hintText: 'الحد الأقصى',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildModernField(
                  label: 'تاريخ الميلاد من',
                  icon: Icons.calendar_month,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _nidBirthDateMin == null
                              ? 'اختر التاريخ'
                              : _nidBirthDateMin!.toIso8601String().split('T')[0],
                          style: TextStyle(
                            fontSize: 13,
                            color: _nidBirthDateMin == null ? Colors.grey : null,
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernField(
                  label: 'تاريخ الميلاد إلى',
                  icon: Icons.calendar_month,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _nidBirthDateMax == null
                              ? 'اختر التاريخ'
                              : _nidBirthDateMax!.toIso8601String().split('T')[0],
                          style: TextStyle(
                            fontSize: 13,
                            color: _nidBirthDateMax == null ? Colors.grey : null,
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernField({
    required String label,
    required Widget child,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final labelColor = isDark ? const Color(0xFF94A3B8) : Colors.blueGrey.shade700;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: primaryColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 38,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MultiSelectField<T> extends StatelessWidget {
  final String label;
  final String title;
  final List<T> items;
  final List<T> selectedItems;
  final String Function(T) itemLabel;
  final void Function(List<T>) onSaved;

  const _MultiSelectField({
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
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: 320,
                  height: 400,
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('تحديد الكل'),
                        value:
                            tempSelected.length == items.length &&
                            items.isNotEmpty,
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
                  ElevatedButton(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              selectedItems.isEmpty
                  ? 'الكل (غير محدد)'
                  : selectedItems.length == items.length
                  ? 'تحديد الكل (${items.length})'
                  : selectedItems.map(itemLabel).join('، '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selectedItems.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                color: selectedItems.isNotEmpty
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}
