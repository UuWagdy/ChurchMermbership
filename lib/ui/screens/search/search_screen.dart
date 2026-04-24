import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/search_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/models/family_models.dart';
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

  int? _selectedArea;
  int? _selectedStreet;
  int? _selectedSocial;
  int? _selectedEconomic;
  int? _selectedStage;
  int? _selectedHealth;
  int? _selectedFather;
  int? _selectedMostwa;
  int? _selectedKaraba;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  void _onSearch() {
    Provider.of<SearchProvider>(context, listen: false).performSearch(
      areaId: _selectedArea,
      streetId: _selectedStreet,
      mobile: _mobileController.text,
      birthMonth: _selectedMonth,
      personCount: int.tryParse(_personCountController.text),
      socialStatusId: _selectedSocial,
      economicStatusId: _selectedEconomic,
      stageId: _selectedStage,
      job: _jobController.text,
      ageMin: int.tryParse(_ageMinController.text),
      ageMax: int.tryParse(_ageMaxController.text),
      name: _nameController.text,
      healthStatusId: _selectedHealth,
      fatherId: _selectedFather,
      mostwaId: _selectedMostwa,
      karabaId: _selectedKaraba,
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
      appBar: AppBar(title: const Text('البحث المتقدم')),
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
                            label: 'المنطقة',
                            child: DropdownButtonFormField<int>(
                              value: _selectedArea,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.areas.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(value: a.areaId as int, child: Text(a.areaName))).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedArea = val;
                                  _selectedStreet = null;
                                });
                                if (val != null) lookup.loadStreets(val);
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
                            child: DropdownButtonFormField<String>(
                              value: _selectedMonth,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: List.generate(12, (i) => (i + 1).toString()).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (val) => setState(() => _selectedMonth = val),
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
                            child: DropdownButtonFormField<int>(
                              value: _selectedSocial,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.socialStatus.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['hala_egtimaia_id'] as int, child: Text(s['hala_name'] as String))).toList(),
                              onChanged: (val) => setState(() => _selectedSocial = val),
                            ),
                          ),
                          _buildModernField(
                            label: 'الحالة الاقتصادية',
                            child: DropdownButtonFormField<int>(
                              value: _selectedEconomic,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.economicStatus.map<DropdownMenuItem<int>>((e) => DropdownMenuItem<int>(value: e['e_s_id'] as int, child: Text(e['e_s_name'] as String))).toList(),
                              onChanged: (val) => setState(() => _selectedEconomic = val),
                            ),
                          ),
                          _buildModernField(
                            label: 'الحالة الصحية',
                            child: DropdownButtonFormField<int>(
                              value: _selectedHealth,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.healthStatus.map<DropdownMenuItem<int>>((h) => DropdownMenuItem<int>(value: h['hala_sehia_id'] as int, child: Text(h['hala_name'] as String))).toList(),
                              onChanged: (val) => setState(() => _selectedHealth = val),
                            ),
                          ),
                          _buildModernField(
                            label: 'المرحلة',
                            child: DropdownButtonFormField<int>(
                              value: _selectedStage,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.stages.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['stage_id'] as int, child: Text(s['stage_name'] as String))).toList(),
                              onChanged: (val) => setState(() => _selectedStage = val),
                            ),
                          ),
                          _buildModernField(
                            label: 'المؤهل (التعليم)',
                            child: DropdownButtonFormField<int>(
                              value: _selectedMostwa,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.educationLevels.map<DropdownMenuItem<int>>((m) => DropdownMenuItem<int>(value: m['mostwa_id'] as int, child: Text(m['mostwa_name'] as String))).toList(),
                              onChanged: (val) => setState(() => _selectedMostwa = val),
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
                            child: DropdownButtonFormField<int>(
                              value: _selectedKaraba,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: lookup.karaba.map<DropdownMenuItem<int>>((k) => DropdownMenuItem<int>(value: k['karaba_id'] as int, child: Text(k['karaba_name'] as String))).toList(),
                              onChanged: (val) => setState(() => _selectedKaraba = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _onSearch, 
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
                              onPressed: searchProvider.results.isEmpty ? null : _printResults, 
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
                                  label: 'الأفراد: ${family.memberCount ?? 0}',
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
