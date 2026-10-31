import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'server_config.dart';

class CaseInsensitiveRowMap extends MapBase<String, dynamic> {
  final Map<String, dynamic> _inner = {};
  final Map<String, String> _lowercaseKeyMap = {};

  CaseInsensitiveRowMap(Map<String, dynamic> source) {
    source.forEach((k, v) {
      _inner[k] = v;
      _lowercaseKeyMap[k.toLowerCase()] = k;
    });
  }

  @override
  dynamic operator [](Object? key) {
    if (key is! String) return null;
    if (_inner.containsKey(key)) return _inner[key];
    final actualKey = _lowercaseKeyMap[key.toLowerCase()];
    return actualKey != null ? _inner[actualKey] : null;
  }

  @override
  void operator []=(String key, dynamic value) {
    final existingKey = _lowercaseKeyMap[key.toLowerCase()];
    if (existingKey != null && existingKey != key) {
      _inner.remove(existingKey);
    }
    _inner[key] = value;
    _lowercaseKeyMap[key.toLowerCase()] = key;
  }

  @override
  void clear() {
    _inner.clear();
    _lowercaseKeyMap.clear();
  }

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  dynamic remove(Object? key) {
    if (key is! String) return null;
    final actualKey = _lowercaseKeyMap.remove(key.toLowerCase());
    if (actualKey != null) {
      return _inner.remove(actualKey);
    }
    return null;
  }
}

abstract class _BasePostgresExecutor implements DatabaseExecutor {
  final http.Client _client;
  final String Function() _baseUrlProvider;
  final String? _txId;

  static const Map<String, String> _singleIdPrimaryKeys = {
    'areas': 'area_id',
    'streets': 'street_id',
    'karaba': 'karaba_id',
    'mostwa': 'mostwa_id',
    'hala_egtimaia': 'hala_egtimaia_id',
    'hala_sehia': 'hala_sehia_id',
    'e_s': 'e_s_id',
    'stage': 'stage_id',
    'fathers': 'father_id',
    'khdma': 'khdma_id',
    'users': 'pass_id',
    'icon': 'icon_id',
    'inter_icon': 'inter_id',
    'osra': 'osra_id',
    'person': 'person_id',
    'eatraf': 'eatraf_id',
    'visits': 'visit_id',
    'monasba': 'monasba_id',
    'count_aid': 'count_id',
    'count_2': 'count_2_id',
    'masrofat': 'masrofat_id',
  };

  _BasePostgresExecutor(this._client, this._baseUrlProvider, this._txId);

  Uri _endpoint(String path) => Uri.parse('${_baseUrlProvider()}$path');

