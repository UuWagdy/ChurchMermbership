import 'national_identity.dart';

class Family {
  final String? birthDate;
  final String? age;
  final String? gender;
  final String? governorate;
  final int? osraId;
  final String osraName;
  final int? karabaId;
  final int? eSId;
  final int? areaId;
  final int? streetId;
  final String? dalilName;
  final String? emara;
  final String? door;
  final String? shaka;
  final String? rO;
  final String? phone;
  final int number;
  final int? halaEgtimaiaId;
  final int? halaSehiaId;
  final int? mostwaId;
  final String? rakmKomy;
  final int? code;
  final int memberCount;

  Family({
    this.birthDate,
    this.age,
    this.gender,
    this.governorate,
    this.osraId,
    required this.osraName,
    this.karabaId,
    this.eSId,
    this.areaId,
    this.streetId,
    this.dalilName,
    this.emara,
    this.door,
    this.shaka,
    this.rO,
    this.phone,
    this.number = 0,
    this.halaEgtimaiaId,
    this.halaSehiaId,
    this.mostwaId,
    this.rakmKomy,
    this.code,
    this.memberCount = 0,
  });

  Map<String, dynamic> toMap() => NationalIdentity.normalize({
    'osra_id': osraId,
    'osra_name': osraName,
    'birth_date': birthDate,
    'age': age,
    'gender': gender,
    'governorate': governorate,
    'karaba_id': karabaId,
    'e_s_id': eSId,
    'area_id': areaId,
    'street_id': streetId,
    'dalil_name': dalilName,
    'emara': emara,
    'door': door,
    'shaka': shaka,
    'r_o': rO,
    'phone': phone,
    'number': number,
    'hala_egtimaia_id': halaEgtimaiaId,
    'hala_sehia_id': halaSehiaId,
    'mostwa_id': mostwaId,
    'rakm_komy': rakmKomy,
    'code': code,
  })..remove('month');

  factory Family.fromMap(Map<String, dynamic> map) {
    map = NationalIdentity.normalize(map);
    return Family(
      gender: map['gender']?.toString(),
      governorate: map['governorate']?.toString(),
      birthDate: map['birth_date']?.toString(),
      age: map['age']?.toString(),
      osraId: (map['osra_id'] as num?)?.toInt(),
      osraName: map['osra_name']?.toString() ?? '',
      karabaId: (map['karaba_id'] as num?)?.toInt(),
      eSId: (map['e_s_id'] as num?)?.toInt(),
      areaId: (map['area_id'] as num?)?.toInt(),
      streetId: (map['street_id'] as num?)?.toInt(),
      dalilName: map['dalil_name']?.toString(),
      emara: map['emara']?.toString(),
      door: map['door']?.toString(),
      shaka: map['shaka']?.toString(),
      rO: map['r_o']?.toString(),
      phone: map['phone']?.toString(),
      number: (map['number'] as num?)?.toInt() ?? 0,
      halaEgtimaiaId: (map['hala_egtimaia_id'] as num?)?.toInt(),
      halaSehiaId: (map['hala_sehia_id'] as num?)?.toInt(),
      mostwaId: (map['mostwa_id'] as num?)?.toInt(),
      rakmKomy: map['rakm_komy']?.toString(),
      code: (map['code'] as num?)?.toInt(),
      memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class Person {
  final String? gender;
  final String? governorate;
  final int? personId;
  final String personName;
  final int osraId;
  final int? karabaId;
  final String? birthDate;
  final int? mostwaId;
  final String? moahil;
  final String? dateMoiahil;
  final int? halaEgtimaiaId;
  final int? halaSehiaId;
  final String? wazefa;
  final String? placeWork;
  final String? mobile;
  final String? facebook;
  final String? father; // Name of spiritual father (string in original db)
  final int? stageId;
  final int? fatherId; // ID of priest in Fathers table
  final String? month;
  final String? age;
  final String? rakmKomy;

  Person({
    this.gender,
    this.governorate,
    this.personId,
    required this.personName,
    required this.osraId,
    this.karabaId,
    this.birthDate,
    this.mostwaId,
    this.moahil,
    this.dateMoiahil,
    this.halaEgtimaiaId,
    this.halaSehiaId,
    this.wazefa,
    this.placeWork,
    this.mobile,
    this.facebook,
    this.father,
    this.stageId,
    this.fatherId,
    this.month,
    this.age,
    this.rakmKomy,
  });

  Map<String, dynamic> toMap() => NationalIdentity.normalize({
    'person_id': personId,
    'person_name': personName,
    'gender': gender,
    'governorate': governorate,
    'osra_id': osraId,
    'karaba_id': karabaId,
    'birth_date': birthDate,
    'mostwa_id': mostwaId,
    'moahil': moahil,
    'date_moiahil': dateMoiahil,
    'hala_egtimaia_id': halaEgtimaiaId,
    'hala_sehia_id': halaSehiaId,
    'wazefa': wazefa,
    'place_work': placeWork,
    'mobile': mobile,
    'facebook': facebook,
    'father': father,
    'stage_id': stageId,
    'father_id': fatherId,
    'month': month,
    'age': age,
    'rakm_komy': rakmKomy,
  });

  factory Person.fromMap(Map<String, dynamic> map) {
    map = NationalIdentity.normalize(map);
    return Person(
      personId: (map['person_id'] as num?)?.toInt(),
      personName: map['person_name']?.toString() ?? '',
      gender: map['gender']?.toString(),
      governorate: map['governorate']?.toString(),
      osraId: (map['osra_id'] as num?)?.toInt() ?? 0,
      karabaId: (map['karaba_id'] as num?)?.toInt(),
      birthDate: map['birth_date']?.toString(),
      mostwaId: (map['mostwa_id'] as num?)?.toInt(),
      moahil: map['moahil']?.toString(),
      dateMoiahil: map['date_moiahil']?.toString(),
      halaEgtimaiaId: (map['hala_egtimaia_id'] as num?)?.toInt(),
      halaSehiaId: (map['hala_sehia_id'] as num?)?.toInt(),
      wazefa: map['wazefa']?.toString(),
      placeWork: map['place_work']?.toString(),
      mobile: map['mobile']?.toString(),
      facebook: map['facebook']?.toString(),
      father: map['father']?.toString(),
      stageId: (map['stage_id'] as num?)?.toInt(),
      fatherId: (map['father_id'] as num?)?.toInt(),
      month: map['month']?.toString(),
      age: map['age']?.toString(),
      rakmKomy: map['rakm_komy']?.toString(),
    );
  }
}
