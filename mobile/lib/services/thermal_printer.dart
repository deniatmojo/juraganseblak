import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// Cetak termal 58mm via Bluetooth ESC/POS — padanan window.print()
/// #thermalPrintArea di web/src/pages/admin/Pos.jsx (template struk &
/// resep dapur disalin 1:1).
class ThermalItem {
  final int qty;
  final String name;
  final double price;
  final String? note;
  const ThermalItem(this.qty, this.name, this.price, this.note);
}

class ThermalData {
  final String kind; // 'struk' | 'dapur'
  final String no;
  final String date;
  final String cashier;
  final String? customer;
  final String? table;
  final String method;
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String footer;
  final List<ThermalItem> items;
  final double subtotal;
  final double tax;
  final double service;
  final double total;

  const ThermalData({
    required this.kind,
    required this.no,
    required this.date,
    required this.cashier,
    this.customer,
    this.table,
    required this.method,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.footer,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.service,
    required this.total,
  });
}

class ThermalPrinter {
  static const _macKey = 'thermal_printer_mac';

  /// Cetak ke printer Bluetooth: minta izin runtime dulu (Android 12+
  /// mewajibkan BLUETOOTH_CONNECT sebelum enumerasi/koneksi), lalu coba
  /// sambung ke printer tersimpan atau minta pilih dari daftar.
  ///
  /// CATATAN: hasil `bluetoothEnabled` TIDAK dipakai untuk memblokir —
  /// di sebagian ROM ia melaporkan false meski Bluetooth nyala (cek internal
  /// plugin terikat kombinasi izin). Kegagalan sejati muncul di connect.
  static Future<void> print(BuildContext context, ThermalData data) async {
    await _ensurePermissions();
    final btReportsOff = !(await PrintBluetoothThermal.bluetoothEnabled);
    var connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) connected = await _connectSaved();
    if (connected) return _printBytes(data);
    if (!context.mounted) {
      throw Exception('Aplikasi tidak aktif — coba cetak lagi.');
    }
    connected = await _connectPick(context);
    if (!connected) {
      throw Exception(btReportsOff
          ? 'Bluetooth tidak terdeteksi aplikasi — pastikan Bluetooth menyala dan izin "Nearby devices" diberikan, lalu coba lagi.'
          : 'Gagal terhubung ke printer — pastikan printer menyala dan sudah dipasangkan di pengaturan Bluetooth.');
    }
    return _printBytes(data);
  }

  /// Izin Bluetooth runtime — Android 12+ (API 31) menuntut BLUETOOTH_CONNECT
  /// diminta lewat dialog sistem sebelum pairedBluetooths/connect dipakai.
  /// BLUETOOTH_SCAN ikut diminta karena cek internal plugin bisa menggabungkan
  /// keduanya; kegagalannya tidak memblokir selama salah satu terlah granted.
  static Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    final connectOk =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    if (!connectOk && !scanOk) {
      throw Exception(
          'Izin Bluetooth ("Nearby devices") ditolak — izinkan di pengaturan aplikasi untuk mencetak.');
    }
  }

  static Future<void> _printBytes(ThermalData raw) async {
    final data = _sanitized(raw);
    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm58, profile);
    final bytes =
        data.kind == 'struk' ? _buildStruk(gen, data) : _buildDapur(gen, data);
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) throw Exception('Printer menolak data cetakan.');
  }

  /// Salinan data dengan teks yang sudah dibersihkan dari non-ASCII.
  static ThermalData _sanitized(ThermalData d) => ThermalData(
        kind: d.kind,
        no: _clean(d.no),
        date: _clean(d.date),
        cashier: _clean(d.cashier),
        customer: d.customer == null ? null : _clean(d.customer!),
        table: d.table == null ? null : _clean(d.table!),
        method: _clean(d.method),
        storeName: _clean(d.storeName),
        storeAddress: _clean(d.storeAddress),
        storePhone: _clean(d.storePhone),
        footer: _clean(d.footer),
        items: [
          for (final i in d.items)
            ThermalItem(i.qty, _clean(i.name), i.price,
                i.note == null ? null : _clean(i.note!)),
        ],
        subtotal: d.subtotal,
        tax: d.tax,
        service: d.service,
        total: d.total,
      );

  static Future<bool> _connectSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_macKey);
    if (mac == null || mac.isEmpty) return false;
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    } catch (_) {
      return false;
    }
  }

  /// Pilih printer dari perangkat Bluetooth yang sudah dipasangkan.
  static Future<bool> _connectPick(BuildContext context) async {
    List<BluetoothInfo> devices;
    try {
      devices = await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      // Bluetooth benar-benar mati / ROM aneh — tampilkan daftar kosong
      // dengan petunjuk, jangan crash dengan exception mentah.
      devices = [];
    }
    if (!context.mounted) return false;
    final mac = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pilih Printer Bluetooth',
                  style: AppText.display(size: 17)),
              const SizedBox(height: 4),
              Text(
                  devices.isEmpty
                      ? 'Tidak ada printer terpasang — pastikan Bluetooth menyala dan printer sudah di-pairing di pengaturan Bluetooth HP.'
                      : 'Printer akan diingat untuk cetakan berikutnya.',
                  style: AppText.body(size: 11, color: Colors.black45)),
            ]),
          ),
          const Divider(height: 1),
          for (final d in devices)
            ListTile(
              leading:
                  const Icon(Icons.print_outlined, color: AppColors.chili),
              title: Text(d.name,
                  style: AppText.body(size: 13, weight: FontWeight.w700)),
              subtitle: Text(d.macAdress,
                  style: AppText.body(size: 10, color: Colors.black45)),
              onTap: () => Navigator.pop(sheetCtx, d.macAdress),
            ),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('Tutup'))),
            ),
        ]),
      ),
    );
    if (mac == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macKey, mac);
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    } catch (_) {
      return false;
    }
  }

  static String _rp(num n) =>
      'Rp ${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';

  /// Printer termal default memakai codepage CP437 — em-dash, kutip melengkung,
  /// emoji dll akan tercetak sebagai sampah. Petakan yang umum, sisanya buang.
  static String _clean(String s) => s
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('·', '-')
      .replaceAll('\u2193', 'v')
      .replaceAll('\u2191', '^')
      .replaceAllMapped(RegExp(r'[^\x20-\x7E\n]'), (m) => '');

  // ---- Template STRUK — mirror web Pos.jsx:807-838 ----
  static Uint8List _buildStruk(Generator gen, ThermalData d) {
    final b = BytesBuilder();
    b.add(gen.reset());
    b.add(gen.text(d.storeName.isEmpty ? 'JURAGAN SEBLAK' : d.storeName,
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    if (d.storeAddress.isNotEmpty) {
      b.add(gen.text(d.storeAddress,
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (d.storePhone.isNotEmpty) {
      b.add(gen.text('Telp: ${d.storePhone}',
          styles: const PosStyles(align: PosAlign.center)));
    }
    b.add(gen.hr(ch: '-', linesAfter: 1));
    b.add(_row(gen, 'No. Struk', d.no));
    b.add(_row(gen, 'Kasir', d.cashier.isEmpty ? '-' : d.cashier));
    b.add(_row(gen, 'Tanggal', d.date));
    b.add(gen.hr(ch: '-', linesAfter: 1));
    for (final i in d.items) {
      b.add(gen.row([
        PosColumn(
            text: '${i.qty}x ${i.name}',
            width: 8,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: _rp(i.price * i.qty),
            width: 4,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]));
      if (i.note != null && i.note!.isNotEmpty) {
        b.add(gen.text('> ${i.note}'));
      }
    }
    b.add(gen.hr(ch: '-', linesAfter: 1));
    b.add(_row(gen, 'Subtotal', _rp(d.subtotal)));
    b.add(_row(gen, 'Pajak', _rp(d.tax)));
    b.add(_row(gen, 'Service', _rp(d.service)));
    b.add(_row(gen, 'TOTAL', _rp(d.total), bold: true, big: true));
    b.add(_row(gen, 'Metode', d.method));
    b.add(gen.hr(ch: '-', linesAfter: 1));
    b.add(gen.text(d.no, styles: const PosStyles(align: PosAlign.center)));
    try {
      b.add(gen.qrcode(d.no));
    } catch (_) {
      // printer tak mendukung QR — lewati
    }
    b.add(gen.text('LUNAS',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    b.add(gen.text(d.footer.isEmpty ? 'Terima kasih!' : d.footer,
        styles: const PosStyles(align: PosAlign.center)));
    b.add(gen.feed(2));
    b.add(gen.cut());
    return b.toBytes();
  }

  // ---- Template RESEP DAPUR — mirror web Pos.jsx:839-860 ----
  static Uint8List _buildDapur(Generator gen, ThermalData d) {
    final b = BytesBuilder();
    b.add(gen.reset());
    b.add(gen.text('RESEP DAPUR',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    b.add(gen.text(d.storeName.isEmpty ? 'Juragan Seblak' : d.storeName,
        styles: const PosStyles(align: PosAlign.center)));
    b.add(gen.hr(ch: '-', linesAfter: 1));
    b.add(_row(gen, 'No.', d.no, bold: true));
    b.add(_row(gen, 'Waktu', d.date));
    if (d.customer != null && d.customer!.isNotEmpty) {
      b.add(_row(gen, 'Pelanggan', d.customer!));
    }
    if (d.table != null && d.table!.isNotEmpty) {
      b.add(_row(gen, 'Meja', d.table!));
    }
    b.add(gen.hr(ch: '-', linesAfter: 1));
    for (final i in d.items) {
      b.add(gen.text('${i.qty}x ${i.name}',
          styles: const PosStyles(
              bold: true, height: PosTextSize.size2)));
      if (i.note != null && i.note!.isNotEmpty) {
        b.add(gen.text('> ${i.note}',
            styles: const PosStyles(bold: true)));
      }
    }
    b.add(gen.hr(ch: '-', linesAfter: 1));
    b.add(gen.text('Untuk koki — selesaikan sesuai urutan datang',
        styles: const PosStyles(align: PosAlign.center)));
    b.add(gen.feed(2));
    b.add(gen.cut());
    return b.toBytes();
  }

  static List<int> _row(Generator gen, String label, String value,
      {bool bold = false, bool big = false}) {
    final styles = PosStyles(
        bold: bold || big,
        height: big ? PosTextSize.size2 : PosTextSize.size1,
        width: big ? PosTextSize.size2 : PosTextSize.size1);
    return gen.row([
      PosColumn(text: label, width: 5, styles: styles),
      PosColumn(
          text: value,
          width: 7,
          styles: PosStyles(
              align: PosAlign.right,
              bold: bold || big,
              height: big ? PosTextSize.size2 : PosTextSize.size1,
              width: big ? PosTextSize.size2 : PosTextSize.size1)),
    ]);
  }
}
