import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../models/family_models.dart';
import '../models/tracking_models.dart';

class PdfService {
  Future<void> generateFamilyReport(Family family, List<Person> members, double totalAids, double totalExpenses) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('تقرير شامل للأسرة - اخوة الرب', style: pw.TextStyle(font: fontBold, fontSize: 24)),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Text('بيانات الأسرة:', style: pw.TextStyle(font: fontBold, fontSize: 18)),
                pw.SizedBox(height: 10),
                pw.Text('اسم الأسرة: ${family.osraName}', style: pw.TextStyle(font: font)),
                pw.Text('الكود: ${family.code ?? '---'}', style: pw.TextStyle(font: font)),
                pw.Text('رقم التليفون: ${family.phone ?? '---'}', style: pw.TextStyle(font: font)),
                pw.Text('العنوان: ${family.dalilName ?? '---'}', style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 20),
                pw.Text('أفراد الأسرة:', style: pw.TextStyle(font: fontBold, fontSize: 18)),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    <String>['الاسم', 'القرابة', 'السن', 'المرحلة'],
                    ...members.map((p) => [p.personName, '---', p.age ?? '---', '---'])
                  ],
                  cellStyle: pw.TextStyle(font: font),
                  headerStyle: pw.TextStyle(font: fontBold),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('إجمالي المساعدات: $totalAids ج.م', style: pw.TextStyle(font: fontBold)),
                    pw.Text('إجمالي المصروفات: $totalExpenses ج.م', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> generateTableReport({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Center(
                child: pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 24)),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              data: <List<String>>[
                headers,
                ...data,
              ],
              cellStyle: pw.TextStyle(font: font),
              headerStyle: pw.TextStyle(font: fontBold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.center,
              headerAlignment: pw.Alignment.center,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> generateDetailedSearchReport({
    required String title,
    required List<Map<String, dynamic>> familiesData, 
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          final pages = <pw.Widget>[
            pw.Header(
              level: 0,
              child: pw.Center(
                child: pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 24)),
              ),
            ),
            pw.SizedBox(height: 20),
          ];

          for (final fData in familiesData) {
            final family = fData['family'] as Family;
            final areaName = fData['areaName'] as String;
            final address = fData['address'] as String;
            final membersDetails = fData['members'] as List<List<String>>;
            final fixedAidsDetails = fData['fixedAids'] as List<List<String>>?;
            final variableAidsDetails = fData['variableAids'] as List<List<String>>?;
            final expensesDetails = fData['expenses'] as List<List<String>>?;
            
            pages.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Wrap(
                      spacing: 20,
                      runSpacing: 5,
                      children: [
                        pw.Text('اسم الأسرة (الرب): ${family.osraName}', style: pw.TextStyle(font: fontBold)),
                        pw.Text('الكود: ${family.code ?? '---'}', style: pw.TextStyle(font: font)),
                        pw.Text('التليفون: ${family.phone ?? '---'}', style: pw.TextStyle(font: font)),
                        pw.Text('المنطقة: $areaName', style: pw.TextStyle(font: font)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('العنوان بالتفصيل: $address', style: pw.TextStyle(font: font)),
                    pw.SizedBox(height: 10),
                    pw.Text('أفراد الأسرة:', style: pw.TextStyle(font: fontBold)),
                    pw.SizedBox(height: 5),
                    if (membersDetails.isEmpty)
                      pw.Text('لا يوجد أفراد مسجلين', style: pw.TextStyle(font: font, color: PdfColors.grey600))
                    else
                      pw.TableHelper.fromTextArray(
                        context: context,
                        data: <List<String>>[
                          ['الاسم', 'القرابة', 'السن', 'المرحلة', 'الوظيفة', 'الموبايل'],
                          ...membersDetails,
                        ],
                        cellStyle: pw.TextStyle(font: font, fontSize: 10),
                        headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        cellAlignment: pw.Alignment.center,
                        headerAlignment: pw.Alignment.center,
                      ),
                    
                    if (fixedAidsDetails != null && fixedAidsDetails.isNotEmpty) ...[
                      pw.SizedBox(height: 15),
                      pw.Text('المساعدات الثابتة:', style: pw.TextStyle(font: fontBold, color: PdfColors.indigo700)),
                      pw.SizedBox(height: 5),
                      pw.TableHelper.fromTextArray(
                        context: context,
                        data: <List<String>>[
                          ['نوع الخدمة', 'المبلغ', 'عيني', 'الملاحظات'],
                          ...fixedAidsDetails,
                        ],
                        cellStyle: pw.TextStyle(font: font, fontSize: 9),
                        headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                        cellAlignment: pw.Alignment.center,
                        headerAlignment: pw.Alignment.center,
                      ),
                    ],

                    if (variableAidsDetails != null && variableAidsDetails.isNotEmpty) ...[
                      pw.SizedBox(height: 15),
                      pw.Text('المساعدات المتغيرة:', style: pw.TextStyle(font: fontBold, color: PdfColors.teal700)),
                      pw.SizedBox(height: 5),
                      pw.TableHelper.fromTextArray(
                        context: context,
                        data: <List<String>>[
                          ['النوع', 'المبلغ', 'التاريخ', 'الملاحظات'],
                          ...variableAidsDetails,
                        ],
                        cellStyle: pw.TextStyle(font: font, fontSize: 9),
                        headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
                        cellAlignment: pw.Alignment.center,
                        headerAlignment: pw.Alignment.center,
                      ),
                    ],

                    if (expensesDetails != null && expensesDetails.isNotEmpty) ...[
                      pw.SizedBox(height: 15),
                      pw.Text('سجل المصروفات:', style: pw.TextStyle(font: fontBold, color: PdfColors.red700)),
                      pw.SizedBox(height: 5),
                      pw.TableHelper.fromTextArray(
                        context: context,
                        data: <List<String>>[
                          ['البند', 'المبلغ', 'عيني', 'ملاحظات'],
                          ...expensesDetails,
                        ],
                        cellStyle: pw.TextStyle(font: font, fontSize: 9),
                        headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.red50),
                        cellAlignment: pw.Alignment.center,
                        headerAlignment: pw.Alignment.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return pages;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
