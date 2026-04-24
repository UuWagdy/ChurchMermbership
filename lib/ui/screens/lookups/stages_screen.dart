import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/lookup_provider.dart';

class StagesScreen extends StatefulWidget {
  const StagesScreen({super.key});

  @override
  State<StagesScreen> createState() => _StagesScreenState();
}

class _StagesScreenState extends State<StagesScreen> {
  final _stageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  void _addStage() async {
    if (_stageController.text.isEmpty) return;
    await Provider.of<LookupProvider>(context, listen: false).addStage(_stageController.text);
    _stageController.clear();
  }

  void _deleteStage(int id) async {
    await Provider.of<LookupProvider>(context, listen: false).deleteStage(id);
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المراحل')),
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
                      const Text('إضافة مرحلة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _stageController,
                        decoration: const InputDecoration(labelText: 'اسم المرحلة', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addStage,
                        child: const Text('إضافة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: lookup.stages.length,
                itemBuilder: (context, index) {
                  final stage = lookup.stages[index];
                  return ListTile(
                    title: Text(stage['stage_name']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteStage(stage['stage_id']),
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
