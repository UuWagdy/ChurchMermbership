import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/lookup_provider.dart';

class FathersScreen extends StatefulWidget {
  const FathersScreen({super.key});

  @override
  State<FathersScreen> createState() => _FathersScreenState();
}

class _FathersScreenState extends State<FathersScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  int? _editingFatherId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  void _onSave() async {
    if (_nameController.text.isEmpty) return;
    final lookup = Provider.of<LookupProvider>(context, listen: false);
    
    if (_editingFatherId != null) {
      await lookup.updateFather(_editingFatherId!, _nameController.text, _mobileController.text);
    } else {
      await lookup.addFather(_nameController.text, _mobileController.text, null);
    }

    _nameController.clear();
    _mobileController.clear();
    setState(() => _editingFatherId = null);
  }

  void _deleteFather(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف أب كاهن'),
        content: const Text('هل أنت متأكد من حذف هذا الأب الكاهن؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await Provider.of<LookupProvider>(context, listen: false).deleteFather(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الآباء الكهنة')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(_editingFatherId != null ? 'تعديل بيانات أب كاهن' : 'إضافة أب كاهن جديد', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم الأب الكاهن')),
                    TextField(controller: _mobileController, decoration: const InputDecoration(labelText: 'رقم الموبايل')),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _onSave,
                          icon: Icon(_editingFatherId != null ? Icons.edit : Icons.add),
                          label: Text(_editingFatherId != null ? 'تعديل' : 'إضافة'),
                        ),
                        if (_editingFatherId != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() {
                              _nameController.clear();
                              _mobileController.clear();
                              _editingFatherId = null;
                            }),
                            child: const Text('إلغاء'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: lookup.fathers.length,
                itemBuilder: (context, index) {
                  final father = lookup.fathers[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(father.fatherName),
                    subtitle: Text(father.fatherMobile ?? 'بدون رقم هاتف'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              _editingFatherId = father.fatherId;
                              _nameController.text = father.fatherName;
                              _mobileController.text = father.fatherMobile ?? '';
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteFather(father.fatherId!),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
