import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../providers/financial_provider.dart';
import '../../../data/models/family_models.dart';
import '../../../data/services/pdf_service.dart';

class FamilyFormScreen extends StatefulWidget {
  const FamilyFormScreen({super.key});

  @override
  State<FamilyFormScreen> createState() => _FamilyFormScreenState();
}

class _FamilyFormScreenState extends State<FamilyFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  Family? _existingFamily;

  // Controllers
  final _nameController = TextEditingController();
  final _dalilController = TextEditingController();
  final _emaraController = TextEditingController();
  final _doorController = TextEditingController();
  final _shakaController = TextEditingController();
  final _roController = TextEditingController();
  final _phoneController = TextEditingController();
  final _rakmKomyController = TextEditingController();
  final _codeController = TextEditingController();

  int? _selectedArea;
  int? _selectedStreet;
  int? _selectedKaraba;
  int? _selectedES;
  int? _selectedHala;
  int? _selectedHalaSehia;
  int? _selectedMostwa;

  List<Person> _persons = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lookup = Provider.of<LookupProvider>(context, listen: false);
      await lookup.loadAllLookups();

      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Family) {
        setState(() {
          _existingFamily = args;
          _nameController.text = args.osraName;
          _dalilController.text = args.dalilName ?? '';
          _emaraController.text = args.emara ?? '';
          _doorController.text = args.door ?? '';
          _shakaController.text = args.shaka ?? '';
          _roController.text = args.rO ?? '';
          _phoneController.text = args.phone ?? '';
          _rakmKomyController.text = args.rakmKomy ?? '';
          _codeController.text = args.code?.toString() ?? '';
          _selectedArea = args.areaId;
          _selectedKaraba = args.karabaId;
          _selectedES = args.eSId;
          _selectedHala = args.halaEgtimaiaId;
          _selectedHalaSehia = args.halaSehiaId;
          _selectedMostwa = args.mostwaId;
        });

        if (args.areaId != null) {
          await lookup.loadStreets(args.areaId!);
          setState(() => _selectedStreet = args.streetId);
        }

        _loadPersons();
      }
    });
  }

  Future<void> _loadPersons() async {
    if (_existingFamily?.osraId != null) {
      final persons = await Provider.of<FamilyProvider>(context, listen: false)
          .getPersons(_existingFamily!.osraId!);
      setState(() => _persons = persons);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final family = Family(
      osraId: _existingFamily?.osraId,
      osraName: _nameController.text,
      karabaId: _selectedKaraba,
      eSId: _selectedES,
      areaId: _selectedArea,
      streetId: _selectedStreet,
      dalilName: _dalilController.text,
      emara: _nameController.text, // Mapping C# logic where Emara sometimes used Osra Name
      door: _doorController.text,
      shaka: _shakaController.text,
      rO: _roController.text,
      phone: _phoneController.text,
      halaEgtimaiaId: _selectedHala,
      halaSehiaId: _selectedHalaSehia,
      mostwaId: _selectedMostwa,
      rakmKomy: _rakmKomyController.text,
      code: int.tryParse(_codeController.text),
    );

    await Provider.of<FamilyProvider>(context, listen: false).saveFamily(family);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _printReport() async {
    if (_existingFamily == null) return;
    final financial = Provider.of<FinancialProvider>(context, listen: false);
    await financial.loadFinancials(_existingFamily!.osraId!);
    
    final pdfService = PdfService();
    await pdfService.generateFamilyReport(
      _existingFamily!,
      _persons,
      financial.calculateTotalAids(),
      financial.calculateTotalExpenses(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_existingFamily == null ? 'إضافة أسرة جديدة' : 'تعديل أسرة'),
        actions: [
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف الأسرة'),
                    content: Text('هل أنت متأكد من حذف أسرة ${_existingFamily!.osraName} وكل البيانات المتعلقة بها؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Provider.of<FamilyProvider>(context, listen: false).deleteFamily(_existingFamily!.osraId!);
                          if (!mounted) return;
                          Navigator.pop(ctx); // Close dialog
                          Navigator.pop(context); // Go back to list
                        },
                        child: const Text('حذف', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'حذف الأسرة',
            ),
          if (_existingFamily != null)
            IconButton(
              onPressed: _printReport,
              icon: const Icon(Icons.print),
              tooltip: 'طباعة التقرير الشامل',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'بيانات الأسرة'),
            Tab(icon: Icon(Icons.people), text: 'أفراد الأسرة'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildFamilyDetails(lookup),
            _buildPersonsList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        label: const Text('حفظ'),
        icon: const Icon(Icons.save),
      ),
    );
  }

  Widget _buildPremiumField({
    required Widget child,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 40,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyDetails(LookupProvider lookup) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPremiumField(
            label: 'اسم الأسرة (رب الأسرة)',
            icon: Icons.family_restroom,
            child: TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8)),
              validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16.0,
            runSpacing: 16.0,
            children: [
              SizedBox(
                width: 300,
                child: _buildPremiumField(
                  label: 'المنطقة',
                  icon: Icons.map,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedArea,
                      items: lookup.areas.map((a) => DropdownMenuItem(value: a.areaId, child: Text(a.areaName))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedArea = val;
                          _selectedStreet = null;
                        });
                        if (val != null) lookup.loadStreets(val);
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 300,
                child: _buildPremiumField(
                  label: 'الشارع',
                  icon: Icons.add_road,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedStreet,
                      items: lookup.streets.map((s) => DropdownMenuItem(value: s.streetId, child: Text(s.streetName))).toList(),
                      onChanged: (val) => setState(() => _selectedStreet = val),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16.0,
            runSpacing: 16.0,
            children: [
              SizedBox(
                width: 250,
                child: _buildPremiumField(
                  label: 'القرابة',
                  icon: Icons.people_outline,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedKaraba,
                      items: lookup.karaba.map<DropdownMenuItem<int>>((k) => DropdownMenuItem<int>(value: k['karaba_id'] as int, child: Text(k['karaba_name'] as String))).toList(),
                      onChanged: (val) => setState(() => _selectedKaraba = val),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: _buildPremiumField(
                  label: 'الحالة الاقتصادية',
                  icon: Icons.attach_money,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedES,
                      items: lookup.economicStatus.map<DropdownMenuItem<int>>((e) => DropdownMenuItem<int>(value: e['e_s_id'] as int, child: Text(e['e_s_name'] as String))).toList(),
                      onChanged: (val) => setState(() => _selectedES = val),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: _buildPremiumField(
                  label: 'الحالة الاجتماعية',
                  icon: Icons.favorite_border,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedHala,
                      items: lookup.socialStatus.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['hala_egtimaia_id'] as int, child: Text(s['hala_name'] as String))).toList(),
                      onChanged: (val) => setState(() => _selectedHala = val),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: _buildPremiumField(
                  label: 'الحالة الصحية',
                  icon: Icons.medical_services_outlined,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedHalaSehia,
                      items: lookup.healthStatus.map<DropdownMenuItem<int>>((h) => DropdownMenuItem<int>(value: h['hala_sehia_id'] as int, child: Text(h['hala_name'] as String))).toList(),
                      onChanged: (val) => setState(() => _selectedHalaSehia = val),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: _buildPremiumField(
                  label: 'المستوى التعليمي',
                  icon: Icons.school_outlined,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedMostwa,
                      items: lookup.educationLevels.map<DropdownMenuItem<int>>((m) => DropdownMenuItem<int>(value: m['mostwa_id'] as int, child: Text(m['mostwa_name'] as String))).toList(),
                      onChanged: (val) => setState(() => _selectedMostwa = val),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16.0,
            runSpacing: 16.0,
            children: [
              SizedBox(
                width: 250,
                child: _buildPremiumField(
                  label: 'رقم التليفون',
                  icon: Icons.phone_android,
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8)),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: _buildPremiumField(
                  label: 'الرقم القومي',
                  icon: Icons.badge_outlined,
                  child: TextFormField(
                    controller: _rakmKomyController,
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8)),
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: _buildPremiumField(
                  label: 'رقم التليفون (أرضي)',
                  icon: Icons.call,
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16.0,
            runSpacing: 16.0,
            children: [
              SizedBox(
                width: 200, 
                child: _buildPremiumField(
                  label: 'الكود',
                  icon: Icons.qr_code,
                  child: TextFormField(
                    controller: _codeController, 
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8))
                  )
                )
              ),
              SizedBox(
                width: 200, 
                child: _buildPremiumField(
                  label: 'الدور',
                  icon: Icons.apartment,
                  child: TextFormField(
                    controller: _roController, 
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8))
                  )
                )
              ),
              SizedBox(
                width: 400,
                child: _buildPremiumField(
                  label: 'دليل / علامة مميزة',
                  icon: Icons.location_on_outlined,
                  child: TextFormField(
                    controller: _dalilController,
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildPersonsList() {
    if (_existingFamily == null) {
      return const Center(child: Text('من فضلك احفظ الأسرة أولاً لإضافة أفراد'));
    }

    final lookup = Provider.of<LookupProvider>(context, listen: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showPersonDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة فرد جديد', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _persons.length,
            itemBuilder: (context, index) {
              final person = _persons[index];
              final karaba = lookup.getKarabaName(person.karabaId);
              final stage = lookup.getStageName(person.stageId);
              final healthName = lookup.getHalaSehiaName(person.halaSehiaId);
              final socialName = lookup.getHalaEgtimaiaName(person.halaEgtimaiaId);
              final educationName = lookup.getEducationLevelName(person.mostwaId);

              return Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.blue.withOpacity(0.1),
                                  child: const Icon(Icons.person, color: Colors.blue, size: 30),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.personName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 4),
                                      if (person.mobile != null && person.mobile!.isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(Icons.phone, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(person.mobile!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showPersonDialog(person),
                                tooltip: 'تعديل الفرد',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  await Provider.of<FamilyProvider>(context, listen: false).deletePerson(person.personId!);
                                  _loadPersons();
                                },
                                tooltip: 'حذف الفرد',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(thickness: 1, color: Colors.black12),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (karaba != '---') 
                            Chip(
                              avatar: const Icon(Icons.family_restroom, size: 16, color: Colors.teal),
                              label: Text(karaba), 
                              backgroundColor: Colors.teal.shade50, 
                              labelStyle: TextStyle(color: Colors.teal.shade800, fontSize: 13)
                            ),
                          if (person.age != null) 
                            Chip(
                              avatar: const Icon(Icons.cake, size: 16, color: Colors.orange),
                              label: Text('${person.age} سنة'), 
                              backgroundColor: Colors.orange.shade50, 
                              labelStyle: TextStyle(color: Colors.orange.shade800, fontSize: 13)
                            ),
                          if (socialName != '---')
                            Chip(
                              avatar: const Icon(Icons.favorite, size: 16, color: Colors.pink),
                              label: Text(socialName), 
                              backgroundColor: Colors.pink.shade50, 
                              labelStyle: TextStyle(color: Colors.pink.shade800, fontSize: 13)
                            ),
                          if (healthName != '---')
                            Chip(
                              avatar: const Icon(Icons.medical_services, size: 16, color: Colors.indigo),
                              label: Text(healthName), 
                              backgroundColor: Colors.indigo.shade50, 
                              labelStyle: TextStyle(color: Colors.indigo.shade800, fontSize: 13)
                            ),
                          if (educationName != '---')
                            Chip(
                              avatar: const Icon(Icons.school, size: 16, color: Colors.purple),
                              label: Text(educationName), 
                              backgroundColor: Colors.purple.shade50, 
                              labelStyle: TextStyle(color: Colors.purple.shade800, fontSize: 13)
                            ),
                          if (stage != '---') 
                            Chip(
                              avatar: const Icon(Icons.class_, size: 16, color: Colors.blue),
                              label: Text(stage), 
                              backgroundColor: Colors.blue.shade50, 
                              labelStyle: TextStyle(color: Colors.blue.shade800, fontSize: 13)
                            ),
                          if (person.wazefa != null && person.wazefa!.isNotEmpty)
                            Chip(
                              avatar: const Icon(Icons.work, size: 16, color: Colors.brown),
                              label: Text(person.wazefa!), 
                              backgroundColor: Colors.brown.shade50, 
                              labelStyle: TextStyle(color: Colors.brown.shade800, fontSize: 13)
                            ),
                        ],
                      ),
                      if (person.rakmKomy != null && person.rakmKomy!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              person.rakmKomy!,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w500,
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
              );
            },
          ),
        ),
      ],
    );
  }

  void _showPersonDialog([Person? person]) {
    showDialog(
      context: context,
      builder: (context) => PersonFormDialog(
        osraId: _existingFamily!.osraId!,
        existingPerson: person,
        onSave: _loadPersons,
      ),
    );
  }
}

class PersonFormDialog extends StatefulWidget {
  final int osraId;
  final Person? existingPerson;
  final Function onSave;

  const PersonFormDialog({super.key, required this.osraId, this.existingPerson, required this.onSave});

  @override
  State<PersonFormDialog> createState() => _PersonFormDialogState();
}

class _PersonFormDialogState extends State<PersonFormDialog> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _jobController = TextEditingController();
  final _rakmKomyController = TextEditingController();
  DateTime? _birthDate;
  int? _selectedKaraba;
  int? _selectedMostwa;
  int? _selectedHala;
  int? _selectedHealth;
  int? _selectedStage;
  int? _selectedFather;

  @override
  void initState() {
    super.initState();
    if (widget.existingPerson != null) {
      final p = widget.existingPerson!;
      _nameController.text = p.personName;
      _mobileController.text = p.mobile ?? '';
      _jobController.text = p.wazefa ?? '';
      _rakmKomyController.text = p.rakmKomy ?? '';
      _birthDate = p.birthDate != null ? DateTime.tryParse(p.birthDate!) : null;
      _selectedKaraba = p.karabaId;
      _selectedMostwa = p.mostwaId;
      _selectedHala = p.halaEgtimaiaId;
      _selectedHealth = p.halaSehiaId;
      _selectedStage = p.stageId;
      _selectedFather = p.fatherId;
    }
  }

  Widget _buildPremiumField({
    required Widget child,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 40,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);
    final familyProvider = Provider.of<FamilyProvider>(context);

    return AlertDialog(
      title: Text(widget.existingPerson == null ? 'إضافة فرد جديد' : 'تعديل بيانات الفرد'),
      contentPadding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 0),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Personal Info - Using Row for Name/Relation to keep them side by side if possible
              Row(
                children: [
                  Expanded(
                    flex: 2, 
                    child: _buildPremiumField(
                      label: 'الاسم',
                      icon: Icons.person_outline,
                      child: TextField(
                        controller: _nameController, 
                        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8))
                      )
                    )
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: _buildPremiumField(
                      label: 'القرابة',
                      icon: Icons.family_restroom_outlined,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedKaraba,
                          items: lookup.karaba.map<DropdownMenuItem<int>>((k) => DropdownMenuItem<int>(value: k['karaba_id'] as int, child: Text(k['karaba_name'] as String))).toList(),
                          onChanged: (val) => setState(() => _selectedKaraba = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Birth Date & Stage
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 250,
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _birthDate ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _birthDate = d);
                      },
                      child: _buildPremiumField(
                        label: 'تاريخ الميلاد',
                        icon: Icons.calendar_today,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(_birthDate == null ? 'اختر التاريخ' : _birthDate!.toLocal().toString().split(' ')[0], style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: _buildPremiumField(
                      label: 'المرحلة المقيد بها',
                      icon: Icons.class_outlined,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedStage,
                          items: lookup.stages.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['stage_id'] as int, child: Text(s['stage_name'] as String))).toList(),
                          onChanged: (val) => setState(() => _selectedStage = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Statuses
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 250,
                    child: _buildPremiumField(
                      label: 'الحالة الاجتماعية',
                      icon: Icons.favorite_border,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedHala,
                          items: lookup.socialStatus.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['hala_egtimaia_id'] as int, child: Text(s['hala_name'] as String))).toList(),
                          onChanged: (val) => setState(() => _selectedHala = val),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: _buildPremiumField(
                      label: 'الحالة الصحية',
                      icon: Icons.medical_services_outlined,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedHealth,
                          items: lookup.healthStatus.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['hala_sehia_id'] as int, child: Text(s['hala_name'] as String))).toList(),
                          onChanged: (val) => setState(() => _selectedHealth = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Education & Work
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 250,
                    child: _buildPremiumField(
                      label: 'المستوى التعليمي',
                      icon: Icons.school_outlined,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedMostwa,
                          items: lookup.educationLevels.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(value: s['mostwa_id'] as int, child: Text(s['mostwa_name'] as String))).toList(),
                          onChanged: (val) => setState(() => _selectedMostwa = val),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: _buildPremiumField(
                      label: 'الوظيفة',
                      icon: Icons.work_outline,
                      child: TextField(
                        controller: _jobController, 
                        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8))
                      )
                    )
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contact & Nat ID
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 250,
                    child: _buildPremiumField(
                      label: 'الرقم القومي',
                      icon: Icons.badge_outlined,
                      child: TextField(
                        controller: _rakmKomyController, 
                        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8))
                      )
                    )
                  ),
                  SizedBox(
                    width: 250,
                    child: _buildPremiumField(
                      label: 'رقم الموبايل',
                      icon: Icons.phone_android,
                      child: TextField(
                        controller: _mobileController, 
                        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 8))
                      )
                    )
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Father
              Row(
                children: [
                  Expanded(
                    child: _buildPremiumField(
                      label: 'أب الاعتراف',
                      icon: Icons.person_pin,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedFather,
                          items: lookup.fathers.map<DropdownMenuItem<int>>((f) => DropdownMenuItem<int>(value: f.fatherId, child: Text(f.fatherName))).toList(),
                          onChanged: (val) => setState(() => _selectedFather = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontSize: 16))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            final p = Person(
              personId: widget.existingPerson?.personId,
              personName: _nameController.text,
              osraId: widget.osraId,
              karabaId: _selectedKaraba,
              birthDate: _birthDate?.toIso8601String(),
              mostwaId: _selectedMostwa,
              halaEgtimaiaId: _selectedHala,
              halaSehiaId: _selectedHealth,
              wazefa: _jobController.text,
              mobile: _mobileController.text,
              stageId: _selectedStage,
              fatherId: _selectedFather,
              age: _birthDate != null ? familyProvider.calculateAge(_birthDate!) : null,
              rakmKomy: _rakmKomyController.text,
            );
            await familyProvider.savePerson(p);
            widget.onSave();
            if (mounted) Navigator.pop(context);
          },
          child: const Text('حفظ الفرد', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
