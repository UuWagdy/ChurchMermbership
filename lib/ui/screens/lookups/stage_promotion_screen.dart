import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/models/family_models.dart';

class StagesPromotionScreen extends StatefulWidget {
  const StagesPromotionScreen({super.key});

  @override
  State<StagesPromotionScreen> createState() => _StagesPromotionScreenState();
}

class _StagesPromotionScreenState extends State<StagesPromotionScreen> {
  int? _fromStageId;
  int? _toStageId;
  List<Person> _persons = [];
  final Set<int> _selectedPersonIds = {};
  bool _isLoading = false;

  // Predefined promotion sequence map based on stage names
  final Map<String, String> _sequenceMap = {
    'تمهيدى': 'KG1',
    'KG1': 'KG2',
    'KG2': 'أولى إبتدائى',
    'أولى إبتدائى': 'ثانية ب',
    'ثانية ب': 'ثالثة ب',
    'ثالثة ب': 'رابعة ب',
    'رابعة ب': 'خامسة ب',
    'خامسة ب': 'سادسة ب',
    'سادسة ب': 'اولى ع',
    'اولى ع': 'ثانية ع',
    'ثانية ع': 'ثالثة ع',
    'ثالثة ع': 'اولي ث',
    'اولي ث': 'ثانية ث',
    'ثانية ث': 'ثالثة ث',
    'ثالثة ث': 'اولي ج',
    'اولي ج': 'ثانية ج',
    'ثانية ج': 'ثالثة ج',
    'ثالثة ج': 'رابعة ج',
    'رابعة ج': 'خامسة ج',
    'خامسة ج': 'سادسة ج',
    'سادسة ج': 'خريج',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  // Load persons in the selected "From Stage"
  Future<void> _loadPersons() async {
    if (_fromStageId == null) return;
    setState(() => _isLoading = true);
    try {
      final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
      final list = await familyProvider.getPersonsByStage(_fromStageId!);
      setState(() {
        _persons = list;
        _selectedPersonIds.clear();
        _selectedPersonIds.addAll(list.map((p) => p.personId!));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء تحميل الأفراد: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Auto suggest to-stage based on from-stage selection
  void _onFromStageChanged(int? stageId, LookupProvider lookup) {
    if (stageId == null) return;
    setState(() {
      _fromStageId = stageId;
      _persons = [];
      _selectedPersonIds.clear();
    });
    
    // Find name of the selected from-stage
    final fromStage = lookup.stages.firstWhere((s) => s['stage_id'] == stageId, orElse: () => {});
    final fromName = fromStage['stage_name'] as String?;

    if (fromName != null && _sequenceMap.containsKey(fromName)) {
      final nextName = _sequenceMap[fromName];
      final toStage = lookup.stages.firstWhere(
        (s) => (s['stage_name'] as String).toLowerCase().trim() == nextName!.toLowerCase().trim(),
        orElse: () => {},
      );
      if (toStage.isNotEmpty) {
        setState(() => _toStageId = toStage['stage_id'] as int);
      } else {
        setState(() => _toStageId = null);
      }
    } else {
      setState(() => _toStageId = null);
    }

    _loadPersons();
  }

  void _promote() async {
    if (_fromStageId == null || _toStageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك اختر المرحلة الحالية والمرحلة الجديدة')),
      );
      return;
    }
    if (_selectedPersonIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك حدد فرداً واحداً على الأقل للترحيل')),
      );
      return;
    }

    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      await familyProvider.promotePersonsStage(_selectedPersonIds.toList(), _toStageId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم ترحيل الأفراد بنجاح إلى المرحلة الجديدة')),
      );
      await _loadPersons();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الترحيل: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ترحيل المراحل التعليمية')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // From Stage Dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _fromStageId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المرحلة الحالية (ترحيل من)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: lookup.stages.map((s) => DropdownMenuItem(value: s['stage_id'] as int, child: Text(s['stage_name'] as String))).toList(),
                        onChanged: (val) => _onFromStageChanged(val, lookup),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.arrow_back, color: Colors.blueGrey), // RTL Arrow
                    const SizedBox(width: 16),
                    // To Stage Dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _toStageId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المرحلة الجديدة (ترحيل إلى)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: lookup.stages.map((s) => DropdownMenuItem(value: s['stage_id'] as int, child: Text(s['stage_name'] as String))).toList(),
                        onChanged: (val) => setState(() => _toStageId = val),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Selection Controls
            if (_persons.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _selectedPersonIds.length == _persons.length,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedPersonIds.clear();
                              _selectedPersonIds.addAll(_persons.map((p) => p.personId!));
                            } else {
                              _selectedPersonIds.clear();
                            }
                          });
                        },
                      ),
                      const Text('تحديد الكل', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('تم تحديد ${_selectedPersonIds.length} من أصل ${_persons.length} فرد'),
                ],
              ),
            // Members List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _fromStageId == null
                      ? const Center(child: Text('اختر المرحلة الحالية لعرض أفرادها'))
                      : _persons.isEmpty
                          ? const Center(child: Text('لا توجد أسماء مسجلة في هذه المرحلة حالياً'))
                          : ListView.builder(
                              itemCount: _persons.length,
                              itemBuilder: (ctx, index) {
                                final person = _persons[index];
                                final isChecked = _selectedPersonIds.contains(person.personId);

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: CheckboxListTile(
                                    title: Text(person.personName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'الموبايل: ${person.mobile ?? "بدون موبايل"} | الرقم القومي: ${person.rakmKomy ?? "بدون رقم قومي"}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    value: isChecked,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPersonIds.add(person.personId!);
                                        } else {
                                          _selectedPersonIds.remove(person.personId!);
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 12),
            // Promote Button
            if (_persons.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _promote,
                icon: const Icon(Icons.upgrade),
                label: const Text('ترحيل الأفراد المحددين', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
