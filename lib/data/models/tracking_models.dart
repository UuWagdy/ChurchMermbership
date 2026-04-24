class Confession {
  final int? eatrafId;
  final int personId;
  final String date;
  final String? notes;

  Confession({this.eatrafId, required this.personId, required this.date, this.notes});

  Map<String, dynamic> toMap() => {'eatraf_id': eatrafId, 'person_id': personId, 'date': date, 'notes': notes};
  factory Confession.fromMap(Map<String, dynamic> map) => Confession(
    eatrafId: map['eatraf_id'],
    personId: map['person_id'],
    date: map['date'],
    notes: map['notes'],
  );
}

class Visit {
  final int? visitId;
  final int osraId;
  final String date;
  final String? notes;

  Visit({this.visitId, required this.osraId, required this.date, this.notes});

  Map<String, dynamic> toMap() => {'visit_id': visitId, 'osra_id': osraId, 'date': date, 'notes': notes};
  factory Visit.fromMap(Map<String, dynamic> map) => Visit(
    visitId: map['visit_id'],
    osraId: map['osra_id'],
    date: map['date'],
    notes: map['notes'],
  );
}

class Occasion {
  final int? monasbaId;
  final int osraId;
  final String monasbaName;
  final String? monasbaDate;
  final String? month;

  Occasion({this.monasbaId, required this.osraId, required this.monasbaName, this.monasbaDate, this.month});

  Map<String, dynamic> toMap() => {
    'monasba_id': monasbaId,
    'osra_id': osraId,
    'monasba_name': monasbaName,
    'monasba_date': monasbaDate,
    'month': month,
  };
  factory Occasion.fromMap(Map<String, dynamic> map) => Occasion(
    monasbaId: map['monasba_id'],
    osraId: map['osra_id'],
    monasbaName: map['monasba_name'],
    monasbaDate: map['monasba_date'],
    month: map['month'],
  );
}

class FixedAid {
  final int? countId;
  final int osraId;
  final int? khdmaId;
  final double countValue;
  final String? aynee;
  final String? notes;

  FixedAid({this.countId, required this.osraId, this.khdmaId, this.countValue = 0.0, this.aynee, this.notes});

  Map<String, dynamic> toMap() => {
    'count_id': countId,
    'osra_id': osraId,
    'khdma_id': khdmaId,
    'count_value': countValue,
    'aynee': aynee,
    'notes': notes,
  };
  factory FixedAid.fromMap(Map<String, dynamic> map) => FixedAid(
    countId: map['count_id'],
    osraId: map['osra_id'],
    khdmaId: map['khdma_id'],
    countValue: (map['count_value'] as num?)?.toDouble() ?? 0.0,
    aynee: map['aynee'],
    notes: map['notes'],
  );
}

class VariableAid {
  final int? count2Id;
  final int osraId;
  final String? type;
  final double countAdd;
  final String? notes;
  final String? date1;

  VariableAid({this.count2Id, required this.osraId, this.type, this.countAdd = 0.0, this.notes, this.date1});

  Map<String, dynamic> toMap() => {
    'count_2_id': count2Id,
    'osra_id': osraId,
    'type': type,
    'count_add': countAdd,
    'notes': notes,
    'date_1': date1,
  };
  factory VariableAid.fromMap(Map<String, dynamic> map) => VariableAid(
    count2Id: map['count_2_id'],
    osraId: map['osra_id'],
    type: map['type'],
    countAdd: (map['count_add'] as num?)?.toDouble() ?? 0.0,
    notes: map['notes'],
    date1: map['date_1'],
  );
}

class Expense {
  final int? masrofatId;
  final int osraId;
  final String? masrof;
  final double countValue;
  final String? aynee;
  final String? notes;

  Expense({this.masrofatId, required this.osraId, this.masrof, this.countValue = 0.0, this.aynee, this.notes});

  Map<String, dynamic> toMap() => {
    'masrofat_id': masrofatId,
    'osra_id': osraId,
    'masrof': masrof,
    'count_value': countValue,
    'aynee': aynee,
    'notes': notes,
  };
  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    masrofatId: map['masrofat_id'],
    osraId: map['osra_id'],
    masrof: map['masrof'],
    countValue: (map['count_value'] as num?)?.toDouble() ?? 0.0,
    aynee: map['aynee'],
    notes: map['notes'],
  );
}
