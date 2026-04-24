import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';

class IdCardSettingsDialog extends StatefulWidget {
  const IdCardSettingsDialog({super.key});

  @override
  IdCardSettingsDialogState createState() => IdCardSettingsDialogState();
}

class IdCardSettingsDialogState extends State<IdCardSettingsDialog> {
  String? _base64Logo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final logo = await settings.getSetting('id_card_logo');
    if (mounted) {
      setState(() {
        _base64Logo = logo;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        List<int> imageBytes = await file.readAsBytes();
        String base64Image = base64Encode(imageBytes);

        setState(() {
          _base64Logo = base64Image;
        });

        if (mounted) {
          final settings = Provider.of<SettingsProvider>(context, listen: false);
          await settings.saveSetting('id_card_logo', _base64Logo!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ اللوجو بنجاح')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء اختيار اللوجو')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعدادات الكارنيه', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر لوجو الكنيسة ليتم طباعته على الكارنيهات', textAlign: TextAlign.center,),
              const SizedBox(height: 16),
              Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: _base64Logo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(_base64Logo!),
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.image, size: 50, color: Colors.grey),
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('تغيير اللوجو'),
                onPressed: _pickLogo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_base64Logo != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    setState(() { _base64Logo = null; });
                    final settings = Provider.of<SettingsProvider>(context, listen: false);
                    await settings.deleteSetting('id_card_logo');
                  }, 
                  icon: const Icon(Icons.delete, color: Colors.red), 
                  label: const Text('حذف اللوجو', style: TextStyle(color: Colors.red)),
                )
              ]
            ],
          ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}
