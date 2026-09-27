import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generator PDF laporan — padanan web/src/financePdf.js (jsPDF):
/// banner gelap "JURAGAN SEBLAK", judul ember di kanan, blok heading
/// berlatar cream, item menjorok, total menonjol, minus merah.
class PdfRow {
  final String label;
  final Object? value; // num atau String
  final bool strong;
  final bool negative;
  final bool sub;

  const PdfRow(this.label,
      {this.value, this.strong = false, this.negative = false, this.sub = false});
}

class PdfBlock {
  final String? heading;
  final List<PdfRow> rows;
  final bool rule;

  const PdfBlock({this.heading, this.rows = const [], this.rule = false});
}

String _fmtRp(num n) => 'Rp ${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';

String _val(Object? value, bool negative) {
  if (value is num) {
    final prefix = negative && value > 0 ? '- ' : '';
    return prefix + _fmtRp(value.abs());
  }
  return '$value';
}

String _ddmmyyyy(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

pw.Widget _banner(String title, String from, String to) {
  return pw.Container(
    color: const PdfColor.fromInt(0x16110F),
    padding: const pw.EdgeInsets.symmetric(
        horizontal: 14 * PdfPageFormat.mm, vertical: 5 * PdfPageFormat.mm),
    height: 24 * PdfPageFormat.mm,
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('JURAGAN SEBLAK',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFAF3EC))),
            pw.SizedBox(height: 2),
            pw.Text('Laporan Keuangan',
                style: pw.TextStyle(
                    fontSize: 8, color: const PdfColor.fromInt(0xFAF3EC))),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xF97316))),
            pw.SizedBox(height: 2),
            pw.Text(
                'Periode: ${_ddmmyyyy(from)} s/d ${_ddmmyyyy(to)}',
                style: pw.TextStyle(
                    fontSize: 8, color: const PdfColor.fromInt(0xFAF3EC))),
          ],
        ),
      ],
    ),
  );
}

List<pw.Widget> _blockWidgets(PdfBlock block) {
  final widgets = <pw.Widget>[];
  if (block.heading != null) {
    widgets.add(pw.Container(
      width: double.infinity,
      color: const PdfColor.fromInt(0xFAF3EC),
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 2 * PdfPageFormat.mm, vertical: 1.5 * PdfPageFormat.mm),
      child: pw.Text(block.heading!,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0x16110F))),
    ));
    widgets.add(pw.SizedBox(height: 1.5 * PdfPageFormat.mm));
  }
  for (final row in block.rows) {
    widgets.add(pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2 * PdfPageFormat.mm),
      child: pw.Row(children: [
        pw.Padding(
          padding: pw.EdgeInsets.only(left: row.sub ? 6 * PdfPageFormat.mm : 0),
          child: pw.Text(row.label,
              style: pw.TextStyle(
                  fontSize: row.strong ? 10 : 9,
                  fontWeight: row.strong
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: row.negative
                      ? const PdfColor.fromInt(0xC81E0F)
                      : const PdfColor.fromInt(0x16110F))),
        ),
        pw.Spacer(),
        pw.Text(_val(row.value, row.negative),
            style: pw.TextStyle(
                fontSize: row.strong ? 10 : 9,
                fontWeight: row.strong
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: row.negative
                    ? const PdfColor.fromInt(0xC81E0F)
                    : const PdfColor.fromInt(0x16110F))),
      ]),
    ));
  }
  if (block.rule) {
    widgets.add(pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 1 * PdfPageFormat.mm),
      decoration: pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColor.fromInt(0xE1E1E1), width: 0.5))),
    ));
  }
  widgets.add(pw.SizedBox(height: 1.5 * PdfPageFormat.mm));
  return widgets;
}

/// Buat & buka sheet share (bisa disimpan ke Files/Drive/WA) — padanan
/// tombol "Unduh PDF" web.
Future<void> shareReportPdf({
  required String title,
  required String from,
  required String to,
  required List<PdfBlock> blocks,
  required String filename,
}) async {
  final doc = pw.Document(title: title, creator: 'Juragan Seblak ERP');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    header: (_) => _banner(title, from, to),
    build: (_) => [
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(14 * PdfPageFormat.mm,
            10 * PdfPageFormat.mm, 14 * PdfPageFormat.mm, 0),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [for (final b in blocks) ..._blockWidgets(b)],
        ),
      ),
    ],
    footer: (ctx) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6 * PdfPageFormat.mm),
      child: pw.Center(
        child: pw.Text(_footerText(ctx.pageNumber, ctx.pagesCount),
            style: const pw.TextStyle(
                fontSize: 7, color: PdfColor.fromInt(0x969696))),
      ),
    ),
  ));
  await Printing.sharePdf(bytes: await doc.save(), filename: filename);
}

String _footerText(int page, int total) {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${now.day}/${now.month}/${now.year}, ${two(now.hour)}.${two(now.minute)}.${two(now.second)}';
  return 'Dicetak $stamp - Halaman $page/$total';
}

