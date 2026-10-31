import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../providers/financial_provider.dart';
import '../../../data/models/family_models.dart';
import '../../../data/services/pdf_service.dart';
import '../../../sync/signalr_sync_service.dart';
import '../../widgets/identity_fields.dart';

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
  bool _loadingPersons = false;
  String? _personsError;
  int _personsGeneration = 0;
  StreamSubscription<Set<String>>? _syncSubscription;
  Timer? _membersRefreshTimer;

  // Extracted National ID data
  String? _extractedGov;
  String? _extractedGender;
  int? _extractedAge;
  DateTime? _extractedBirthDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final lookup = Provider.of<LookupProvider>(context, listen: false);
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
          _extractedGov = args.governorate;
          _extractedGender = args.gender;
          _extractedAge = int.tryParse(args.age ?? '');
          _extractedBirthDate = DateTime.tryParse(args.birthDate ?? '');
          _codeController.text = args.code?.toString() ?? '';
          _selectedArea = args.areaId;
          _selectedKaraba = args.karabaId;
          _selectedES = args.eSId;
          _selectedHala = args.halaEgtimaiaId;
          _selectedHalaSehia = args.halaSehiaId;
          _selectedMostwa = args.mostwaId;
        });

        _selectedStreet = args.streetId;
        unawaited(_loadPersons());
      }
      // Members must not wait for nine unrelated lookup requests.
      try {
        await Future.wait([
          lookup.loadAllLookups(),
          if (args is Family && args.areaId != null)
            lookup.loadStreets(args.areaId!),
        ]);
        if (mounted) setState(() {});
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر تحميل بعض القوائم. يمكنك إعادة المحاولة.'),
            ),
          );
        }
      }
    });
    _syncSubscription = SignalRSyncService.instance.onTablesChanged.listen((
      tables,
    ) {
      if (tables.contains('*') ||
          tables.contains('person') ||
          tables.contains('osra')) {
        _membersRefreshTimer?.cancel();
        _membersRefreshTimer = Timer(const Duration(milliseconds: 120), () {
          if (mounted) unawaited(_loadPersons(silent: true));
        });
      }
    });
  }

  @override
  void dispose() {
    _membersRefreshTimer?.cancel();
    _syncSubscription?.cancel();
    _personsGeneration++;
    _tabController.dispose();
    for (final controller in [
      _nameController,
      _dalilController,
      _emaraController,
      _doorController,
      _shakaController,
      _roController,
      _phoneController,
      _codeController,
    ]) {
      controller.dispose();
    }
    _rakmKomyController.dispose();
    super.dispose();
  }

  Future<void> _loadPersons({bool silent = false}) async {
    final id = _existingFamily?.osraId;
    if (id == null || !mounted) return;
    final generation = ++_personsGeneration;
    if (!silent) {
      setState(() {
        _loadingPersons = true;
        _personsError = null;
      });
    }
    try {
      final persons = await context.read<FamilyProvider>().getPersons(id);
      if (!mounted || generation != _personsGeneration) return;
      setState(() {
        _persons = persons;
        _personsError = null;
        _loadingPersons = false;
      });
    } catch (error) {
      if (!mounted || generation != _personsGeneration) return;
      setState(() {
        _loadingPersons = false;
        _personsError =
            'تعذر تحميل أفراد الأسرة. تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final family = Family(
      osraId: _existingFamily?.osraId,
      osraName: _nameController.text.trim(),
      karabaId: _selectedKaraba,
      eSId: _selectedES,
      areaId: _selectedArea,
      streetId: _selectedStreet,
      dalilName: _dalilController.text.trim(),
      emara: _emaraController.text.trim().isNotEmpty
          ? _emaraController.text.trim()
          : _nameController.text.trim(),
      door: _doorController.text.trim(),
      shaka: _shakaController.text.trim(),
      rO: _roController.text.trim(),
      phone: _phoneController.text.trim(),
      halaEgtimaiaId: _selectedHala,
      halaSehiaId: _selectedHalaSehia,
      mostwaId: _selectedMostwa,
      rakmKomy: _rakmKomyController.text.trim(),
      code: int.tryParse(_codeController.text.trim()),
      birthDate: _extractedBirthDate?.toIso8601String(),
      age: _extractedAge?.toString(),
      gender: _extractedGender,
      governorate: _extractedGov,
    );

    await Provider.of<FamilyProvider>(
      context,
      listen: false,
    ).saveFamily(family);
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
        title: Text(
          _existingFamily == null ? 'إضافة أسرة جديدة' : 'تعديل أسرة',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'حفظ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف الأسرة'),
                  content: Text(
                    'هل أنت متأكد من حذف أسرة ${_existingFamily!.osraName} وكل البيانات المتعلقة بها؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final dialogNav = Navigator.of(ctx);
                        await Provider.of<FamilyProvider>(
                          context,
                          listen: false,
                        ).deleteFamily(_existingFamily!.osraId!);
                        dialogNav.pop(); // Close dialog
                        nav.pop(); // Go back to list
                      },
                      child: const Text(
                        'حذف',
                        style: TextStyle(color: Colors.red),
                      ),
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
          children: [_buildFamilyDetails(lookup), _buildPersonsList()],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPremiumField({
    required Widget child,
    required String label,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final labelColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Theme.of(context).primaryColor),
              const SizedBox(width: 6),
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
          SizedBox(height: 38, child: child),
        ],
      ),
    );
  }

  Widget _buildFamilyDetails(LookupProvider lookup) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 760;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 12,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. البيانات الأساسية لرب الأسرة
              _buildSectionCard(
                title: 'البيانات الأساسية لرب الأسرة',
                icon: Icons.badge_outlined,
                children: [
                  if (isDesktop) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildPremiumField(
                            label: 'اسم الأسرة (رب الأسرة)',
                            icon: Icons.family_restroom,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                                hintText: 'أدخل اسم رب الأسرة كاملاً',
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildPremiumField(
                            label: 'الكود',
                            icon: Icons.qr_code,
                            child: TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                                hintText: 'كود الأسرة',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildPremiumField(
                            label: 'القرابة',
                            icon: Icons.people_outline,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedKaraba,
                                hint: const Text('صلة القرابة',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.karaba
                                    .map<DropdownMenuItem<int>>(
                                      (k) => DropdownMenuItem<int>(
                                        value: k['karaba_id'] as int,
                                        child: Text(k['karaba_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedKaraba = val),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Mobile
                    _buildPremiumField(
                      label: 'اسم الأسرة (رب الأسرة)',
                      icon: Icons.family_restroom,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(bottom: 8),
                          hintText: 'أدخل اسم رب الأسرة كاملاً',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الكود',
                            icon: Icons.qr_code,
                            child: TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                                hintText: 'الكود',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildPremiumField(
                            label: 'القرابة',
                            icon: Icons.people_outline,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedKaraba,
                                hint: const Text('صلة القرابة',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.karaba
                                    .map<DropdownMenuItem<int>>(
                                      (k) => DropdownMenuItem<int>(
                                        value: k['karaba_id'] as int,
                                        child: Text(k['karaba_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedKaraba = val),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              // 2. بطاقة الرقم القومي والبيانات المستخرجة
              _buildSectionCard(
                title: 'بطاقة الرقم القومي والبيانات الشخصية',
                icon: Icons.credit_card_rounded,
                children: [
                  _buildPremiumField(
                    label: 'الرقم القومي (14 رقم)',
                    icon: Icons.badge_outlined,
                    child: TextFormField(
                      controller: _rakmKomyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(bottom: 8),
                        hintText: 'أدخل 14 رقماً لاستخراج البيانات تلقائياً',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  IdentityFields(
                    nationalId: _rakmKomyController,
                    governorate: _extractedGov,
                    gender: _extractedGender,
                    age: _extractedAge?.toString(),
                    birthDate: _extractedBirthDate,
                    onChanged: (gov, gender, age, date) {
                      _extractedGov = gov;
                      _extractedGender = gender;
                      _extractedAge = age;
                      _extractedBirthDate = date;
                    },
                  ),
                ],
              ),

              // 3. العنوان وبيانات السكن
              _buildSectionCard(
                title: 'العنوان وبيانات السكن',
                icon: Icons.location_on_outlined,
                children: [
                  if (isDesktop) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildPremiumField(
                            label: 'المنطقة',
                            icon: Icons.map,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedArea,
                                hint: const Text('اختر المنطقة',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.areas
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a.areaId,
                                        child: Text(a.areaName),
                                      ),
                                    )
                                    .toList(),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الشارع',
                            icon: Icons.add_road,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedStreet,
                                hint: const Text('اختر الشارع',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.streets
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.streetId,
                                        child: Text(s.streetName),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedStreet = val),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildPremiumField(
                            label: 'الدور',
                            icon: Icons.apartment,
                            child: TextFormField(
                              controller: _doorController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                                hintText: 'رقم الدور',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildPremiumField(
                            label: 'الشقة',
                            icon: Icons.door_front_door_outlined,
                            child: TextFormField(
                              controller: _shakaController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                                hintText: 'رقم الشقة',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildPremiumField(
                            label: 'دليل / علامة مميزة',
                            icon: Icons.flag_outlined,
                            child: TextFormField(
                              controller: _dalilController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                                hintText: 'علامة مميزة أو تفاصيل العنوان',
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
                          child: _buildPremiumField(
                            label: 'المنطقة',
                            icon: Icons.map,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedArea,
                                hint: const Text('المنطقة',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.areas
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a.areaId,
                                        child: Text(a.areaName),
                                      ),
                                    )
                                    .toList(),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الشارع',
                            icon: Icons.add_road,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedStreet,
                                hint: const Text('الشارع',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.streets
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.streetId,
                                        child: Text(s.streetName),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedStreet = val),
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
                          child: _buildPremiumField(
                            label: 'الدور',
                            icon: Icons.apartment,
                            child: TextFormField(
                              controller: _doorController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                                hintText: 'الدور',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الشقة',
                            icon: Icons.door_front_door_outlined,
                            child: TextFormField(
                              controller: _shakaController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                                hintText: 'الشقة',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildPremiumField(
                      label: 'دليل / علامة مميزة',
                      icon: Icons.flag_outlined,
                      child: TextFormField(
                        controller: _dalilController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(bottom: 8),
                          hintText: 'علامة مميزة أو تفاصيل العنوان',
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // 4. بيانات الاتصال والتواصل
              _buildSectionCard(
                title: 'بيانات الاتصال والتواصل',
                icon: Icons.phone_in_talk_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPremiumField(
                          label: 'رقم الموبايل',
                          icon: Icons.phone_android,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 8),
                              hintText: 'رقم المحمول',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPremiumField(
                          label: isDesktop ? 'رقم التليفون (أرضي)' : 'الهاتف الأرضي',
                          icon: Icons.call,
                          child: TextFormField(
                            controller: _roController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              hintText: 'الهاتف الأرضي',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 5. الحالة الاجتماعية والاقتصادية والصحية
              _buildSectionCard(
                title: 'الحالة الاجتماعية والاقتصادية والتعليمية',
                icon: Icons.volunteer_activism_rounded,
                children: [
                  if (isDesktop) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الحالة الاقتصادية',
                            icon: Icons.attach_money,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedES,
                                hint: const Text('الحالة الاقتصادية',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.economicStatus
                                    .map<DropdownMenuItem<int>>(
                                      (e) => DropdownMenuItem<int>(
                                        value: e['e_s_id'] as int,
                                        child: Text(e['e_s_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedES = val),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الحالة الاجتماعية',
                            icon: Icons.favorite_border,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedHala,
                                hint: const Text('الحالة الاجتماعية',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.socialStatus
                                    .map<DropdownMenuItem<int>>(
                                      (s) => DropdownMenuItem<int>(
                                        value: s['hala_egtimaia_id'] as int,
                                        child: Text(s['hala_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedHala = val),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الحالة الصحية',
                            icon: Icons.medical_services_outlined,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedHalaSehia,
                                hint: const Text('الحالة الصحية',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.healthStatus
                                    .map<DropdownMenuItem<int>>(
                                      (h) => DropdownMenuItem<int>(
                                        value: h['hala_sehia_id'] as int,
                                        child: Text(h['hala_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedHalaSehia = val),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPremiumField(
                            label: 'المستوى التعليمي',
                            icon: Icons.school_outlined,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedMostwa,
                                hint: const Text('المستوى التعليمي',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.educationLevels
                                    .map<DropdownMenuItem<int>>(
                                      (m) => DropdownMenuItem<int>(
                                        value: m['mostwa_id'] as int,
                                        child: Text(m['mostwa_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedMostwa = val),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Mobile: 2 rows of 2 columns
                    Row(
                      children: [
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الحالة الاقتصادية',
                            icon: Icons.attach_money,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedES,
                                hint: const Text('الاقتصادية',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.economicStatus
                                    .map<DropdownMenuItem<int>>(
                                      (e) => DropdownMenuItem<int>(
                                        value: e['e_s_id'] as int,
                                        child: Text(e['e_s_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedES = val),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPremiumField(
                            label: 'الحالة الاجتماعية',
                            icon: Icons.favorite_border,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedHala,
                                hint: const Text('الاجتماعية',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.socialStatus
                                    .map<DropdownMenuItem<int>>(
                                      (s) => DropdownMenuItem<int>(
                                        value: s['hala_egtimaia_id'] as int,
                                        child: Text(s['hala_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedHala = val),
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
                          child: _buildPremiumField(
                            label: 'الحالة الصحية',
                            icon: Icons.medical_services_outlined,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedHalaSehia,
                                hint: const Text('الصحية',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.healthStatus
                                    .map<DropdownMenuItem<int>>(
                                      (h) => DropdownMenuItem<int>(
                                        value: h['hala_sehia_id'] as int,
                                        child: Text(h['hala_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedHalaSehia = val),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPremiumField(
                            label: 'المستوى التعليمي',
                            icon: Icons.school_outlined,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedMostwa,
                                hint: const Text('التعليمي',
                                    style: TextStyle(fontSize: 13)),
                                items: lookup.educationLevels
                                    .map<DropdownMenuItem<int>>(
                                      (m) => DropdownMenuItem<int>(
                                        value: m['mostwa_id'] as int,
                                        child: Text(m['mostwa_name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedMostwa = val),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),
              // Prominent Save button inside the scroll
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 22),
                label: const Text(
                  'حفظ بيانات الأسرة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonsList() {
    if (_existingFamily == null) {
      return const Center(
        child: Text('من فضلك احفظ الأسرة أولاً لإضافة أفراد'),
      );
    }

    final lookup = Provider.of<LookupProvider>(context, listen: false);

    if (_loadingPersons && _persons.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_personsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_personsError!),
            TextButton(
              onPressed: _loadPersons,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (_persons.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('لا يوجد أفراد مسجلون في هذه الأسرة'),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showPersonDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text(
                'إضافة فرد جديد',
                style: TextStyle(fontSize: 16),
              ),
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
              final socialName = lookup.getHalaEgtimaiaName(
                person.halaEgtimaiaId,
              );
              final educationName = lookup.getEducationLevelName(
                person.mostwaId,
              );

              final isDark = Theme.of(context).brightness == Brightness.dark;
              final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
              final textSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

              return Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.personName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (person.mobile != null &&
                                          person.mobile!.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 14,
                                              color: textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              person.mobile!,
                                              style: TextStyle(
                                                color: textSecondary,
                                                fontSize: 13,
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _showPersonDialog(person),
                                tooltip: 'تعديل الفرد',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  await Provider.of<FamilyProvider>(
                                    context,
                                    listen: false,
                                  ).deletePerson(person.personId!);
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
                              avatar: const Icon(
                                Icons.family_restroom,
                                size: 16,
                                color: Colors.teal,
                              ),
                              label: Text(karaba),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.teal.shade50,
                              labelStyle: TextStyle(
                                color: isDark ? const Color(0xFF5EEAD4) : Colors.teal.shade800,
                                fontSize: 13,
                              ),
                            ),
                          if (person.age != null)
                            Chip(
                              avatar: const Icon(
                                Icons.cake,
                                size: 16,
                                color: Colors.orange,
                              ),
                              label: Text('${person.age} سنة'),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.orange.shade50,
                              labelStyle: TextStyle(
                                color: isDark ? const Color(0xFFFDBA74) : Colors.orange.shade800,
                                fontSize: 13,
                              ),
                            ),
                          if (socialName != '---')
                            Chip(
                              avatar: const Icon(
                                Icons.favorite,
                                size: 16,
                                color: Colors.pink,
                              ),
                              label: Text(socialName),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.pink.shade50,
                              labelStyle: TextStyle(
                                color: isDark ? const Color(0xFFF472B6) : Colors.pink.shade800,
                                fontSize: 13,
                              ),
                            ),
                          if (healthName != '---')
                            Chip(
                              avatar: const Icon(
                                Icons.medical_services,
                                size: 16,
                                color: Colors.indigo,
                              ),
                              label: Text(healthName),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.indigo.shade50,
                              labelStyle: TextStyle(
                                color: isDark ? const Color(0xFFA5B4FC) : Colors.indigo.shade800,
                                fontSize: 13,
                              ),
                            ),
                          if (educationName != '---')
                            Chip(
                              avatar: const Icon(
                                Icons.school,
                                size: 16,
                                color: Colors.purple,
                              ),
                              label: Text(educationName),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.purple.shade50,
                              labelStyle: TextStyle(
                                color: isDark ? const Color(0xFFD8B4FE) : Colors.purple.shade800,
                                fontSize: 13,
                              ),
                            ),
                          if (stage != '---')
                            Chip(
                              avatar: const Icon(
                                Icons.class_,
                                size: 16,
                                color: Colors.blue,
                              ),
                              label: Text(stage),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                              labelStyle: TextStyle(
                                color: isDark ? const Color(0xFF93C5FD) : Colors.blue.shade800,
                                fontSize: 13,
                              ),
                            ),
                          if (person.wazefa != null &&
                              person.wazefa!.isNotEmpty)
                            Chip(
                              avatar: const Icon(
                                Icons.work,
                                size: 16,
                                color: Colors.brown,
                              ),
                              label: Text(person.wazefa!),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.brown.shade50,
                              labelStyle: TextStyle(
                                color: isDark ? const Color(0xFFD6D3D1) : Colors.brown.shade800,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                      if (person.rakmKomy != null &&
                          person.rakmKomy!.isNotEmpty) ...[
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
                            Icon(
                              Icons.badge_outlined,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
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

  const PersonFormDialog({
    super.key,
    required this.osraId,
    this.existingPerson,
    required this.onSave,
  });

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

  // Extracted National ID data
  String? _extractedGov;
  String? _extractedGender;
  int? _extractedAge;

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
      _extractedGov = p.governorate;
      _extractedGender = p.gender;
      _extractedAge = int.tryParse(p.age?.split(' ').first ?? '');
      _selectedKaraba = p.karabaId;
      _selectedMostwa = p.mostwaId;
      _selectedHala = p.halaEgtimaiaId;
      _selectedHealth = p.halaSehiaId;
      _selectedStage = p.stageId;
      _selectedFather = p.fatherId;
    }
  }

  @override
  void dispose() {
    _rakmKomyController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _jobController.dispose();
    super.dispose();
  }

  Widget _buildPremiumField({
    required Widget child,
    required String label,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final labelColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Theme.of(context).primaryColor),
              const SizedBox(width: 6),
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
          SizedBox(height: 38, child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);
    final familyProvider = Provider.of<FamilyProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 620;
    final dialogWidth = isMobile ? screenWidth * 0.94 : 640.0;

    final nameField = _buildPremiumField(
      label: 'الاسم',
      icon: Icons.person_outline,
      child: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          hintText: 'الاسم بالكامل',
        ),
      ),
    );

    final karabaField = _buildPremiumField(
      label: 'القرابة',
      icon: Icons.family_restroom_outlined,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedKaraba,
          hint: const Text('صلة القرابة', style: TextStyle(fontSize: 13)),
          items: lookup.karaba
              .map<DropdownMenuItem<int>>(
                (k) => DropdownMenuItem<int>(
                  value: k['karaba_id'] as int,
                  child: Text(k['karaba_name'] as String, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedKaraba = val),
        ),
      ),
    );

    final stageField = _buildPremiumField(
      label: 'المرحلة المقيد بها',
      icon: Icons.class_outlined,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedStage,
          hint: const Text('المرحلة', style: TextStyle(fontSize: 13)),
          items: lookup.stages
              .map<DropdownMenuItem<int>>(
                (s) => DropdownMenuItem<int>(
                  value: s['stage_id'] as int,
                  child: Text(s['stage_name'] as String, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedStage = val),
        ),
      ),
    );

    final fatherField = _buildPremiumField(
      label: 'أب الاعتراف',
      icon: Icons.person_pin,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedFather,
          hint: const Text('الكاهن', style: TextStyle(fontSize: 13)),
          items: lookup.fathers
              .map<DropdownMenuItem<int>>(
                (f) => DropdownMenuItem<int>(
                  value: f.fatherId,
                  child: Text(f.fatherName, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedFather = val),
        ),
      ),
    );

    final socialField = _buildPremiumField(
      label: 'الحالة الاجتماعية',
      icon: Icons.favorite_border,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedHala,
          hint: const Text('الاجتماعية', style: TextStyle(fontSize: 13)),
          items: lookup.socialStatus
              .map<DropdownMenuItem<int>>(
                (s) => DropdownMenuItem<int>(
                  value: s['hala_egtimaia_id'] as int,
                  child: Text(s['hala_name'] as String, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedHala = val),
        ),
      ),
    );

    final healthField = _buildPremiumField(
      label: 'الحالة الصحية',
      icon: Icons.medical_services_outlined,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedHealth,
          hint: const Text('الصحية', style: TextStyle(fontSize: 13)),
          items: lookup.healthStatus
              .map<DropdownMenuItem<int>>(
                (s) => DropdownMenuItem<int>(
                  value: s['hala_sehia_id'] as int,
                  child: Text(s['hala_name'] as String, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedHealth = val),
        ),
      ),
    );

    final educationField = _buildPremiumField(
      label: 'المستوى التعليمي',
      icon: Icons.school_outlined,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedMostwa,
          hint: const Text('التعليمي', style: TextStyle(fontSize: 13)),
          items: lookup.educationLevels
              .map<DropdownMenuItem<int>>(
                (s) => DropdownMenuItem<int>(
                  value: s['mostwa_id'] as int,
                  child: Text(s['mostwa_name'] as String, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedMostwa = val),
        ),
      ),
    );

    final jobField = _buildPremiumField(
      label: 'الوظيفة',
      icon: Icons.work_outline,
      child: TextField(
        controller: _jobController,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          hintText: 'المهنة أو الوظيفة',
        ),
      ),
    );

    final mobileField = _buildPremiumField(
      label: 'رقم الموبايل',
      icon: Icons.phone_android,
      child: TextField(
        controller: _mobileController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          hintText: 'رقم الهاتف المحمول',
        ),
      ),
    );

    final nationalIdField = _buildPremiumField(
      label: 'الرقم القومي',
      icon: Icons.badge_outlined,
      child: TextField(
        controller: _rakmKomyController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          hintText: '14 رقم',
        ),
      ),
    );

    final identityWidget = IdentityFields(
      nationalId: _rakmKomyController,
      governorate: _extractedGov,
      gender: _extractedGender,
      age: _extractedAge?.toString(),
      birthDate: _birthDate,
      onChanged: (gov, gender, age, date) {
        _extractedGov = gov;
        _extractedGender = gender;
        _extractedAge = age;
        _birthDate = date;
      },
    );

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.existingPerson == null
                  ? Icons.person_add_rounded
                  : Icons.edit_note_rounded,
              color: Theme.of(context).primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.existingPerson == null
                  ? 'إضافة فرد جديد'
                  : 'تعديل بيانات الفرد',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 500;
              if (isWide) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 3, child: nameField),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: karabaField),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: stageField),
                        const SizedBox(width: 10),
                        Expanded(child: fatherField),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: socialField),
                        const SizedBox(width: 10),
                        Expanded(child: healthField),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: educationField),
                        const SizedBox(width: 10),
                        Expanded(child: jobField),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: mobileField),
                        const SizedBox(width: 10),
                        Expanded(child: nationalIdField),
                      ],
                    ),
                    const SizedBox(height: 12),
                    identityWidget,
                    const SizedBox(height: 8),
                  ],
                );
              } else {
                // Mobile layout: generous single-column fields so no labels or hints are cut off
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nameField,
                    const SizedBox(height: 10),
                    karabaField,
                    const SizedBox(height: 10),
                    stageField,
                    const SizedBox(height: 10),
                    fatherField,
                    const SizedBox(height: 10),
                    socialField,
                    const SizedBox(height: 10),
                    healthField,
                    const SizedBox(height: 10),
                    educationField,
                    const SizedBox(height: 10),
                    jobField,
                    const SizedBox(height: 10),
                    mobileField,
                    const SizedBox(height: 10),
                    nationalIdField,
                    const SizedBox(height: 12),
                    identityWidget,
                    const SizedBox(height: 8),
                  ],
                );
              }
            },
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(fontSize: 15)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 18),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
            final p = Person(
              personId: widget.existingPerson?.personId,
              personName: _nameController.text.trim(),
              osraId: widget.osraId,
              karabaId: _selectedKaraba,
              birthDate: _birthDate?.toIso8601String(),
              mostwaId: _selectedMostwa,
              halaEgtimaiaId: _selectedHala,
              halaSehiaId: _selectedHealth,
              wazefa: _jobController.text.trim(),
              mobile: _mobileController.text.trim(),
              stageId: _selectedStage,
              fatherId: _selectedFather,
              age: _extractedAge?.toString(),
              gender: _extractedGender,
              governorate: _extractedGov,
              rakmKomy: _rakmKomyController.text.trim(),
            );
            final nav = Navigator.of(context);
            await familyProvider.savePerson(p);
            widget.onSave();
            if (mounted) nav.pop();
          },
          label: const Text('حفظ الفرد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
