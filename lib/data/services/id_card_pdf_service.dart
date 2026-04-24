import 'dart:convert';
import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../models/family_models.dart';
import '../../providers/lookup_provider.dart';
import '../../providers/settings_provider.dart';

/// Configuration for which fields to show on the ID card
class IdCardConfig {
  final bool showName;
  final bool showNationalId;
  final bool showMobile;
  final bool showJob;
  final bool showStage;
  final bool showBirthDate;
  final String barcodeType; // 'qr' or '1d'
  final int cardsPerRow;
  final int cardsPerCol;

  // Back card config
  final bool printBack;
  final String backTopText;
  final String backBottomText;
  final String? backLogoBase64;

  const IdCardConfig({
    this.showName = true,
    this.showNationalId = true,
    this.showMobile = true,
    this.showJob = true,
    this.showStage = true,
    this.showBirthDate = false,
    this.barcodeType = 'qr',
    this.cardsPerRow = 2,
    this.cardsPerCol = 4,
    this.printBack = false,
    this.backTopText = '',
    this.backBottomText = '',
    this.backLogoBase64,
  });

  int get cardsPerPage => cardsPerRow * cardsPerCol;
}

class IdCardPdfService {
  // Page margins and spacing constants (in points, 1mm ≈ 2.835pt)
  static const double _pageMargin = 20; // ~7mm margin around the page
  static const double _cardGapH = 10;   // Horizontal gap between cards
  static const double _cardGapV = 10;   // Vertical gap between cards

  // Premium color palette
  static const _primaryColor = PdfColors.indigo900;
  static const _accentColor = PdfColors.indigo50;
  static const _headerBg = PdfColor.fromInt(0xFF1A237E); // Deep Indigo
  static const _goldAccent = PdfColor.fromInt(0xFFD4AF37); // Gold

  /// Helper to fix Arabic text clipping: adds a trailing space
  static String _fixArabic(String text) {
    if (text.isEmpty) return text;
    return '$text ';
  }

  static Future<void> generateAndPrint(
    List<Person> persons,
    LookupProvider lookupProvider,
    SettingsProvider settingsProvider,
    IdCardConfig config,
  ) async {
    final pdf = pw.Document();

    // Load Cairo fonts locally
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    // Load Logo
    final String? base64Logo = await settingsProvider.getSetting('id_card_logo');
    pw.MemoryImage? logoImage;
    if (base64Logo != null && base64Logo.isNotEmpty) {
      logoImage = pw.MemoryImage(base64Decode(base64Logo));
    }

    // Load Back Logo
    pw.MemoryImage? backLogoImage;
    if (config.backLogoBase64 != null && config.backLogoBase64!.isNotEmpty) {
      backLogoImage = pw.MemoryImage(base64Decode(config.backLogoBase64!));
    }

    // Calculate card dimensions to fill A4 properly
    // A4 = 595.28 x 841.89 points
    final double usableWidth = PdfPageFormat.a4.width - (_pageMargin * 2);
    final double usableHeight = PdfPageFormat.a4.height - (_pageMargin * 2);

    final double totalHGaps = _cardGapH * (config.cardsPerRow - 1);
    final double totalVGaps = _cardGapV * (config.cardsPerCol - 1);

    final double cardWidth = (usableWidth - totalHGaps) / config.cardsPerRow;
    final double cardHeight = (usableHeight - totalVGaps) / config.cardsPerCol;

    final int cardsPerPage = config.cardsPerPage;

    for (int i = 0; i < persons.length; i += cardsPerPage) {
      final pagePersons = persons.skip(i).take(cardsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: pw.EdgeInsets.all(_pageMargin),
          build: (pw.Context context) {
            // Build rows of cards manually for precise sizing
            final List<pw.Widget> rows = [];
            for (int row = 0; row < config.cardsPerCol; row++) {
              final List<pw.Widget> rowCards = [];
              for (int col = 0; col < config.cardsPerRow; col++) {
                final idx = row * config.cardsPerRow + col;
                if (idx < pagePersons.length) {
                  rowCards.add(
                    pw.SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _buildCard(pagePersons[idx], lookupProvider, font, fontBold, logoImage, config, cardWidth),
                    ),
                  );
                } else {
                  rowCards.add(pw.SizedBox(width: cardWidth, height: cardHeight));
                }
                if (col < config.cardsPerRow - 1) {
                  rowCards.add(pw.SizedBox(width: _cardGapH));
                }
              }
              rows.add(pw.Row(children: rowCards));
              if (row < config.cardsPerCol - 1) {
                rows.add(pw.SizedBox(height: _cardGapV));
              }
            }
            return pw.Column(children: rows);
          },
        ),
      );

