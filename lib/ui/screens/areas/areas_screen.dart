import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../data/models/lookup_models.dart';

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final _areaController = TextEditingController();
  final _streetController = TextEditingController();
  int? _selectedArea;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  void _addArea() async {
    if (_areaController.text.isEmpty) return;
    await Provider.of<LookupProvider>(context, listen: false).addArea(_areaController.text);
    _areaController.clear();
  }

  void _addStreet() async {
    if (_selectedArea == null || _streetController.text.isEmpty) return;
    await Provider.of<LookupProvider>(context, listen: false).addStreet(_streetController.text, _selectedArea!);
    _streetController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lookup = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('المناطق والشوارع')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Management Panel
            Wrap(
              spacing: 16.0,
              runSpacing: 20.0,
              children: [
                SizedBox(
                  width: 350,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.add_location_alt, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              const Text('إضافة منطقة جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _areaController,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم المنطقة',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                                onPressed: _addArea,
                                tooltip: 'إضافة منطقة',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 350,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.add_road, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              const Text('إضافة شارع جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const Divider(height: 24),
                          DropdownButtonFormField<int>(
                            value: _selectedArea,
                            decoration: const InputDecoration(
                              labelText: 'اختر المنطقة',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: lookup.areas.map((a) => DropdownMenuItem(value: a.areaId, child: Text(a.areaName))).toList(),
                            onChanged: (val) {
                              setState(() => _selectedArea = val);
                              if (val != null) lookup.loadStreets(val);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _streetController,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم الشارع',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                                onPressed: _addStreet,
                                tooltip: 'إضافة شارع',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                const Text('قائمة المناطق والشوارع المسجلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            // Comprehensive List
            Expanded(
              child: ListView.builder(
                itemCount: lookup.areas.length,
                itemBuilder: (context, index) {
                  final area = lookup.areas[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ExpansionTile(
                      leading: CircleAvatar(backgroundColor: Colors.indigo.shade50, child: Icon(Icons.map, color: Colors.indigo.shade700)),
                      title: Text(area.areaName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: Colors.orange, size: 24),
                            onPressed: () => _showEditAreaDialog(area),
                            tooltip: 'تعديل المنطقة',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 24),
                            onPressed: () => _confirmDeleteArea(area),
                            tooltip: 'حذف المنطقة',
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      onExpansionChanged: (expanded) {
                        if (expanded) {
                          setState(() => _selectedArea = area.areaId);
                          lookup.loadStreets(area.areaId!);
                        }
                      },
                      children: [
                        Consumer<LookupProvider>(
                          builder: (context, lp, child) {
                            if (_selectedArea == area.areaId) {
                              if (lp.streets.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(16.0),
                                  width: double.infinity,
                                  color: Colors.grey.shade50,
                                  child: const Text('لا توجد شوارع مضافة لهذه المنطقة', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                );
                              }
                              return Container(
                                color: Colors.grey.shade50,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: lp.streets.length,
                                  separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey.shade300, indent: 32, endIndent: 32),
                                  itemBuilder: (context, sIdx) {
                                    final street = lp.streets[sIdx];
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 4),
                                      leading: const Icon(Icons.subdirectory_arrow_left, size: 16, color: Colors.grey),
                                      title: Text(street.streetName, style: const TextStyle(fontSize: 15)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                            onPressed: () => _showEditStreetDialog(street),
                                            tooltip: 'تعديل الشارع',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                            onPressed: () => _confirmDeleteStreet(street),
                                            tooltip: 'حذف الشارع',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
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

  void _showEditAreaDialog(Area area) {
    final controller = TextEditingController(text: area.areaName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل اسم المنطقة'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'الاسم الجديد')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await Provider.of<LookupProvider>(context, listen: false).updateArea(area.areaId!, controller.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteArea(Area area) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف منطقة'),
        content: Text('هل أنت متأكد من حذف منطقة "${area.areaName}"؟ سيتم حذف كافة الشوارع المرتبطة بها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              try {
                await Provider.of<LookupProvider>(context, listen: false).deleteArea(area.areaId!);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر حذف المنطقة لوجود بيانات مرتبطة بها (شوارع أو أسر)')),
                  );
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditStreetDialog(Street street) {
    final controller = TextEditingController(text: street.streetName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل اسم الشارع'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'الاسم الجديد')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await Provider.of<LookupProvider>(context, listen: false).updateStreet(street.streetId!, controller.text, street.areaId);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStreet(Street street) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف شارع'),
        content: Text('هل أنت متأكد من حذف شارع "${street.streetName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              try {
                await Provider.of<LookupProvider>(context, listen: false).deleteStreet(street.streetId!, street.areaId);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر حذف الشارع لوجود بيانات مرتبطة به (أسر)')),
                  );
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
