import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/family_provider.dart';
import '../../../data/services/pdf_service.dart';

class MainReportScreen extends StatefulWidget {
  const MainReportScreen({super.key});

  @override
  State<MainReportScreen> createState() => _MainReportScreenState();
}

class _MainReportScreenState extends State<MainReportScreen> {
  bool _isLoading = false;

  void _printReport() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<FamilyProvider>(context, listen: false);
    final reportData = await provider.getSummaryReport();
    
    if (reportData.isEmpty) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات للطباعة')));
      }
      return;
    }

    final headers = ['م', 'المنطقة', 'إجمالي الأسر', 'إجمالي الأفراد'];
    final data = reportData.asMap().entries.map((e) {
      final row = e.value;
      return [
        (e.key + 1).toString(),
        row['area_name']?.toString() ?? 'غير محدد',
        row['family_count']?.toString() ?? '0',
        row['person_count']?.toString() ?? '0',
      ];
    }).toList();

    final pdfService = PdfService();
    await pdfService.generateTableReport(
      title: 'إحصائيات الأسر والأفراد حسب المنطقة',
      headers: headers,
      data: data,
    );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير اخوة الرب')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'التقرير الإحصائي الشامل لاخوة الرب',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'يقوم هذا التقرير بحساب إجمالي عدد الأسر والأفراد\nفي كل منطقة وتصديرها كملف PDF للطباعة المباشرة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  onPressed: _printReport,
                  icon: const Icon(Icons.print),
                  label: const Text('استخراج وطباعة التقرير'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