      if (config.printBack) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            textDirection: pw.TextDirection.rtl,
            margin: pw.EdgeInsets.all(_pageMargin),
            build: (pw.Context context) {
              final List<pw.Widget> rows = [];
              for (int row = 0; row < config.cardsPerCol; row++) {
                final List<pw.Widget> rowCards = [];
                for (int col = 0; col < config.cardsPerRow; col++) {
                  final idx = row * config.cardsPerRow + col;
                  if (idx < pagePersons.length) {
                    rowCards.add(
                      pw.SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: _buildBackCard(pagePersons[idx], font, fontBold, backLogoImage, config),
                      ),
                    );
                  } else {
                    rowCards.add(pw.SizedBox(width: cardWidth, height: cardHeight));
                  }
                  if (col < config.cardsPerRow - 1) {
                    rowCards.add(pw.SizedBox(width: _cardGapH));
                  }
                }
                
                // Reverse row for correct duplex mirroring
                rows.add(pw.Row(children: rowCards.reversed.toList()));
                
                if (row < config.cardsPerCol - 1) {
                  rows.add(pw.SizedBox(height: _cardGapV));
                }
              }
              return pw.Column(children: rows);
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كارنيهات_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static pw.Widget _buildCard(
    Person person,
    LookupProvider lookupProvider,
    pw.Font font,
    pw.Font fontBold,
    pw.MemoryImage? logoImage,
    IdCardConfig config,
    double cardWidth,
  ) {
    // Dynamically calculate font sizes based on card height
    final double labelSize = 10;
    final double valueSize = 10;
    final double headerSize = 9;

    // Build the info rows
    final rows = <pw.Widget>[];

    if (config.showName) {
      rows.add(_buildInfoRow('الاسم', person.personName, font, fontBold, labelSize, valueSize));
    }
    if (config.showStage) {
      rows.add(_buildInfoRow('المرحلة', lookupProvider.getStageName(person.stageId), font, fontBold, labelSize, valueSize));
    }
    if (config.showJob && person.wazefa != null && person.wazefa!.isNotEmpty) {
      rows.add(_buildInfoRow('الوظيفة', person.wazefa!, font, fontBold, labelSize, valueSize));
    }
    if (config.showNationalId) {
      rows.add(_buildInfoRow('رقم قومي', person.rakmKomy ?? '---', font, fontBold, labelSize, valueSize));
    }
    if (config.showMobile && person.mobile != null && person.mobile!.isNotEmpty) {
      rows.add(_buildInfoRow('موبايل', person.mobile!, font, fontBold, labelSize, valueSize));
    }
    if (config.showBirthDate) {
      rows.add(_buildInfoRow('الميلاد', person.birthDate ?? '---', font, fontBold, labelSize, valueSize));
    }

    // Barcode data = person ID or code
    final barcodeData = 'ID:${person.personId ?? 0}';

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _primaryColor, width: 1.5),
        color: PdfColors.white,
      ),
      child: pw.Column(
        children: [
          // ═══════ Header Bar ═══════
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: const pw.BoxDecoration(
              color: _headerBg,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  _fixArabic('كارنيه العضوية'),
                  style: pw.TextStyle(font: fontBold, fontSize: headerSize + 1, color: PdfColors.white),
                ),
                pw.SizedBox(width: 4),
                pw.Container(width: 20, height: 1, color: _goldAccent),
                pw.SizedBox(width: 4),
                pw.Text(
                  'Membership Card',
                  style: pw.TextStyle(font: font, fontSize: headerSize - 1, color: _goldAccent),
                ),
              ],
            ),
          ),

          // ═══════ Body ═══════
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Logo on the right (RTL)
                    if (logoImage != null)
                      pw.Container(
                        width: cardWidth * 0.18,
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ],
                        ),
                      ),
                    if (logoImage != null) 
                      pw.Container(
                        width: 1,
                        margin: const pw.EdgeInsets.symmetric(horizontal: 6),
                        color: _goldAccent,
                      ),
                    // Details on the left
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: rows,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ═══════ Footer with Barcode ═══════
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const pw.BoxDecoration(
              color: _accentColor,
              borderRadius: pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(7),
                bottomRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  barcode: config.barcodeType == '1d' ? Barcode.code128() : Barcode.qrCode(),
                  data: barcodeData,
                  width: config.barcodeType == '1d' ? 60 : 28,
                  height: config.barcodeType == '1d' ? 18 : 28,
                  color: _primaryColor,
                  drawText: false, // We will manually draw the ID below it using our styled text
                ),
                pw.SizedBox(width: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      _fixArabic('كود: ${person.personId ?? "---"}'),
                      style: pw.TextStyle(font: fontBold, fontSize: 8, color: _primaryColor),
                    ),
                    pw.Container(width: 40, height: 0.5, color: _goldAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold,
    double labelSize,
    double valueSize,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: pw.BoxDecoration(
              color: _accentColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              _fixArabic(label),
              style: pw.TextStyle(font: fontBold, fontSize: labelSize, color: _primaryColor),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              _fixArabic(value),
              style: pw.TextStyle(font: font, fontSize: valueSize),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBackCard(
    Person person,
    pw.Font font,
    pw.Font fontBold,
    pw.MemoryImage? backLogoImage,
    IdCardConfig config,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _primaryColor, width: 1.5),
        color: PdfColors.white,
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            _fixArabic(config.backTopText),
            style: pw.TextStyle(font: fontBold, fontSize: 15, color: _primaryColor),
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Expanded(
            child: pw.Center(
              child: backLogoImage != null
                  ? pw.Image(backLogoImage, fit: pw.BoxFit.contain, height: 75)
                  : pw.SizedBox(),
            ),
          ),
          pw.Text(
            _fixArabic(config.backBottomText),
            style: pw.TextStyle(font: font, fontSize: 13, color: _primaryColor),
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
