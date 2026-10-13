import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Lembar cetak QR meja A5 (148x210 mm), satu halaman per meja — padanan
/// web/src/pages/admin/QrPrintSheet.jsx. Dart murni (hanya paket `pdf`) agar
/// bisa dirender & diuji tanpa Flutter. QR digambar vektor (tajam saat cetak).
class QrSheetTable {
  final String url; // URL yang dikodekan QR (mis. https://…/order?meja=3)
  final String label; // label meja apa adanya dari database
  final String branchName; // dipakai bila label tidak memuat nama cabang
  const QrSheetTable(
      {required this.url, required this.label, this.branchName = ''});
}

const _chili = PdfColor.fromInt(0xFFC81E1E);
const _ember = PdfColor.fromInt(0xFFF97316);
const _emberLight = PdfColor.fromInt(0xFFFDBA74);
const _char = PdfColor.fromInt(0xFF16110F);
const _cream = PdfColor.fromInt(0xFFFAF3EC);
const _muted = PdfColor.fromInt(0xFF6B5B53);

/// Label meja sering sudah memuat nama cabang ("Juragan Seblak Prasmanan 2 -
/// Meja A"): bagian terakhir jadi nama besar, sisanya keterangan cabang.
({String title, String sub}) splitTableLabel(QrSheetTable t) {
  final parts = t.label
      .split(RegExp(r'\s[-–—]\s'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final main = parts.isEmpty ? t.label : parts.last;
  final rest = parts.length > 1 ? parts.sublist(0, parts.length - 1).join(' · ') : '';
  final title = RegExp(r'^meja\b', caseSensitive: false).hasMatch(main)
      ? main
      : 'Meja $main';
  return (title: title, sub: rest.isNotEmpty ? rest : t.branchName);
}

String _ascii(String s) => s.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

Future<Uint8List> buildQrSheetPdf({
  required List<QrSheetTable> tables,
  required Uint8List logo,
  String host = '',
}) async {
  final doc = pw.Document(
      title: 'QR Meja - Juragan Seblak', creator: 'Juragan Seblak ERP');
  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();
  final logoImg = pw.MemoryImage(logo);
  const format = PdfPageFormat.a5;
  final w = format.width;

  for (final t in tables) {
    final (:title, :sub) = splitTableLabel(t);
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Stack(children: [
        // latar krem
        pw.Positioned.fill(child: pw.Container(color: _cream)),
        // pita merah + dekorasi
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Container(
            width: w,
            height: 215,
            decoration: const pw.BoxDecoration(
              color: _chili,
              borderRadius: pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(40),
                bottomRight: pw.Radius.circular(40),
              ),
            ),
          ),
        ),
        pw.Positioned(
          left: -45,
          top: -55,
          child: pw.Opacity(
            opacity: 0.35,
            child: pw.Container(
                width: 130,
                height: 130,
                decoration: const pw.BoxDecoration(
                    color: _ember, shape: pw.BoxShape.circle)),
          ),
        ),
        pw.Positioned(
          right: -30,
          top: 120,
          child: pw.Opacity(
            opacity: 0.12,
            child: pw.Container(
                width: 96,
                height: 96,
                decoration: const pw.BoxDecoration(
                    color: PdfColors.white, shape: pw.BoxShape.circle)),
          ),
        ),
        // logo bulat
        pw.Positioned(
          left: (w - 112) / 2,
          top: 20,
          child: pw.Container(
            width: 112,
            height: 112,
            padding: const pw.EdgeInsets.all(4),
            decoration: const pw.BoxDecoration(
                color: PdfColors.white, shape: pw.BoxShape.circle),
            child: pw.ClipOval(
                child: pw.Image(logoImg,
                    width: 104, height: 104, fit: pw.BoxFit.cover)),
          ),
        ),
        pw.Positioned(
          left: 0,
          top: 142,
          child: pw.SizedBox(
            width: w,
            child: pw.Text('JURAGAN SEBLAK',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 25,
                    letterSpacing: 2,
                    color: PdfColors.white)),
          ),
        ),
        pw.Positioned(
          left: 0,
          top: 176,
          child: pw.SizedBox(
            width: w,
            child: pw.Text('Seblak Prasmanan  |  Racik Sendiri, Puas Sendiri',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 8, color: _emberLight)),
          ),
        ),
        // kartu QR
        pw.Positioned(
          left: 60,
          top: 198,
          child: pw.Container(
            width: w - 120,
            padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _ember, width: 3),
              borderRadius: pw.BorderRadius.circular(20),
            ),
            child: pw.Column(children: [
              pw.Text('SCAN & PESAN DARI MEJA',
                  style: pw.TextStyle(
                      font: bold, fontSize: 13, letterSpacing: 1, color: _chili)),
              pw.SizedBox(height: 9),
              pw.Container(
                width: 184,
                height: 184,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _char, width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(
                      errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium),
                  data: t.url,
                  drawText: false,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 11),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 6),
                decoration: pw.BoxDecoration(
                    color: _char, borderRadius: pw.BorderRadius.circular(16)),
                child: pw.Text(_ascii(title).toUpperCase(),
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 21,
                        letterSpacing: 1,
                        color: PdfColors.white)),
              ),
              if (sub.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(_ascii(sub),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 8.5, color: _muted)),
              ],
            ]),
          ),
        ),
        // 3 langkah
        pw.Positioned(
          left: 26,
          right: 26,
          top: 526,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              for (final (i, s) in const [
                ('Scan', 'QR dengan kamera HP'),
                ('Pilih', 'menu & kirim pesanan'),
                ('Bayar', 'di meja, kasir ACC'),
              ].indexed)
                pw.SizedBox(
                  width: (w - 52) / 3 - 4,
                  child: pw.Row(children: [
                    pw.Container(
                      width: 20,
                      height: 20,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(
                          color: _ember, shape: pw.BoxShape.circle),
                      child: pw.Text('${i + 1}',
                          style: pw.TextStyle(
                              font: bold, fontSize: 10, color: PdfColors.white)),
                    ),
                    pw.SizedBox(width: 5),
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(
                          style: pw.TextStyle(font: regular, fontSize: 7.5),
                          children: [
                            pw.TextSpan(
                                text: '${s.$1} ',
                                style: pw.TextStyle(font: bold, fontSize: 7.5)),
                            pw.TextSpan(text: s.$2),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ),
        pw.Positioned(
          left: 0,
          bottom: 14,
          child: pw.SizedBox(
            width: w,
            child: pw.Text(
                'Terima kasih sudah makan di Juragan Seblak${host.isEmpty ? '' : '  |  $host'}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 6.8, color: _muted)),
          ),
        ),
      ]),
    ));
  }
  return doc.save();
}
