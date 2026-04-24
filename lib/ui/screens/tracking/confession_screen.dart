import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/models/family_models.dart';
import '../../../data/services/pdf_service.dart';

class ConfessionScreen extends StatefulWidget {
  const ConfessionScreen({super.key});

  @override
  State<ConfessionScreen> createState() => _ConfessionScreenState();
}

class _ConfessionScreenState extends State<ConfessionScreen> {
  int? _selectedPersonId;
  final _notesController = TextEditingController();
  List<Person> _allPersons = [];

  @override
  void initState() {
    super.initState();
    _loadAllPersons();
  }

  Future<void> _loadAllPersons() async {
    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    await familyProvider.loadFamilies();
    List<Person> all = [];
    for (var family in familyProvider.families) {
      final p = await familyProvider.getPersons(family.osraId!);
      all.addAll(p);
    }
    setState(() => _allPersons = all);
  }

  void _addConfession() async {
    if (_selectedPersonId == null || _notesController.text.isEmpty) return;
    await Provider.of<TrackingProvider>(context, listen: false)
        .addConfession(_selectedPersonId!, _notesController.text);
    _notesController.clear();
  }

  void _printConfessions() async {
    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
    if (trackingProvider.confessions.isEmpty) return;

    final personName = _allPersons.firstWhere((p) => p.personId == _selectedPersonId).personName;

    final headers = ['م', 'التاريخ', 'ملاحظات الاعتراف'];
    final data = trackingProvider.confessions.asMap().entries.map((e) {
      final conf = e.value;
      return [
        (e.key + 1).toString(),
        conf.date.split('T')[0],
        conf.notes ?? '---',
      ];
    }).toList();

    final pdfService = PdfService();
    await pdfService.generateTableReport(
      title: 'سجل اعترافات: $personName',
      headers: headers,
      data: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingProvider = Provider.of<TrackingProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الاعتراف')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                 child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.church, color: Colors.deepPurple.shade700),
                        const SizedBox(width: 8),
                        const Text('تسجيل اعتراف جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 550;
                        
                        final searchField = Autocomplete<Person>(
                          displayStringForOption: (p) => p.personName,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') return const Iterable<Person>.empty();
                            return _allPersons.where((p) => p.personName.contains(textEditingValue.text));
                          },
                          onSelected: (p) {
                            setState(() => _selectedPersonId = p.personId);
                            trackingProvider.loadConfessions(p.personId!);
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'ابحث عن الشخص بالاسم',
                                prefixIcon: Icon(Icons.person_search),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            );
                          },
                        );

                        final notesField = TextField(
                          controller: _notesController,
                          maxLines: 1,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات الاعتراف',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        );

                        final actions = Wrap(
                          spacing: 12.0,
                          runSpacing: 12.0,
                          alignment: WrapAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _selectedPersonId == null ? null : _addConfession,
                              icon: const Icon(Icons.add_task),
                              label: const Text('تسجيل اعتراف'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                backgroundColor: Colors.deepPurple.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: trackingProvider.confessions.isEmpty ? null : _printConfessions,
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('طباعة السجل'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        );

                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: searchField),
                              const SizedBox(width: 12),
                              Expanded(flex: 3, child: notesField),
                              const SizedBox(width: 12),
                              actions,
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              searchField,
                              const SizedBox(height: 12),
                              notesField,
                              const SizedBox(height: 12),
                              actions,
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: trackingProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedPersonId == null
                      ? const Center(child: Text('ابحث عن شخص لعرض سجل الاعترافات'))
                      : ListView.builder(
                          itemCount: trackingProvider.confessions.length,
                          itemBuilder: (context, index) {
                            final confession = trackingProvider.confessions[index];
                            return ListTile(
                              leading: const Icon(Icons.church, color: Colors.deepPurple),
                              title: Text(confession.date.split('T')[0]),
                              subtitle: Text(confession.notes ?? 'بدون ملاحظات'),
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
