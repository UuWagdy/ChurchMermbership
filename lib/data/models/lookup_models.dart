class Area {
  final int? areaId;
  final String areaName;

  Area({this.areaId, required this.areaName});

  Map<String, dynamic> toMap() => {'area_id': areaId, 'area_name': areaName};
  factory Area.fromMap(Map<String, dynamic> map) => Area(
    areaId: map['area_id'],
    areaName: map['area_name'],
  );
}

class Street {
  final int? streetId;
  final String streetName;
  final int areaId;

  Street({this.streetId, required this.streetName, required this.areaId});

  Map<String, dynamic> toMap() => {'street_id': streetId, 'street_name': streetName, 'area_id': areaId};
  factory Street.fromMap(Map<String, dynamic> map) => Street(
    streetId: map['street_id'],
    streetName: map['street_name'],
    areaId: map['area_id'],
  );
}

class Father {
  final int? fatherId;
  final String fatherName;
  final String? fatherMobile;
  final String? birthDate;

  Father({this.fatherId, required this.fatherName, this.fatherMobile, this.birthDate});

  Map<String, dynamic> toMap() => {
    'father_id': fatherId,
    'father_name': fatherName,
    'father_mobile': fatherMobile,
    'birth_date': birthDate,
  };
  factory Father.fromMap(Map<String, dynamic> map) => Father(
    fatherId: map['father_id'],
    fatherName: map['father_name'],
    fatherMobile: map['father_mobile'],
    birthDate: map['birth_date'],
  );
}

class User {
  final int? passId;
  final String userName;
  final String passWord;

  User({this.passId, required this.userName, required this.passWord});

  Map<String, dynamic> toMap() => {'pass_id': passId, 'user_name': userName, 'pass_word': passWord};
  factory User.fromMap(Map<String, dynamic> map) => User(
    passId: map['pass_id'],
    userName: map['user_name'],
    passWord: map['pass_word'],
  );
}

class Permission {
  final int? interId;
  final int passId;
  final int? iconId;
  final String? iconName;
  final bool check1;

  Permission({this.interId, required this.passId, this.iconId, this.iconName, required this.check1});

  Map<String, dynamic> toMap() => {
    'inter_id': interId,
    'pass_id': passId,
    'icon_id': iconId,
    'icon_name': iconName,
    'check_1': check1 ? 1 : 0,
  };
  factory Permission.fromMap(Map<String, dynamic> map) => Permission(
    interId: map['inter_id'],
    passId: map['pass_id'],
    iconId: map['icon_id'],
    iconName: map['icon_name'],
    check1: map['check_1'] == 1,
  );
}