  static List<Map<String, dynamic>> encodeParams(List<Object?>? args) {
    if (args == null || args.isEmpty) return const [];
    return args.map((arg) {
      if (arg == null) {
        return {'type': 'null', 'value': null};
      } else if (arg is int) {
        return {'type': 'int', 'value': arg};
      } else if (arg is double) {
        return {'type': 'double', 'value': arg};
      } else if (arg is num) {
        return {'type': 'double', 'value': arg.toDouble()};
      } else if (arg is bool) {
        return {'type': 'bool', 'value': arg};
      } else if (arg is Uint8List) {
        return {'type': 'bytes', 'value': base64Encode(arg)};
      } else if (arg is List<int>) {
        return {'type': 'bytes', 'value': base64Encode(Uint8List.fromList(arg))};
      } else if (arg is DateTime) {
        return {'type': 'string', 'value': arg.toIso8601String()};
      } else {
        return {'type': 'string', 'value': arg.toString()};
      }
    }).toList();
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _endpoint(path),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['error'] != null) {
          errMsg = decoded['error'].toString();
        }
      } catch (_) {
        errMsg = utf8.decode(response.bodyBytes);
      }
      throw Exception('خطأ في اتصال السيرفر ($path): $errMsg');
    }

    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    if (sql.trim().toUpperCase().startsWith('PRAGMA')) return;
    await _postJson('/api/storage/execute', {
      'sql': sql,
      'params': encodeParams(arguments),
      if (_txId != null) 'txId': _txId,
    });
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final res = await _postJson('/api/storage/insert', {
      'sql': sql,
      'params': encodeParams(arguments),
      if (_txId != null) 'txId': _txId,
    });
    return (res['lastInsertRowId'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final cleaned = Map<String, Object?>.from(values);
    final pk = _singleIdPrimaryKeys[table.toLowerCase()];
    if (pk != null) {
      cleaned.removeWhere((k, v) => k.toLowerCase() == pk && v == null);
    }

    String prefix = 'INSERT INTO';
    if (conflictAlgorithm == ConflictAlgorithm.ignore) {
      prefix = 'INSERT OR IGNORE INTO';
    } else if (conflictAlgorithm == ConflictAlgorithm.replace) {
      prefix = 'INSERT OR REPLACE INTO';
    }

    final cols = cleaned.keys.toList();
    final args = cols.map((k) => cleaned[k]).toList();
    final colsSql = cols.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    final sql = '$prefix "$table" ($colsSql) VALUES ($placeholders)';

    return rawInsert(sql, args);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final sb = StringBuffer('SELECT ');
    if (distinct == true) sb.write('DISTINCT ');
    if (columns != null && columns.isNotEmpty) {
      sb.write(columns.join(', '));
    } else {
      sb.write('*');
    }
    sb.write(' FROM "$table"');
    if (where != null && where.trim().isNotEmpty) {
      sb.write(' WHERE $where');
    }
    if (groupBy != null && groupBy.trim().isNotEmpty) {
      sb.write(' GROUP BY $groupBy');
    }
    if (having != null && having.trim().isNotEmpty) {
      sb.write(' HAVING $having');
    }
    if (orderBy != null && orderBy.trim().isNotEmpty) {
      sb.write(' ORDER BY $orderBy');
    }
    if (limit != null) {
      sb.write(' LIMIT $limit');
    }
    if (offset != null) {
      sb.write(' OFFSET $offset');
    }

    return rawQuery(sb.toString(), whereArgs);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (sql.trim().toUpperCase().startsWith('PRAGMA')) return <Map<String, Object?>>[];
    final res = await _postJson('/api/storage/query', {
      'sql': sql,
      'params': encodeParams(arguments),
      if (_txId != null) 'txId': _txId,
    });
    final rawRows = (res['rows'] as List<dynamic>? ?? const []);
    return rawRows
        .map<Map<String, Object?>>(
          (r) => CaseInsensitiveRowMap(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    throw UnimplementedError('rawQueryCursor is not used in this project.');
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) {
    throw UnimplementedError('queryCursor is not used in this project.');
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final res = await _postJson('/api/storage/execute', {
      'sql': sql,
      'params': encodeParams(arguments),
      if (_txId != null) 'txId': _txId,
    });
    return (res['affectedRows'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final cols = values.keys.toList();
    final setClause = cols.map((c) => '"$c" = ?').join(', ');
    final args = <Object?>[
      ...cols.map((c) => values[c]),
      if (whereArgs != null) ...whereArgs,
    ];
    final sql = 'UPDATE "$table" SET $setClause${where != null && where.trim().isNotEmpty ? ' WHERE $where' : ''}';
    return rawUpdate(sql, args);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    return rawUpdate(sql, arguments);
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final sql = 'DELETE FROM "$table"${where != null && where.trim().isNotEmpty ? ' WHERE $where' : ''}';
    return rawDelete(sql, whereArgs);
  }

  @override
  Batch batch() => _DotNetPostgresBatch(this);
}

class _DotNetPostgresTransaction extends _BasePostgresExecutor implements Transaction {
  final DotNetPostgresDatabase _parentDb;

  _DotNetPostgresTransaction(this._parentDb, String txId)
      : super(_parentDb._client, _parentDb._baseUrlProvider, txId);

  @override
  Database get database => _parentDb;
}

class _DotNetPostgresBatch implements Batch {
  final _BasePostgresExecutor _executor;
  final List<Map<String, dynamic>> _statements = [];

  _DotNetPostgresBatch(this._executor);

  @override
  int get length => _statements.length;

  @override
  Future<List<Object?>> commit({bool? exclusive, bool? noResult, bool? continueOnError}) async {
    if (_statements.isEmpty) return const [];
    final res = await _executor._postJson('/api/storage/batch', {
      'statements': _statements,
      if (_executor._txId != null) 'txId': _executor._txId,
    });
    _statements.clear();
    if (noResult == true) return const [];
    return [(res['affectedRows'] as num?)?.toInt() ?? 0];
  }

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) =>
      commit(noResult: noResult, continueOnError: continueOnError);

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _statements.add({
      'sql': sql,
      'params': _BasePostgresExecutor.encodeParams(arguments),
    });
  }

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final cleaned = Map<String, Object?>.from(values);
    final pk = _BasePostgresExecutor._singleIdPrimaryKeys[table.toLowerCase()];
    if (pk != null) {
      cleaned.removeWhere((k, v) => k.toLowerCase() == pk && v == null);
    }
    String prefix = 'INSERT INTO';
    if (conflictAlgorithm == ConflictAlgorithm.ignore) {
      prefix = 'INSERT OR IGNORE INTO';
    } else if (conflictAlgorithm == ConflictAlgorithm.replace) {
      prefix = 'INSERT OR REPLACE INTO';
    }
    final cols = cleaned.keys.toList();
    final args = cols.map((k) => cleaned[k]).toList();
    final colsSql = cols.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    rawInsert('$prefix "$table" ($colsSql) VALUES ($placeholders)', args);
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _statements.add({
      'sql': sql,
      'params': _BasePostgresExecutor.encodeParams(arguments),
    });
  }

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final cols = values.keys.toList();
    final setClause = cols.map((c) => '"$c" = ?').join(', ');
    final args = <Object?>[
      ...cols.map((c) => values[c]),
      if (whereArgs != null) ...whereArgs,
    ];
    final sql = 'UPDATE "$table" SET $setClause${where != null && where.trim().isNotEmpty ? ' WHERE $where' : ''}';
    rawUpdate(sql, args);
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) => rawUpdate(sql, arguments);

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    final sql = 'DELETE FROM "$table"${where != null && where.trim().isNotEmpty ? ' WHERE $where' : ''}';
    rawDelete(sql, whereArgs);
  }

  @override
  void execute(String sql, [List<Object?>? arguments]) => rawUpdate(sql, arguments);

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {}

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {}
}

class DotNetPostgresDatabase extends _BasePostgresExecutor implements Database {
  bool _isOpen = true;

  DotNetPostgresDatabase({
    http.Client? client,
    String Function()? baseUrlProvider,
  }) : super(
          client ?? http.Client(),
          baseUrlProvider ?? (() => ServerConfig.baseUrl),
          null,
        );

  static List<Map<String, dynamic>> encodeParams(List<Object?>? args) =>
      _BasePostgresExecutor.encodeParams(args);

  @override
  Database get database => this;

  @override
  String get path => _baseUrlProvider();

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final beginRes = await _postJson('/api/storage/tx/begin', const {});
    final txId = beginRes['txId'] as String;
    final txn = _DotNetPostgresTransaction(this, txId);
    try {
      final result = await action(txn);
      await _postJson('/api/storage/tx/commit', {'txId': txId});
      return result;
    } catch (e) {
      try {
        await _postJson('/api/storage/tx/rollback', {'txId': txId});
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) =>
      transaction(action);

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) =>
      throw UnimplementedError();

  @override
  Future<T> devInvokeSqlMethod<T>(String method, String sql, [List<Object?>? arguments]) =>
      throw UnimplementedError();
}
