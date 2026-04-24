class Family {
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

  Map<String, dynamic> toMap() => {
    'osra_id': osraId,
    'osra_name': osraName,
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
  };

  factory Family.fromMap(Map<String, dynamic> map) => Family(
    osraId: map['osra_id'],
    osraName: map['osra_name'],
    karabaId: map['karaba_id'],
    eSId: map['e_s_id'],
    areaId: map['area_id'],
    streetId: map['street_id'],
    dalilName: map['dalil_name'],
    emara: map['emara'],
    door: map['door'],
    shaka: map['shaka'],
    rO: map['r_o'],
    phone: map['phone'],
    number: map['number'] ?? 0,
    halaEgtimaiaId: map['hala_egtimaia_id'],
    halaSehiaId: map['hala_sehia_id'],
    mostwaId: map['mostwa_id'],
    rakmKomy: map['rakm_komy'],
    code: map['code'],
    memberCount: map['member_count'] ?? 0,
  );
}

class Person {
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

  Map<String, dynamic> toMap() => {
    'person_id': personId,
    'person_name': personName,
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
  };

  factory Person.fromMap(Map<String, dynamic> map) => Person(
    personId: map['person_id'],
    personName: map['person_name'],
    osraId: map['osra_id'],
    karabaId: map['karaba_id'],
    birthDate: map['birth_date'],
    mostwaId: map['mostwa_id'],
    moahil: map['moahil'],
    dateMoiahil: map['date_moiahil'],
    halaEgtimaiaId: map['hala_egtimaia_id'],
    halaSehiaId: map['hala_sehia_id'],
    wazefa: map['wazefa'],
    placeWork: map['place_work'],
    mobile: map['mobile'],
    facebook: map['facebook'],
    father: map['father'],
    stageId: map['stage_id'],
    fatherId: map['father_id'],
    month: map['month'],
    age: map['age'],
    rakmKomy: map['rakm_komy'],
  );
}
