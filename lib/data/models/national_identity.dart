String normalizeSearch(String value) => normalizeDigits(value)
    .toLowerCase()
    .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670ـ]'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

String normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  return value.trim();
}

class NationalIdentity {
  static const governorates = {
    '01': 'القاهرة',
    '02': 'الإسكندرية',
    '03': 'بورسعيد',
    '04': 'السويس',
    '11': 'دمياط',
    '12': 'الدقهلية',
    '13': 'الشرقية',
    '14': 'القليوبية',
    '15': 'كفر الشيخ',
    '16': 'الغربية',
    '17': 'المنوفية',
    '18': 'البحيرة',
    '19': 'الإسماعيلية',
    '21': 'الجيزة',
    '22': 'بني سويف',
    '23': 'الفيوم',
    '24': 'المنيا',
    '25': 'أسيوط',
    '26': 'سوهاج',
    '27': 'قنا',
    '28': 'أسوان',
    '29': 'الأقصر',
    '31': 'البحر الأحمر',
    '32': 'الوادي الجديد',
    '33': 'مطروح',
    '34': 'شمال سيناء',
    '35': 'جنوب سيناء',
    '88': 'خارج الجمهورية',
  };
  final DateTime birthDate;
  final String governorate;
  final String gender;
  NationalIdentity(this.birthDate, this.governorate, this.gender);

  int ageAt(DateTime now) =>
      now.year -
      birthDate.year -
      ((now.month < birthDate.month ||
              (now.month == birthDate.month && now.day < birthDate.day))
          ? 1
          : 0);
  int get age => ageAt(DateTime.now());

  static NationalIdentity? parse(String? value) {
    final id = normalizeDigits(value ?? '');
    if (!RegExp(r'^[23]\d{13}$').hasMatch(id)) return null;
    final year = (id[0] == '2' ? 1900 : 2000) + int.parse(id.substring(1, 3));
    final month = int.parse(id.substring(3, 5));
    final day = int.parse(id.substring(5, 7));
    final date = DateTime(year, month, day);
    final gov = governorates[id.substring(7, 9)];
    if (date.year != year ||
        date.month != month ||
        date.day != day ||
        date.isAfter(DateTime.now()) ||
        gov == null) {
      return null;
    }
    return NationalIdentity(
      date,
      gov,
      int.parse(id[12]).isOdd ? 'ذكر' : 'أنثى',
    );
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> source) {
    final map = {
      for (final entry in source.entries) entry.key.toLowerCase(): entry.value,
    };
    final identity = parse(map['rakm_komy']?.toString());
    if (identity != null) {
      map['rakm_komy'] = normalizeDigits(map['rakm_komy'].toString());
      map['birth_date'] = identity.birthDate.toIso8601String().split('T').first;
      map['gender'] = identity.gender;
      map['governorate'] = identity.governorate;
      map['age'] = identity.age.toString();
    }
    final date = DateTime.tryParse(map['birth_date']?.toString() ?? '');
    if (date != null) {
      map['month'] = date.month.toString();
      if (identity != null || (map['age']?.toString().trim().isEmpty ?? true)) {
        map['age'] = NationalIdentity(date, '', '').age.toString();
      }
    }
    return map;
  }
}
