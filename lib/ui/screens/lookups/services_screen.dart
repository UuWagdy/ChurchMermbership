import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/lookup_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _serviceController = TextEditingController();
  int? _editingServiceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  void _onSave() async {
    if (_serviceController.text.isEmpty) return;
    final lookup = Provider.of<LookupProvider>(context, listen: false);
    
    if (_editingServiceId != null) {
      await lookup.updateService(_editingServiceId!, _serviceController.text);
    } else {
      await lookup.addService(_serviceController.text);
    }
    
    setState(() {
      _serviceController.clear();
      _editingServiceId = null;
    });
  }

  void _deleteService(int id) async {
    await Provider.of<LookupProvider>(context, listen: false).deleteService(id);
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الخدمات')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final widgets = [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('إضافة خدمة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _serviceController,
                        decoration: const InputDecoration(labelText: 'اسم الخدمة', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _onSave,
                        child: Text(_editingServiceId != null ? 'تعديل' : 'إضافة'),
                      ),
                      if (_editingServiceId != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _serviceController.clear();
                            _editingServiceId = null;
                          }),
                          child: const Text('إلغاء'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: lookup.services.length,
                itemBuilder: (context, index) {
                  final service = lookup.services[index];
                  return ListTile(
                    title: Text(service['khdma_name']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              _serviceController.text = service['khdma_name'];
                              _editingServiceId = service['khdma_id'];
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteService(service['khdma_id']),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ];

          if (isMobile) {
            return Column(children: [
              widgets[0],
              widgets[1],
            ]);
          } else {
            return Row(
              children: [
                SizedBox(width: 350, child: widgets[0]),
                widgets[1],
              ],
            );
          }
        },
      ),
    );
  }
}
