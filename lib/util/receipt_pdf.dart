import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/maintenance_bill.dart';

/// Builds a PDF receipt for a single payment (one or more bills paid together)
/// and hands it to the OS share / save sheet.
///
/// The PDF uses "Rs." rather than the ₹ glyph — the default PDF font has no
/// rupee symbol and would otherwise render a blank box.
class BillReceipt {
  BillReceipt._();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(0)}';

  static String _date(DateTime? d) {
    if (d == null) return '-';
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  static String _dateTime(DateTime? d) {
    if (d == null) return '-';
    final l = d.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final ampm = l.hour >= 12 ? 'PM' : 'AM';
    final min = l.minute.toString().padLeft(2, '0');
    return '${_date(d)}, $h:$min $ampm';
  }

  /// Generates the receipt PDF bytes for the [bills] paid together.
  static Future<Uint8List> build({
    required List<MaintenanceBill> bills,
    required String flat,
    required String residentName,
    required String phone,
    String? societyName,
  }) async {
    final doc = pw.Document();
    final total = bills.fold<double>(0, (s, b) => s + b.amount);
    final paidAt = bills.first.paidAt;
    final stamp = (paidAt ?? DateTime.now()).millisecondsSinceEpoch.toString();
    final receiptNo = 'NST-${stamp.substring(stamp.length - 8)}';
    final accent = PdfColor.fromHex('#00695C');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header — society name + PAID badge.
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: accent, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        societyName ?? 'Nestora',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Payment Receipt',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#E8F5E9'),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'PAID',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#2E7D32'),
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            // Receipt meta.
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _kv('Receipt No.', receiptNo),
                _kv('Paid on', _dateTime(paidAt), alignRight: true),
              ],
            ),
            pw.SizedBox(height: 12),
            _kv('Billed to', residentName),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Expanded(child: _kv('Flat', flat)),
                pw.Expanded(child: _kv('Phone', phone.isEmpty ? '-' : phone)),
              ],
            ),
            pw.SizedBox(height: 20),
            // Line items.
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Type', bold: true),
                    _cell('Period', bold: true),
                    _cell('Amount', bold: true, alignRight: true),
                  ],
                ),
                ...bills.map(
                  (b) => pw.TableRow(
                    children: [
                      _cell(b.kindLabel),
                      _cell(b.period),
                      _cell(_money(b.amount), alignRight: true),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total paid:  ',
                  style: const pw.TextStyle(fontSize: 13),
                ),
                pw.Text(
                  _money(total),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'This is a system-generated receipt from Nestora. '
              'No signature required.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _kv(String k, String v, {bool alignRight = false}) {
    return pw.Column(
      crossAxisAlignment: alignRight
          ? pw.CrossAxisAlignment.end
          : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          k,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          v,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String t, {
    bool bold = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        t,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Builds the receipt and saves it straight to the device's Downloads folder
  /// (no share sheet). Returns the saved file path so the caller can offer to
  /// open it.
  static Future<String> download({
    required List<MaintenanceBill> bills,
    required String flat,
    required String residentName,
    required String phone,
    String? societyName,
  }) async {
    final bytes = await build(
      bills: bills,
      flat: flat,
      residentName: residentName,
      phone: phone,
      societyName: societyName,
    );
    final period = bills.first.period.replaceAll(' ', '-');
    return FileSaver.instance.saveFile(
      name: 'Receipt-$flat-$period',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