/// Slip gaji PDF — padanan downloadSlip() di web/src/pages/admin/Gaji.jsx.
/// Param: payment_id, employee, from, to, daily_rate, days, gaji, kasbon, total.
Future<void> shareSlipGajiPdf(Map<String, dynamic> p) async {
  num n(String k) => num.tryParse('${p[k]}') ?? 0;
  final doc = pw.Document(title: 'Slip Gaji', creator: 'Juragan Seblak ERP');
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${now.day}/${now.month}/${now.year}, ${two(now.hour)}.${two(now.minute)}.${two(now.second)}';

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Kop
        pw.Container(
          color: const PdfColor.fromInt(0x16110F),
          height: 26 * PdfPageFormat.mm,
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 14 * PdfPageFormat.mm, vertical: 5 * PdfPageFormat.mm),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('JURAGAN SEBLAK',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFAF3EC))),
                    pw.SizedBox(height: 2),
                    pw.Text('Slip Pembayaran Gaji Karyawan',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: const PdfColor.fromInt(0xFAF3EC))),
                  ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                        'No. #${('${p['payment_id']}').padLeft(5, '0')}',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xF97316))),
                    pw.SizedBox(height: 2),
                    pw.Text(stamp,
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: const PdfColor.fromInt(0xFAF3EC))),
                  ]),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 14 * PdfPageFormat.mm, vertical: 10 * PdfPageFormat.mm),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('BUKTI PEMBAYARAN GAJI',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0x16110F))),
              ),
              pw.SizedBox(height: 8 * PdfPageFormat.mm),
              _info('Nama Karyawan', '${p['employee']}'),
              _info('Periode', '${p['from']} s/d ${p['to']}'),
              _info('Tarif Harian', _fmtRp(n('daily_rate'))),
              _info('Hari Hadir', '${p['days']} hari'),
              pw.SizedBox(height: 4 * PdfPageFormat.mm),
              pw.Container(
                  decoration: pw.BoxDecoration(
                      border: pw.Border(
                          top: pw.BorderSide(
                              color: PdfColor.fromInt(0xC8C8C8),
                              width: 0.5)))),
              _row('Gaji (${p['days']} hari x ${_fmtRp(n('daily_rate'))})',
                  _fmtRp(n('gaji'))),
              _row('Potongan Kasbon',
                  n('kasbon') > 0 ? '- ${_fmtRp(n('kasbon'))}' : '-'),
              pw.Container(
                  decoration: pw.BoxDecoration(
                      border: pw.Border(
                          top: pw.BorderSide(
                              color: PdfColor.fromInt(0xC8C8C8),
                              width: 0.5)))),
              pw.SizedBox(height: 5 * PdfPageFormat.mm),
              pw.Container(
                color: const PdfColor.fromInt(0x16110F),
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4 * PdfPageFormat.mm,
                    vertical: 3.5 * PdfPageFormat.mm),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL DIBAYARKAN',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFAF3EC))),
                    pw.Text(_fmtRp(n('total')),
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFAF3EC))),
                  ],
                ),
              ),
              pw.SizedBox(height: 8 * PdfPageFormat.mm),
              pw.Text(
                'Pembayaran tercatat sebagai pengeluaran kategori "gaji" di modul Keuangan. Dokumen ini sah tanpa tanda tangan basah.',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColor.fromInt(0x16110F)),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Text('Diterima oleh,',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColor.fromInt(0x16110F))),
                    pw.SizedBox(height: 22 * PdfPageFormat.mm),
                    pw.Container(
                        width: 50 * PdfPageFormat.mm,
                        decoration: pw.BoxDecoration(
                            border: pw.Border(
                                top: pw.BorderSide(
                                    color: PdfColor.fromInt(0x787878),
                                    width: 0.5)))),
                    pw.SizedBox(height: 2 * PdfPageFormat.mm),
                    pw.Text('${p['employee']}',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0x16110F))),
                  ]),
                  pw.Column(children: [
                    pw.Text('Disetujui oleh,',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColor.fromInt(0x16110F))),
                    pw.SizedBox(height: 22 * PdfPageFormat.mm),
                    pw.Container(
                        width: 50 * PdfPageFormat.mm,
                        decoration: pw.BoxDecoration(
                            border: pw.Border(
                                top: pw.BorderSide(
                                    color: PdfColor.fromInt(0x787878),
                                    width: 0.5)))),
                    pw.SizedBox(height: 2 * PdfPageFormat.mm),
                    pw.Text('Owner Juragan Seblak',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0x16110F))),
                  ]),
                ],
              ),
              pw.SizedBox(height: 12 * PdfPageFormat.mm),
            ],
          ),
        ),
      ],
    ),
  ));
  final employeeSlug =
      '${p['employee']}'.trim().replaceAll(RegExp(r'\s+'), '_');
  await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Slip-Gaji-$employeeSlug-${p['from']}_${p['to']}.pdf');
}

pw.Widget _info(String k, String v) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1 * PdfPageFormat.mm),
      child: pw.Text('$k   : $v',
          style: const pw.TextStyle(
              fontSize: 10, color: PdfColor.fromInt(0x16110F))),
    );

pw.Widget _row(String label, String val) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5 * PdfPageFormat.mm),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColor.fromInt(0x16110F))),
        pw.Text(val,
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColor.fromInt(0x16110F))),
      ]),
    );
