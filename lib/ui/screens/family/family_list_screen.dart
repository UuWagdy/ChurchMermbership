import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/lookup_provider.dart';
import '../../../data/models/family_models.dart';

class FamilyListScreen extends StatefulWidget {
  const FamilyListScreen({super.key});

  @override
  State<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends State<FamilyListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FamilyProvider>(context, listen: false).loadFamilies();
      Provider.of<LookupProvider>(context, listen: false).loadAllLookups();
    });
  }

  void _onSearch() {
    Provider.of<FamilyProvider>(context, listen: false).loadFamilies(query: _searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = Provider.of<FamilyProvider>(context);
    final lookupProvider = Provider.of<LookupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأسر'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 28),
            onPressed: () => Navigator.of(context).pushNamed('/family-form'),
            tooltip: 'إضافة أسرة جديدة',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surface,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'بحث باسم الأسرة',
                hintText: 'اكتب اسم الأسرة أو رقم التليفون...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onSubmitted: (_) => _onSearch(),
            ),
          ),
          Expanded(
            child: familyProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : familyProvider.families.isEmpty
                    ? const Center(
                        child: Text(
                          'لا يوجد أسر مسجلة',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24, top: 8),
                        itemCount: familyProvider.families.length,
                        itemBuilder: (context, index) {
                          final family = familyProvider.families[index];
                          return _buildFamilyCard(context, family, lookupProvider, familyProvider);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context, Family family, LookupProvider lookup, FamilyProvider familyProvider) {
    final karabaName = lookup.getKarabaName(family.karabaId);
    final esName = lookup.getEconomicStatusName(family.eSId);
    final halaName = lookup.getHalaEgtimaiaName(family.halaEgtimaiaId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pushNamed('/family-form', arguments: family);
        },
        onLongPress: () => _confirmDelete(context, family, familyProvider),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Name + Icons
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    radius: 24,
                    child: Icon(Icons.family_restroom, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          family.osraName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.numbers, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'كود: ${family.code ?? 'غير مسجل'}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context, family, familyProvider),
                    tooltip: 'حذف الأسرة',
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Info Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.people, 'الأفراد: ${family.memberCount}', Colors.blue),
                  if (karabaName != '---') _buildInfoChip(Icons.diversity_3, karabaName, Colors.teal),
                  if (halaName != '---') _buildInfoChip(Icons.favorite, halaName, Colors.deepPurple),
                  if (esName != '---') _buildInfoChip(Icons.account_balance_wallet, esName, Colors.orange),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Contact & Address Row
              Row(
                children: [
                  if (family.phone != null && family.phone!.isNotEmpty) ...[
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(family.phone!, style: TextStyle(color: Colors.grey[800])),
                    const SizedBox(width: 16),
                  ],
                  if (family.rakmKomy != null && family.rakmKomy!.isNotEmpty) ...[
                    Icon(Icons.credit_card, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(family.rakmKomy!, style: TextStyle(color: Colors.grey[800])),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color.shade900, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Family family, FamilyProvider familyProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الأسرة'),
        content: Text('هل أنت متأكد من حذف أسرة ${family.osraName} وكل البيانات المتعلقة بها (أفراد، افتقادات، مساعدات، إلخ)؟\n\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              familyProvider.deleteFamily(family.osraId!);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
