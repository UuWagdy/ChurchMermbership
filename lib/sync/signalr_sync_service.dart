import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'server_config.dart';

class SignalRSyncService {
  static final SignalRSyncService instance = SignalRSyncService._internal();
  SignalRSyncService._internal();

  static const String _recordSeparator = '\x1e';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _handshakeTimer;
  int _generation = 0;
  bool _isRunning = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;

  final _tablesChangedController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get onTablesChanged => _tablesChangedController.stream;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionStateChanged =>
      _connectionStateController.stream;

  bool get isConnected => _isConnected;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _reconnectAttempts = 0;
    _connect();
  }

  void stop() {
    _isRunning = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _disconnect();
    _setConnected(false);
  }

  void restart() {
    stop();
    start();
  }

  void _setConnected(bool value) {
    if (_isConnected != value) {
      _isConnected = value;
      _connectionStateController.add(value);
      if (kDebugMode) {
        debugPrint('[SignalR] Connection state changed: $_isConnected');
      }
    }
  }

  String _getWsUrl() {
    var base = ServerConfig.baseUrl.trim();
    if (base.startsWith('https://')) {
      base = 'wss://${base.substring(8)}';
    } else if (base.startsWith('http://')) {
      base = 'ws://${base.substring(7)}';
    } else {
      base = 'ws://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/hubs/sync';
  }

  Future<void> _connect() async {
    if (!_isRunning) return;

    _disconnect();
    final generation = _generation;
    bool current() => _isRunning && generation == _generation;

    try {
      final wsUrl = _getWsUrl();
      if (kDebugMode) {
        debugPrint('[SignalR] Connecting to: $wsUrl');
      }

      final uri = Uri.parse(wsUrl);
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 8));
      if (!current()) {
        await channel.sink.close();
        return;
      }
      _handshakeTimer = Timer(const Duration(seconds: 8), () {
        if (current() && !_isConnected) _onDisconnected();
      });

      // 1. Send SignalR Handshake
      _channel!.sink.add('{"protocol":"json","version":1}$_recordSeparator');

      bool handshakeDone = false;
      StringBuffer buffer = StringBuffer();

      _subscription = _channel!.stream.listen(
        (data) {
          if (!current()) return;
          buffer.write(data.toString());
          var str = buffer.toString();

          while (str.contains(_recordSeparator)) {
            final idx = str.indexOf(_recordSeparator);
            final message = str.substring(0, idx).trim();
            str = str.substring(idx + 1);
            buffer = StringBuffer(str);

            if (message.isEmpty) continue;

            if (!handshakeDone) {
              final handshake = jsonDecode(message);
              if (handshake is! Map || handshake.containsKey('error')) {
                _onDisconnected();
                return;
              }
              handshakeDone = true;
              _handshakeTimer?.cancel();
              _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
                if (current()) channel.sink.add('{"type":6}$_recordSeparator');
              });
              final wasDisconnected = !_isConnected;
              _setConnected(true);
              _reconnectAttempts = 0;
              if (wasDisconnected) {
                // بث إشعار شامل لتحديث جميع الشاشات عند استعادة الاتصال
                _tablesChangedController.add({'*'});
              }
              continue;
            }

            _handleSignalRMessage(message);
          }
        },
        onError: (err) {
          if (!current()) return;
          if (kDebugMode) {
            debugPrint('[SignalR] Error: $err');
          }
          _onDisconnected();
        },
        onDone: () {
          if (!current()) return;
          if (kDebugMode) {
            debugPrint('[SignalR] Connection closed');
          }
          _onDisconnected();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!current()) return;
      if (kDebugMode) {
        debugPrint('[SignalR] Connection exception: $e');
      }
      _onDisconnected();
    }
  }

  void _handleSignalRMessage(String message) {
    try {
      final json = jsonDecode(message);
      if (json is! Map) return;

      final type = json['type'] as int?;

      // Ping
      if (type == 6) {
        _channel?.sink.add('{"type":6}$_recordSeparator');
        return;
      }

      if (type == 7) {
        _onDisconnected();
        return;
      }

      // Invocation
      if (type == 1) {
        final target = json['target'] as String?;
        if (target == 'DatabaseChanged') {
          final arguments = json['arguments'] as List?;
          if (arguments != null && arguments.isNotEmpty) {
            final arg = arguments[0];
            if (arg is Map && arg['tables'] is List) {
              final rawTables = arg['tables'] as List;
              final tables = rawTables
                  .map((t) => t.toString().toLowerCase())
                  .toSet();
              if (tables.isNotEmpty) {
                _tablesChangedController.add(tables);
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SignalR] Error parsing message: $e');
      }
    }
  }

  void _onDisconnected() {
    _disconnect();
    _setConnected(false);
    if (!_isRunning) return;

    _reconnectAttempts++;
    final delaySeconds = switch (_reconnectAttempts) {
      1 => 2,
      2 => 4,
      3 => 8,
      _ => 15,
    };

    if (kDebugMode) {
      debugPrint(
        '[SignalR] Reconnecting in $delaySeconds seconds (attempt $_reconnectAttempts)...',
      );
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isRunning) _connect();
    });
  }

  void _disconnect() {
    _generation++;
    _pingTimer?.cancel();
    _pingTimer = null;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    try {
      _subscription?.cancel();
      _subscription = null;
      _channel?.sink.close();
      _channel = null;
    } catch (_) {}
  }
}

class SignalRSyncProvider extends ChangeNotifier {
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  StreamSubscription? _sub;

  SignalRSyncProvider() {
    _isConnected = SignalRSyncService.instance.isConnected;
    _sub = SignalRSyncService.instance.onConnectionStateChanged.listen((
      connected,
    ) {
      _isConnected = connected;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
