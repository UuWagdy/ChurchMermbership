import 'package:flutter/material.dart';
import '../../data/models/national_identity.dart';

class IdentityFields extends StatefulWidget {
  final TextEditingController nationalId;
  final String? gender;
  final String? governorate;
  final String? age;
  final DateTime? birthDate;
  final void Function(String?, String?, int?, DateTime?) onChanged;

  const IdentityFields({
    super.key,
    required this.nationalId,
    this.gender,
    this.governorate,
    this.age,
    this.birthDate,
    required this.onChanged,
  });

  @override
  State<IdentityFields> createState() => _IdentityFieldsState();
}

class _IdentityFieldsState extends State<IdentityFields> {
  late final TextEditingController _age;
  late final TextEditingController _governorate;
  String? _gender;
  DateTime? _birthDate;
  bool get _locked => NationalIdentity.parse(widget.nationalId.text) != null;

  @override
  void initState() {
    super.initState();
    _age = TextEditingController(text: widget.age?.split(' ').first ?? '');
    _governorate = TextEditingController(text: widget.governorate ?? '');
    _gender = widget.gender;
    _birthDate = widget.birthDate;
    final identity = NationalIdentity.parse(widget.nationalId.text);
    if (identity != null) _apply(identity);
    widget.nationalId.addListener(_idChanged);
  }

  void _apply(NationalIdentity identity) {
    _gender = identity.gender;
    _governorate.text = identity.governorate;
    _age.text = identity.age.toString();
    _birthDate = identity.birthDate;
  }

  void _emit() => widget.onChanged(
        _governorate.text.trim(),
        _gender,
        int.tryParse(normalizeDigits(_age.text)),
        _birthDate,
      );

  void _idChanged() {
    final identity = NationalIdentity.parse(widget.nationalId.text);
    setState(() {
      if (identity != null) _apply(identity);
    });
    _emit();
  }

  @override
  void dispose() {
    widget.nationalId.removeListener(_idChanged);
    _age.dispose();
    _governorate.dispose();
    super.dispose();
  }

  Widget _buildFieldBox({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final labelColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700;
    final primaryColor = Theme.of(context).primaryColor;

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
              Icon(icon, size: 15, color: primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
              if (_locked)
                const Icon(
                  Icons.lock_rounded,
                  size: 13,
                  color: Colors.teal,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;
        final isMedium = constraints.maxWidth >= 440 && !isWide;

        final genderWidget = _buildFieldBox(
          context: context,
          label: 'النوع',
          icon: Icons.wc_rounded,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _gender,
              hint: const Text('اختر النوع', style: TextStyle(fontSize: 13)),
              items: const [
                DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
              ],
              onChanged: _locked
                  ? null
                  : (val) {
                      setState(() => _gender = val);
                      _emit();
                    },
            ),
          ),
        );

        final ageWidget = _buildFieldBox(
          context: context,
          label: 'السن',
          icon: Icons.cake_outlined,
          child: TextFormField(
            controller: _age,
            readOnly: _locked,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              hintText: 'العمر',
            ),
            onChanged: (_) => _emit(),
          ),
        );

        final govWidget = _buildFieldBox(
          context: context,
          label: 'المحافظة',
          icon: Icons.location_city_outlined,
          child: TextFormField(
            controller: _governorate,
            readOnly: _locked,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              hintText: 'اسم المحافظة',
            ),
            onChanged: (_) => _emit(),
          ),
        );

        final birthDateWidget = _buildFieldBox(
          context: context,
          label: 'تاريخ الميلاد',
          icon: Icons.calendar_month_outlined,
          child: InkWell(
            onTap: _locked
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _birthDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (date == null || !mounted) return;
                    setState(() {
                      _birthDate = date;
                      _age.text = NationalIdentity(
                        date,
                        '',
                        '',
                      ).age.toString();
                    });
                    _emit();
                  },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _birthDate?.toIso8601String().split('T').first ??
                        'اختر التاريخ',
                    style: TextStyle(
                      fontSize: 13,
                      color: _birthDate == null
                          ? Colors.grey
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: _locked ? Colors.teal : Colors.grey,
                ),
              ],
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide) ...[
              // 4 columns on wide screens
              Row(
                children: [
                  Expanded(child: genderWidget),
                  const SizedBox(width: 10),
                  Expanded(child: ageWidget),
                  const SizedBox(width: 10),
                  Expanded(child: govWidget),
                  const SizedBox(width: 10),
                  Expanded(child: birthDateWidget),
                ],
              ),
            ] else if (isMedium) ...[
              // 2 rows of 2 columns on medium screens
              Row(
                children: [
                  Expanded(child: genderWidget),
                  const SizedBox(width: 10),
                  Expanded(child: ageWidget),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: govWidget),
                  const SizedBox(width: 10),
                  Expanded(child: birthDateWidget),
                ],
              ),
            ] else ...[
              // Mobile / Compact dialog view: gender+age pair, then full-width gov and birthDate for full readability
              Row(
                children: [
                  Expanded(child: genderWidget),
                  const SizedBox(width: 8),
                  Expanded(child: ageWidget),
                ],
              ),
              const SizedBox(height: 8),
              govWidget,
              const SizedBox(height: 8),
              birthDateWidget,
            ],
            if (_locked) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.teal),
                    SizedBox(width: 6),
                    Text(
                      'البيانات مستخرجة ومقفلة تلقائياً من الرقم القومي',
                      style: TextStyle(
                        color: Colors.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
