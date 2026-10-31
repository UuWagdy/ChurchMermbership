import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/automatic_backup_service.dart';

class BackupSettingsCard extends StatefulWidget {
  const BackupSettingsCard({super.key, required this.service});
  final AutomaticBackupService service;
  @override
  State<BackupSettingsCard> createState() => _BackupSettingsCardState();
}

class _BackupSettingsCardState extends State<BackupSettingsCard> {
  Map<String, dynamic>? _settings;
  String? _error;
  bool _busy = false;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) _load();
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await widget.service.load();
      if (mounted)
        setState(() {
          _settings = value;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _perform(Future<void> Function() work) async {
    setState(() => _busy = true);
    try {
      await work();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseDirectory() async {
    final service = widget.service;
    String? chosen;
    final host = Uri.tryParse(service.serverUrl())?.host;
    final onServer =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (!service.isServerMode() || onServer) {
      chosen = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد النسخ الاحتياطي',
      );
    } else {
      var entered = _settings!['directory'] as String? ?? '';
      chosen = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('مجلد النسخ على السيرفر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل مسارًا على جهاز السيرفر أو مجلد شبكة يستطيع حساب تشغيل السيرفر الكتابة فيه.',
              ),
              TextFormField(
                initialValue: entered,
                onChanged: (value) => entered = value,
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, entered.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    }
    if (chosen == null || chosen.isEmpty || !mounted) return;
    await _perform(
      () => service.configure({..._settings!, 'directory': chosen}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final server = widget.service.isServerMode();
    final last = DateTime.tryParse(
      settings?['lastSuccessUtc'] as String? ?? '',
    )?.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'النسخ الاحتياطي التلقائي — ${server ? 'PostgreSQL' : 'SQLite'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              server
                  ? 'نسخة يومية على جهاز السيرفر حتى عند إغلاق واجهة البرنامج.'
                  : 'نسخة يومية أثناء تشغيل البرنامج، وتعويض النسخة المستحقة عند فتحه.',
            ),
            const Text(
              'اختر هاردًا خارجيًا أو مجلد شبكة للحماية من تعطل الهارد الأساسي.',
            ),
            if (settings == null && _error == null)
              const LinearProgressIndicator(),
            if (settings != null) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تفعيل النسخ اليومي'),
                value: settings['enabled'] != false,
                onChanged: _busy
                    ? null
                    : (value) => _perform(
                        () => widget.service.configure({
                          ...settings,
                          'enabled': value,
                        }),
                      ),
              ),
              SelectableText('المجلد: ${settings['directory']}'),
              TextButton.icon(
                onPressed: _busy ? null : _chooseDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('اختيار مجلد الحفظ'),
              ),
              DropdownButtonFormField<int>(
                initialValue: settings['retention'] as int? ?? 30,
                decoration: const InputDecoration(
                  labelText: 'عدد النسخ التلقائية المحفوظة',
                ),
                items: {7, 14, 30, 60, 90, settings['retention'] as int? ?? 30}
                    .map(
                      (n) => DropdownMenuItem(value: n, child: Text('$n نسخة')),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null)
                          _perform(
                            () => widget.service.configure({
                              ...settings,
                              'retention': value,
                            }),
                          );
                      },
              ),
              const SizedBox(height: 10),
              Text(
                last == null
                    ? 'لم تُحفظ نسخة تلقائية بعد.'
                    : 'آخر نسخة ناجحة: $last',
              ),
              if (settings['lastPath'] != null)
                SelectableText('آخر ملف: ${settings['lastPath']}'),
              if (settings['lastError'] != null)
                Text(
                  'فشل آخر تشغيل: ${settings['lastError']}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _perform(() async {
                        final path = await widget.service.runNow();
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تم حفظ النسخة: $path')),
                          );
                      }),
                icon: const Icon(Icons.backup),
                label: const Text('إنشاء نسخة في المجلد المحدد الآن'),
              ),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
