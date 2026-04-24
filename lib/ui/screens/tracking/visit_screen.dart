import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/models/family_models.dart';
import '../../../data/services/pdf_service.dart';

class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  int? _selectedOsraId;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FamilyProvider>(context, listen: false).loadFamilies();
    });
  }

  void _addVisit() async {
    if (_selectedOsraId == null || _notesController.text.isEmpty) return;
    await Provider.of<TrackingProvider>(context, listen: false)
        .addVisit(_selectedOsraId!, _notesController.text);
    _notesController.clear();
  }

  void _printVisits() async {
    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
    if (trackingProvider.visits.isEmpty) return;

    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    final familyName = familyProvider.families.firstWhere((f) => f.osraId == _selectedOsraId).osraName;

    final headers = ['م', 'التاريخ', 'ملاحظات الزيارة'];
    final data = trackingProvider.visits.asMap().entries.map((e) {
      final visit = e.value;
      return [
        (e.key + 1).toString(),
        visit.date.split('T')[0],
        visit.notes ?? '---',
      ];
    }).toList();

    final pdfService = PdfService();
    await pdfService.generateTableReport(
      title: 'سجل زيارات وافتقاد أسرة: $familyName',
      headers: headers,
      data: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = Provider.of<FamilyProvider>(context);
    final trackingProvider = Provider.of<TrackingProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الافتقاد')),
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
                        Icon(Icons.transfer_within_a_station, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text('تسجيل زيارة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 550;
                        
                        final familyDropdown = DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: _selectedOsraId,
                          decoration: const InputDecoration(
                            labelText: 'اختر الأسرة',
                            prefixIcon: Icon(Icons.people),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: familyProvider.families.map((f) => DropdownMenuItem(value: f.osraId, child: Text(f.osraName))).toList(),
                          onChanged: (val) {
                            setState(() => _selectedOsraId = val);
                            if (val != null) trackingProvider.loadVisits(val);
                          },
                        );

                        final notesField = TextField(
                          controller: _notesController,
                          maxLines: 1,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات الزيارة',
                            prefixIcon: Icon(Icons.note),
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
                              onPressed: _selectedOsraId == null ? null : _addVisit,
                              icon: const Icon(Icons.add_task),
                              label: const Text('تسجيل زيارة'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: trackingProvider.visits.isEmpty ? null : _printVisits,
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
                              Expanded(flex: 2, child: familyDropdown),
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
                              familyDropdown,
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
                  : _selectedOsraId == null
                      ? const Center(child: Text('اختر أسرة لعرض سجل الزيارات'))
                      : ListView.builder(
                          itemCount: trackingProvider.visits.length,
                          itemBuilder: (context, index) {
                            final visit = trackingProvider.visits[index];
                            return ListTile(
                              leading: const Icon(Icons.calendar_month, color: Colors.amber),
                              title: Text(visit.date.split('T')[0]),
                              subtitle: Text(visit.notes ?? 'بدون ملاحظات'),
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
