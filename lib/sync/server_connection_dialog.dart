import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../data/services/backup_service.dart';
import '../providers/auth_provider.dart';
import '../providers/family_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/lookup_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tracking_provider.dart';
import 'server_config.dart';
import 'server_connection_service.dart';
import 'signalr_sync_service.dart';

class ServerConnectionStatusButton extends StatelessWidget {
  final bool compact;
  final bool darkBackground;

  const ServerConnectionStatusButton({
    super.key,
    this.compact = false,
    this.darkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ServerConfigProvider, SignalRSyncProvider>(
      builder: (context, serverConfig, signalR, _) {
        final isServer = serverConfig.isServerMode;
        final isConnected = signalR.isConnected;

        Color dotColor;
        String statusLabel;
        String tooltipText;

        if (!isServer) {
          dotColor = const Color(0xFF60A5FA); // Blue
          statusLabel = 'محلي (SQLite)';
          tooltipText =
              'وضع التشغيل: قاعدة بيانات محلية (SQLite) — اضغط لإعدادات الاتصال بالسيرفر';
        } else if (isConnected) {
          dotColor = const Color(0xFF10B981); // Emerald Green
          statusLabel = 'متصل بالسيرفر (SignalR)';
          tooltipText =
              'متصل بسيرفر .NET + PostgreSQL والمزامنة الفورية نشطة (${serverConfig.baseUrl})';
        } else {
          dotColor = const Color(0xFFF59E0B); // Amber
          statusLabel = 'جارٍ الاتصال بالسيرفر...';
          tooltipText =
              'وضع السيرفر مفعل لكن جارٍ الاتصال بالسيرفر (${serverConfig.baseUrl})';
        }

        final fgColor = darkBackground ? Colors.white : const Color(0xFF1A237E);

        if (compact) {
          return Tooltip(
            message: tooltipText,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => ServerConnectionDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: darkBackground
                      ? Colors.white.withAlpha(25)
                      : const Color(0xFF1A237E).withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dotColor.withAlpha(140), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withAlpha(128),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isServer ? Icons.dns_rounded : Icons.storage_rounded,
                      size: 14,
                      color: fgColor.withAlpha(230),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: fgColor.withAlpha(240),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.settings_ethernet_rounded,
                      size: 13,
                      color: fgColor.withAlpha(200),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Tooltip(
          message: tooltipText,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => ServerConnectionDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: darkBackground
                      ? const Color(0xFF0F172A).withAlpha(180)
                      : const Color(0xFF1A237E).withAlpha(25),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: darkBackground
                        ? Colors.white.withAlpha(60)
                        : const Color(0xFF1A237E).withAlpha(50),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withAlpha(140),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.settings_ethernet_rounded,
                      size: 17,
                      color: fgColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'إعدادات الاتصال والسيرفر ($statusLabel)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ServerConnectionDialog extends StatefulWidget {
  const ServerConnectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ServerConnectionDialog(),
    );
  }

  @override
  State<ServerConnectionDialog> createState() => _ServerConnectionDialogState();
}

class _ServerConnectionDialogState extends State<ServerConnectionDialog> {
  late bool _isServerMode;
  late TextEditingController _urlController;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _isUploadingDb = false;
  ServerConnectionCheckResult? _healthResult;
  Map<String, String> _discoveredUrls = {};

  @override
  void initState() {
    super.initState();
    _isServerMode = ServerConfig.isServerMode;
    _urlController = TextEditingController(text: ServerConfig.baseUrl);
    _loadDiscoveredServerInfo();
  }

  Future<void> _loadDiscoveredServerInfo() async {
    final info = await _readServerInfoFile();
    if (mounted && info.isNotEmpty) {
      setState(() => _discoveredUrls = info);
    }
  }

  static Future<Map<String, String>> _readServerInfoFile() async {
    final result = <String, String>{};
    if (kIsWeb) return result;
    try {
      if (Platform.isWindows) {
        final appDataDir = p.join(
          Platform.environment['LOCALAPPDATA'] ?? '',
          'AbonaFlemoon_ServerData',
          'SERVER_INFO.txt',
        );
        final progDataDir = p.join(
          Platform.environment['ProgramData'] ?? r'C:\ProgramData',
          'AbonaFlemoon',
          'SERVER_INFO.txt',
        );
        final exeDir = p.join(
          File(Platform.resolvedExecutable).parent.path,
          'SERVER_INFO.txt',
        );
        final candidates = [appDataDir, progDataDir, exeDir, 'SERVER_INFO.txt'];

        for (final path in candidates) {
          final file = File(path);
          if (await file.exists()) {
            final lines = await file.readAsLines();
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.startsWith('LAN_URL=')) {
                final val = trimmed.substring('LAN_URL='.length).trim();
                if (val.isNotEmpty && !val.contains('127.0.0.1')) {
                  result['LAN_URL'] = val;
                }
              } else if (trimmed.startsWith('Recommended LAN URL') ||
                  trimmed.startsWith('Recommended LAN address')) {
                final parts = trimmed.split(': ');
                if (parts.length >= 2) {
                  final val = parts[1].trim();
                  if (val.isNotEmpty && !val.contains('127.0.0.1')) {
                    result['LAN_URL'] = val;
                  }
                }
              } else if (trimmed.startsWith('http://192.168.') ||
                  trimmed.startsWith('http://10.') ||
                  trimmed.startsWith('http://172.')) {
                result.putIfAbsent('LAN_URL', () => trimmed);
              }
            }
            if (result.isNotEmpty) break;
          }
        }
      }

      if (!result.containsKey('LAN_URL')) {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('169.254.')) {
              result['LAN_URL'] = 'http://${addr.address}:5060';
              break;
            }
          }
          if (result.containsKey('LAN_URL')) break;
        }
      }
    } catch (_) {}
    return result;
  }

