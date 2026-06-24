import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/search_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/models/lookup_models.dart';
import '../../../data/repositories/financial_repository.dart';
import '../../../data/services/pdf_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  bool _isLoading = false;
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
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  void _onSearch() {
    Provider.of<SearchProvider>(context, listen: false).performSearch(
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
          orElse: () => Area(areaId: 0, areaName: 'غير محدد')
        );
        
        // 2. Get Street Name
        final street = lookup.streets.firstWhere(
          (s) => s.streetId == family.streetId,
          orElse: () => Street(streetId: 0, streetName: '', areaId: 0)
        );
        
        // 3. Format Address Detail
        final fullAddress = '${area.areaName} - ${street.streetName} - ${family.dalilName ?? ""}';
        
        if (_showMembers) {
          final members = await familyProvider.getPersons(family.osraId!);
          
          final membersDetails = members.map((p) => [
            p.personName,
            lookup.getKarabaName(p.karabaId),
            p.age ?? '---',
            lookup.getStageName(p.stageId),
            p.wazefa ?? '---',
            p.mobile ?? '---',
          ]).toList();
          
          // Fetch Financial Data
          final financialRepo = FinancialRepository();
          
          final fixedAids = await financialRepo.getFixedAidByFamily(family.osraId!);
          final fixedAidsDetails = fixedAids.map((a) {
            final serviceName = lookup.services.firstWhere(
              (s) => s['khdma_id'] == a.khdmaId, 
              orElse: () => {'khdma_name': '---'}
            )['khdma_name'];
            return [
              serviceName as String,
              '${a.countValue} ج.م',
              a.aynee ?? '---',
              a.notes ?? '---',
            ];
          }).toList();

          final variableAids = await financialRepo.getVariableAidByFamily(family.osraId!);
          final variableAidsDetails = variableAids.map((a) => [
            a.type ?? '---',
            '${a.countAdd} ج.م',
            a.date1?.split('T')[0] ?? '---',
            a.notes ?? '---',
          ]).toList();

          final expenses = await financialRepo.getExpensesByFamily(family.osraId!);
          final expensesDetails = expenses.map((e) => [
            e.masrof ?? '---',
            '${e.countValue} ج.م',
            e.aynee ?? '---',
            e.notes ?? '---',
          ]).toList();
          
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
            'expenses': <List<String>>[],
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
        title: const Text('البحث المتقدم'),
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
              title: const Text('فلاتر البحث', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم (أسرة أو فرد)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('إظهار أفراد الأسرة في التقرير'),
                        value: _showMembers,
                        onChanged: (val) => setState(() => _showMembers = val),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: [
                          _buildModernField(
                            label: 'المناطق',
                            child: _MultiSelectField<int>(
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
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.streets.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s.streetId as int, child: Text(s.streetName))).toList(),
                              onChanged: (val) => setState(() => _selectedStreet = val),
                            ),
                          ),
                          _buildModernField(
                            label: 'شهر الميلاد',
                            child: _MultiSelectField<String>(
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
                            child: TextField(controller: _mobileController, decoration: const InputDecoration(border: OutlineInputBorder())),
                          ),
                          _buildModernField(
                            label: 'الوظيفة',
                            child: TextField(controller: _jobController, decoration: const InputDecoration(border: OutlineInputBorder())),
                          ),
                          _buildModernField(
                            label: 'عدد الأفراد',
                            child: TextField(controller: _personCountController, decoration: const InputDecoration(border: OutlineInputBorder()), keyboardType: TextInputType.number),
                          ),
                          _buildModernField(
                            label: 'السن من',
                            child: TextField(controller: _ageMinController, decoration: const InputDecoration(border: OutlineInputBorder()), keyboardType: TextInputType.number),
                          ),
                          _buildModernField(
                            label: 'السن إلى',
                            child: TextField(controller: _ageMaxController, decoration: const InputDecoration(border: OutlineInputBorder()), keyboardType: TextInputType.number),
                          ),
                          _buildModernField(
                            label: 'الحالة الاجتماعية',
                            child: _MultiSelectField<int>(
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
                            child: _MultiSelectField<int>(
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
                            child: _MultiSelectField<int>(
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
                            child: _MultiSelectField<int>(
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
                            child: _MultiSelectField<int>(
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
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.fathers.map<DropdownMenuItem<int>>((f) => DropdownMenuItem<int>(value: f.fatherId as int, child: Text(f.fatherName))).toList(),
                              onChanged: (val) => setState(() => _selectedFather = val),
                            ),
                          ),
                          _buildModernField(
                            label: 'صلة القرابة',
                            child: _MultiSelectField<int>(
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
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
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
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
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
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                _buildModernField(
                                  label: 'السن إلى (الرقم القومي)',
                                  child: TextField(
                                    controller: _nidAgeMaxController,
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
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
                                      height: 56,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
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
                                      height: 56,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
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
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _onSearch, 
                              icon: const Icon(Icons.search), 
                              label: const Text('بدء البحث'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (searchProvider.results.isEmpty || _isLoading) ? null : _printResults, 
                              icon: const Icon(Icons.print), 
                              label: const Text('طباعة النتائج'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  child: Text('لا توجد نتائج بحث لعرضها', style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final family = searchProvider.results[index];
                  final socialName = lookup.getHalaEgtimaiaName(family.halaEgtimaiaId);
                  final economicName = lookup.getEconomicStatusName(family.eSId);
                  final karaba = lookup.getKarabaName(family.karabaId);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pushNamed(context, '/family-form', arguments: family),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.blue.shade50,
                                  child: Icon(Icons.family_restroom, color: Colors.blue.shade700, size: 30),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        family.osraName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '# كود: ${family.code ?? '---'}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
                            if (family.rakmKomy != null && family.rakmKomy!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    family.rakmKomy!,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.badge_outlined, size: 16, color: Colors.grey.shade400),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: searchProvider.results.length,
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildFamilyChip({required String label, required IconData icon, required MaterialColor color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.shade900,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernField({required String label, required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 600 ? 250.0 : (constraints.maxWidth - 24) / 2;
        return SizedBox(
          width: width.clamp(150.0, 400.0),
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
          borderRadius: BorderRadius.circular(4),
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
