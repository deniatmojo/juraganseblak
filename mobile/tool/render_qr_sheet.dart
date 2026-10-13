// Render contoh lembar QR A5 ke PDF untuk pengecekan visual:
//   dart run tool/render_qr_sheet.dart <output.pdf>
import 'dart:io';
import 'package:juragan_seblak_app/services/qr_sheet.dart';

Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args[0] : 'qr-sheet.pdf';
  final logo = await File('assets/logo.jpg').readAsBytes();
  final bytes = await buildQrSheetPdf(
    logo: logo,
    host: 'juragan-seblak.airadynamics.com',
    tables: const [
      QrSheetTable(
          url: 'https://juragan-seblak.airadynamics.com/order?meja=3',
          label: 'Juragan Seblak Prasmanan 2 - Meja A'),
      QrSheetTable(
          url: 'https://juragan-seblak.airadynamics.com/order?meja=4',
          label: '7',
          branchName: 'Juragan Seblak Prasmanan 1'),
    ],
  );
  await File(out).writeAsBytes(bytes);
  stdout.writeln('ok ${bytes.length} bytes -> $out');
}
