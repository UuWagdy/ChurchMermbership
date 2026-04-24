import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/models/family_models.dart';
import '../../../data/services/pdf_service.dart';

class BirthdaysScreen extends StatefulWidget {
  const BirthdaysScreen({super.key});

  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen> {
  int _selectedMonth = DateTime.now().month;
  List<Person> _persons = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBirthdays();
  }

  Future<void> _loadBirthdays() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<FamilyProvider>(context, listen: false);
    final results = await provider.getBirthdays(_selectedMonth);
    setState(() {
      _persons = results;
      _isLoading = false;
    });
  }

  void _printResults() async {
    if (_persons.isEmpty) return;
    
    final pdfService = PdfService();
    final headers = ['م', 'الاسم', 'تاريخ الميلاد', 'السن المٌقدر'];
    final data = _persons.asMap().entries.map((e) {
      final person = e.value;
      return [
        (e.key + 1).toString(),
        person.personName,
        person.birthDate?.split('T')[0] ?? '---',
        person.age ?? '---',
      ];
    }).toList();

    await pdfService.generateTableReport(
      title: 'تقرير أعياد ميلاد شهر $_selectedMonth',
      headers: headers,
      data: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أعياد الميلاد')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('اختر الشهر:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(
                      width: 150,
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        isExpanded: true,
                        items: List.generate(12, (index) {
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text('شهر ${index + 1}'),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMonth = val);
                            _loadBirthdays();
                          }
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _persons.isEmpty ? null : _printResults,
                      icon: const Icon(Icons.print),
                      label: const Text('طباعة القائمة'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _persons.isEmpty
                      ? const Center(child: Text('لا يوجد أعياد ميلاد مسجلة في هذا الشهر'))
                      : ListView.builder(
                          itemCount: _persons.length,
                          itemBuilder: (context, index) {
                            final person = _persons[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: const Icon(Icons.cake, color: Colors.pink),
                                title: Text(person.personName),
                                subtitle: Text('تاريخ الميلاد: ${person.birthDate?.split('T')[0] ?? "غير محدد"}'),
                                trailing: Text('السن: ${person.age ?? "-"}'),
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