  void _refreshAllProviders() {
    if (!mounted) return;
    try {
      context.read<LookupProvider>().refreshSilently();
      context.read<FamilyProvider>().refreshSilently();
      context.read<TrackingProvider>().refreshSilently();
      context.read<FinancialProvider>().refreshSilently();
      context.read<AuthProvider>().refreshSilently();
      context.read<SettingsProvider>().refreshSilently();
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _healthResult = null;
    });

    final res = await ServerConnectionService.checkConnection(
      _urlController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _healthResult = res;
      });
    }
  }

  Future<void> _saveAndConnect() async {
    setState(() => _isSaving = true);
    final provider = context.read<ServerConfigProvider>();
    final url = _urlController.text.trim();

    try {
      final success = await provider.applySettings(
        enabled: _isServerMode,
        url: url.isEmpty ? 'http://127.0.0.1:5060' : url,
      );

      if (mounted) {
        if (success) {
          context.read<AuthProvider>().logout();
          _refreshAllProviders();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isServerMode
                    ? 'تم الاتصال بسيرفر .NET + PostgreSQL وتفعيل المزامنة الفورية (SignalR) بنجاح!'
                    : 'تم التبديل إلى قاعدة البيانات المحلية (SQLite) بنجاح.',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.lastError ?? 'فشل الاتصال بالسيرفر المحدد',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadLocalDbToPostgres() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفع قاعدة البيانات المحلية إلى PostgreSQL'),
          content: const Text(
            'سيتم رفع جميع البيانات الموجودة في ملف SQLite المحلي على هذا الجهاز إلى قاعدة بيانات PostgreSQL على السيرفر ومزامنتها فوراً مع جميع الأجهزة المتصلة.\n\nهل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، ارفع البيانات الآن'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploadingDb = true);
    try {
      final dbPath = await BackupService().getDatabasePath();
      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        throw Exception('ملف قاعدة البيانات المحلي غير موجود');
      }

      final fileBytes = await sourceFile.readAsBytes();
      final targetUrl =
          '${ServerConfig.normalizeUrl(_urlController.text)}/api/storage/sqlite/import';

      final response = await HttpClient().postUrl(Uri.parse(targetUrl)).then((
        req,
      ) {
        req.headers.set('Content-Type', 'application/octet-stream');
        req.add(fileBytes);
        return req.close();
      });

      if (response.statusCode != 200) {
        throw Exception(
          'فشل استيراد قاعدة البيانات إلى السيرفر: HTTP ${response.statusCode}',
        );
      }

      if (mounted) {
        _refreshAllProviders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم رفع البيانات المحلية إلى PostgreSQL بنجاح وإشعار جميع الأجهزة عبر SignalR!',
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفع البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingDb = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalR = context.watch<SignalRSyncProvider>();
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.settings_ethernet_rounded,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إعدادات الاتصال والسيرفر والمزامنة',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Flutter > Dart Logic > .NET 8 > PostgreSQL > SignalR',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 26),

                // Mode Selection Cards
                Text(
                  'وضع تشغيل قاعدة البيانات:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textPrimary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeOption(
                        selected: _isServerMode,
                        icon: Icons.dns_rounded,
                        title: 'سيرفر مركزي (.NET + PostgreSQL)',
                        subtitle:
                            'مزامنة فورية لحظية بين جميع الأجهزة عبر SignalR',
                        onTap: () => setState(() => _isServerMode = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModeOption(
                        selected: !_isServerMode,
                        icon: Icons.storage_rounded,
                        title: 'قاعدة بيانات محلية (SQLite)',
                        subtitle: 'تشغيل منفرد على هذا الجهاز فقط بدون سيرفر',
                        onTap: () => setState(() => _isServerMode = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Server URL Input
                Text(
                  'عنوان السيرفر (Server URL):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: _isServerMode ? textPrimary : textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _urlController,
                    enabled: _isServerMode,
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.100:5060',
                      prefixIcon: const Icon(Icons.link_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'استعادة العنوان الافتراضي',
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        onPressed: _isServerMode
                            ? () => setState(
                                () => _urlController.text =
                                    'http://127.0.0.1:5060',
                              )
                            : null,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // Quick Fill Discovered URLs
                if (_isServerMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.computer, size: 15),
                        label: const Text(
                          'نفس الجهاز (127.0.0.1:5060)',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        onPressed: () {
                          setState(
                            () => _urlController.text = 'http://127.0.0.1:5060',
                          );
                        },
                      ),
                      if (_discoveredUrls['LAN_URL'] != null)
                        ActionChip(
                          avatar: const Icon(Icons.lan_outlined, size: 15),
                          label: Text(
                            'الشبكة المحلية (${_discoveredUrls['LAN_URL']})',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () {
                            setState(
                              () => _urlController.text =
                                  _discoveredUrls['LAN_URL']!,
                            );
                          },
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Test Connection & Live SignalR Status Row
                if (_isServerMode) ...[
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.network_check_rounded, size: 18),
                        label: const Text('اختبار الاتصال بالسيرفر'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSignalRStatusBadge(signalR.isConnected),
                      ),
                    ],
                  ),
                ],

                // Health Test Result Banner
                if (_healthResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _healthResult!.isReachable
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _healthResult!.isReachable
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _healthResult!.isReachable
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _healthResult!.isReachable
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _healthResult!.message,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _healthResult!.isReachable
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Upload Local SQLite to PostgreSQL Card
                if (_isServerMode) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.blueGrey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1A237E),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'نقل البيانات المحلية إلى السيرفر (PostgreSQL)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'رفع بيانات SQLite الحالية على هذا الجهاز إلى قاعدة بيانات PostgreSQL',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _isUploadingDb
                              ? null
                              : _uploadLocalDbToPostgres,
                          icon: _isUploadingDb
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_rounded, size: 17),
                          label: const Text('رفع الآن'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveAndConnect,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        _isServerMode
                            ? 'حفظ واتصال بالسيرفر الآن'
                            : 'حفظ والتشغيل محلياً',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

    final unselectedBg = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;
    final unselectedBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withAlpha(isDark ? 50 : 20) : unselectedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primaryColor : unselectedBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? primaryColor : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                ),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 18,
                  color: selected ? primaryColor : (isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: selected ? primaryColor : textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalRStatusBadge(bool isConnected) {
    final Color color = isConnected
        ? const Color(0xFF10B981)
        : Colors.grey.shade600;
    final String text = isConnected
        ? 'SignalR: متصل (مزامنة فورية)'
        : 'SignalR: غير متصل حالياً';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
