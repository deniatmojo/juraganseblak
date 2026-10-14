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
  // Seblak prasmanan: item_role ('kuah'|'topping') + porsi_no untuk
  // pengelompokan porsi di struk/resep dapur. Null = item biasa (minuman).
  final int? porsiNo;
  final String? role;
  const ThermalItem(this.qty, this.name, this.price, this.note,
      {this.porsiNo, this.role});
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
  final double rounding; // pembulatan ke atas (0 = tanpa pembulatan)
  final double total;
  final String branch; // nama cabang (dicetak di bawah alamat bila terisi)

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
    this.rounding = 0,
    required this.total,
    this.branch = '',
  });
}

class ThermalPrinter {
  static const _macKey = 'thermal_printer_mac';
  static const _nameKey = 'thermal_printer_name';
  static const _safeKey = 'thermal_printer_safe'; // true = tanpa QR & potong kertas

  /// Cetak ke printer Bluetooth: minta izin runtime dulu (Android 12+
  /// mewajibkan BLUETOOTH_CONNECT sebelum enumerasi/koneksi), lalu coba
  /// sambung ke printer tersimpan atau minta pilih dari daftar.
  ///
  /// CATATAN: hasil `bluetoothEnabled` TIDAK dipakai untuk memblokir —
  /// di sebagian ROM ia melaporkan false meski Bluetooth nyala (cek internal
  /// plugin terikat kombinasi izin). Kegagalan sejati muncul di connect.
  static Future<void> print(BuildContext context, ThermalData data) async {
    final permOk = await _ensurePermissions();
    final btReportsOff = !(await PrintBluetoothThermal.bluetoothEnabled);
    var connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) connected = await _connectSaved();
    if (connected) return _printBytes(data);
    if (!context.mounted) {
      throw Exception('Aplikasi tidak aktif — coba cetak lagi.');
    }
    connected = await _connectPick(context);
    if (!connected) throw Exception(_failMessage(permOk, btReportsOff));
    return _printBytes(data);
  }

  static String _failMessage(bool permOk, bool btReportsOff) {
    if (!permOk) {
      return 'Izin Bluetooth ("Perangkat sekitar / Nearby devices") belum diberikan — izinkan di Pengaturan > Aplikasi > Juragan Seblak > Izin, lalu coba lagi.';
    }
    return btReportsOff
        ? 'Bluetooth tidak terdeteksi aplikasi — pastikan Bluetooth menyala, lalu coba lagi.'
        : 'Gagal terhubung ke printer — pastikan printer menyala, berada dekat HP, dan sudah dipasangkan di pengaturan Bluetooth.';
  }

  /// Menu "Printer Bluetooth": lihat printer tersimpan, pilih/ganti printer,
  /// cetak tes, atau lupakan printer. Dibuka dari drawer aplikasi.
  static Future<void> manage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        final mac = prefs.getString(_macKey);
        final name = prefs.getString(_nameKey);
        Future<void> run(Future<void> Function() job) async {
          Navigator.pop(sheetCtx);
          final messenger = ScaffoldMessenger.of(context);
          try {
            await job();
          } catch (e) {
            messenger.showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.chili,
                content: Text(e.toString().replaceFirst('Exception: ', ''),
                    style: AppText.body(size: 12, color: Colors.white))));
          }
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Printer Bluetooth', style: AppText.display(size: 17)),
                  const SizedBox(height: 4),
                  Text(
                      mac == null
                          ? 'Belum ada printer tersimpan. Pasangkan (pairing) printer termal 58mm di pengaturan Bluetooth HP, lalu pilih di sini.'
                          : 'Tersimpan: ${name ?? 'Printer'} ($mac)',
                      style: AppText.body(size: 11, color: Colors.black45)),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bluetooth_searching,
                        color: AppColors.chili),
                    title: Text(mac == null ? 'Pilih printer' : 'Ganti printer',
                        style: AppText.body(size: 13, weight: FontWeight.w700)),
                    onTap: () => run(() async {
                      await _ensurePermissions();
                      if (!context.mounted) return;
                      final ok = await _connectPick(context);
                      if (!ok) throw Exception('Printer belum terhubung.');
                    }),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.print_outlined,
                        color: AppColors.chili),
                    title: Text('Cetak tes',
                        style: AppText.body(size: 13, weight: FontWeight.w700)),
                    subtitle: Text('Pastikan printer menyala & terhubung',
                        style: AppText.body(size: 10, color: Colors.black45)),
                    onTap: () => run(() async {
                      await print(context, _testData());
                    }),
                  ),
                  if (mac != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link_off, color: Colors.black45),
                      title: Text('Lupakan printer',
                          style:
                              AppText.body(size: 13, weight: FontWeight.w700)),
                      onTap: () => run(() async {
                        try {
                          await PrintBluetoothThermal.disconnect;
                        } catch (_) {}
                        await prefs.remove(_macKey);
                        await prefs.remove(_nameKey);
                      }),
                    ),
                ]),
          ),
        );
      },
    );
  }

  static ThermalData _testData() => const ThermalData(
        kind: 'struk',
        no: 'TES-CETAK',
        date: 'Tes printer Bluetooth',
        cashier: 'Juragan Seblak',
        method: 'Cash',
        storeName: 'JURAGAN SEBLAK',
        storeAddress: 'Tes cetak berhasil',
        storePhone: '',
        footer: 'Printer siap dipakai',
        items: [ThermalItem(1, 'Item contoh', 10000, null)],
        subtotal: 10000,
        tax: 0,
        service: 0,
        total: 10000,
      );

  /// Izin Bluetooth runtime — Android 12+ (API 31) menuntut BLUETOOTH_CONNECT
  /// diminta lewat dialog sistem sebelum pairedBluetooths/connect dipakai.
  /// BLUETOOTH_SCAN ikut diminta karena cek internal plugin bisa menggabungkan
  /// keduanya; kegagalannya tidak memblokir selama salah satu terlah granted.
  ///
  /// Mengembalikan false bila ditolak, tetapi TIDAK memblokir: di Android 11
  /// ke bawah izin ini tidak ada (dilaporkan 'denied' padahal tidak
  /// diperlukan), jadi koneksi tetap dicoba dan kegagalannya diberi pesan yang
  /// menyebut izin bila memang itu penyebabnya.
  static Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    final connectOk =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    return connectOk || scanOk;
  }

  static Future<void> _printBytes(ThermalData raw) async {
    final data = _sanitized(raw);
    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm58, profile);
    Uint8List build({required bool safe}) => data.kind == 'struk'
        ? _buildStruk(gen, data, safe: safe)
        : _buildDapur(gen, data, safe: safe);

    final prefs = await SharedPreferences.getInstance();
    final preferSafe = prefs.getBool(_safeKey) ?? false;
    var ok = await _sendChunked(build(safe: preferSafe));
    if (!ok) {
      // Koneksi bisa basi (printer sempat mati/keluar jangkauan): sambung ulang
      // ke printer tersimpan lalu coba lagi.
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      if (await _connectSaved()) {
        await Future.delayed(const Duration(milliseconds: 400));
        ok = await _sendChunked(build(safe: preferSafe));
      }
    }
    if (!ok && !preferSafe) {
      // Terakhir: mode aman (tanpa QR & potong kertas). Bila berhasil, diingat
      // untuk cetakan berikutnya karena printer ini jelas tak menerima keduanya.
      if (await PrintBluetoothThermal.connectionStatus ||
          await _connectSaved()) {
        ok = await _sendChunked(build(safe: true));
        if (ok) await prefs.setBool(_safeKey, true);
      }
    }
    if (!ok) {
      throw Exception(
          'Printer terhubung tetapi tidak menerima data — pastikan penutup kertas tertutup, kertas ada, printer dekat HP dan tidak sedang dipakai aplikasi lain, lalu coba lagi.');
    }
  }

  /// Kirim per potongan kecil dengan jeda — printer Bluetooth murah (mis. RPP02N)
  /// sering memutus koneksi bila menerima data sekaligus dalam satu blok besar.
  static Future<bool> _sendChunked(Uint8List bytes) async {
    const chunk = 200;
    for (var i = 0; i < bytes.length; i += chunk) {
      final end = i + chunk > bytes.length ? bytes.length : i + chunk;
      final ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
      if (!ok) return false;
      await Future.delayed(const Duration(milliseconds: 40));
    }
    return true;
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
                i.note == null ? null : _clean(i.note!),
                porsiNo: i.porsiNo, role: i.role),
        ],
        subtotal: d.subtotal,
        tax: d.tax,
        service: d.service,
        rounding: d.rounding,
        total: d.total,
        branch: _clean(d.branch),
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
    // Perangkat bernama mirip printer termal ditaruh paling atas; sisanya
    // (speaker, headset, jam tangan) tetap ada di bawah untuk jaga-jaga.
    final saved = (await SharedPreferences.getInstance()).getString(_macKey);
    final sorted = [...devices]..sort((x, y) {
        int rank(BluetoothInfo d) =>
            d.macAdress == saved ? 0 : (_looksLikePrinter(d.name) ? 1 : 2);
        final r = rank(x).compareTo(rank(y));
        return r != 0 ? r : x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });
    if (!context.mounted) return false;
    final mac = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        var query = '';
        return StatefulBuilder(builder: (ctx, setS) {
          final shown = sorted
              .where((d) =>
                  query.isEmpty ||
                  d.name.toLowerCase().contains(query) ||
                  d.macAdress.toLowerCase().contains(query))
              .toList();
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pilih Printer Bluetooth',
                              style: AppText.display(size: 17)),
                          const SizedBox(height: 4),
                          Text(
                              devices.isEmpty
                                  ? 'Tidak ada perangkat terpasang — pastikan Bluetooth menyala dan printer sudah di-pairing di pengaturan Bluetooth HP.'
                                  : '${devices.length} perangkat terpasang. Printer (nama mis. RPP, MTP, PT, Printer) ada paling atas — geser untuk melihat lainnya. Printer akan diingat untuk cetakan berikutnya.',
                              style: AppText.body(size: 11, color: Colors.black45)),
                          if (devices.length > 5) ...[
                            const SizedBox(height: 10),
                            TextField(
                              onChanged: (v) =>
                                  setS(() => query = v.trim().toLowerCase()),
                              decoration: const InputDecoration(
                                  isDense: true,
                                  prefixIcon: Icon(Icons.search, size: 18),
                                  hintText: 'Cari nama printer…'),
                            ),
                          ],
                        ]),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final d in shown)
                          ListTile(
                            leading: Icon(
                                _looksLikePrinter(d.name)
                                    ? Icons.print_outlined
                                    : Icons.bluetooth,
                                color: _looksLikePrinter(d.name)
                                    ? AppColors.chili
                                    : Colors.black38),
                            title: Text(d.name,
                                style: AppText.body(
                                    size: 13, weight: FontWeight.w700)),
                            subtitle: Text(
                                '${d.macAdress}${d.macAdress == saved ? ' · printer tersimpan' : _looksLikePrinter(d.name) ? ' · kemungkinan printer' : ''}',
                                style: AppText.body(
                                    size: 10,
                                    color: _looksLikePrinter(d.name)
                                        ? AppColors.chili
                                        : Colors.black45)),
                            onTap: () => Navigator.pop(sheetCtx, d.macAdress),
                          ),
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                                child: TextButton(
                                    onPressed: () => Navigator.pop(sheetCtx),
                                    child: const Text('Tutup'))),
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          );
        });
      },
    );
    if (mac == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macKey, mac);
    final picked = devices.where((d) => d.macAdress == mac).firstOrNull;
    if (picked != null) await prefs.setString(_nameKey, picked.name);
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    } catch (_) {
      return false;
    }
  }

  /// Tebakan dari nama: printer termal portabel umumnya bernama RPP02N, MTP-II,
  /// PT-210, MPT-3, "Bluetooth Printer", dst.
  static bool _looksLikePrinter(String name) => RegExp(
          r'(rpp|mtp|mpt|pt-?\d|printer|print|thermal|pos[-_ ]?\d|zj-?\d|rp\d|xp-|gp-|hm-|bt-?print|kprinter|sunmi|epson|tm-|spp)',
          caseSensitive: false)
      .hasMatch(name);

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
  static Uint8List _buildStruk(Generator gen, ThermalData d, {bool safe = false}) {
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
    if (d.branch.isNotEmpty) {
      b.add(gen.text('Cabang: ${d.branch}',
          styles: const PosStyles(align: PosAlign.center, bold: true)));
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
      if (i.role == 'kuah') {
        // Baris kuah = kepala porsi prasmanan (qty = jumlah porsi).
        b.add(gen.row([
          PosColumn(
              text: '${i.qty}x ${i.name} (P.${i.porsiNo ?? '-'})',
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
      } else if (i.role == 'topping') {
        // Topping menjorok ke dalam, di bawah kuah porsinya.
        b.add(gen.row([
          PosColumn(
              text: '+ ${i.qty}x ${i.name}',
              width: 8,
              styles: const PosStyles()),
          PosColumn(
              text: _rp(i.price * i.qty),
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      } else {
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
    }
    b.add(gen.hr(ch: '-', linesAfter: 1));
    b.add(_row(gen, 'Subtotal', _rp(d.subtotal)));
    b.add(_row(gen, 'Pajak', _rp(d.tax)));
    b.add(_row(gen, 'Service', _rp(d.service)));
    if (d.rounding > 0) b.add(_row(gen, 'Pembulatan', _rp(d.rounding)));
    b.add(_row(gen, 'TOTAL', _rp(d.total), bold: true, big: true));
    b.add(_row(gen, 'Metode', d.method));
    b.add(gen.hr(ch: '-', linesAfter: 1));
    b.add(gen.text(d.no, styles: const PosStyles(align: PosAlign.center)));
    if (!safe) {
      try {
        b.add(gen.qrcode(d.no));
      } catch (_) {
        // printer tak mendukung QR — lewati
      }
    }
    b.add(gen.text('LUNAS',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    b.add(gen.text(d.footer.isEmpty ? 'Terima kasih!' : d.footer,
        styles: const PosStyles(align: PosAlign.center)));
    // Mode aman: tanpa perintah potong (sebagian printer 58mm tanpa pemotong
    // memutus koneksi saat menerimanya) — cukup dorong kertas keluar.
    b.add(gen.feed(safe ? 4 : 2));
    if (!safe) b.add(gen.cut());
    return b.toBytes();
  }

  // ---- Template RESEP DAPUR — mirror web Pos.jsx:839-860 ----
  static Uint8List _buildDapur(Generator gen, ThermalData d, {bool safe = false}) {
    final b = BytesBuilder();
    b.add(gen.reset());
    b.add(gen.text('RESEP DAPUR',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    b.add(gen.text(
        d.branch.isNotEmpty
            ? d.branch
            : (d.storeName.isEmpty ? 'Juragan Seblak' : d.storeName),
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
      if (i.role == 'kuah') {
        // Kepala porsi prasmanan — besar & tebal agar mudah dibaca koki.
        b.add(gen.text('PORSI ${i.porsiNo ?? '-'}: ${i.qty}x ${i.name}',
            styles: const PosStyles(
                bold: true, height: PosTextSize.size2)));
        if (i.note != null && i.note!.isNotEmpty) {
          b.add(gen.text('> ${i.note}',
              styles: const PosStyles(bold: true)));
        }
      } else if (i.role == 'topping') {
        b.add(gen.text('   + ${i.qty}x ${i.name}',
            styles: const PosStyles()));
      } else {
        b.add(gen.text('${i.qty}x ${i.name}',
            styles: const PosStyles(
                bold: true, height: PosTextSize.size2)));
        if (i.note != null && i.note!.isNotEmpty) {
          b.add(gen.text('> ${i.note}',
              styles: const PosStyles(bold: true)));
        }
      }
    }
    b.add(gen.hr(ch: '-', linesAfter: 1));
    b.add(gen.text('Untuk koki - selesaikan sesuai urutan datang',
        styles: const PosStyles(align: PosAlign.center)));
    // Mode aman: tanpa perintah potong (sebagian printer 58mm tanpa pemotong
    // memutus koneksi saat menerimanya) — cukup dorong kertas keluar.
    b.add(gen.feed(safe ? 4 : 2));
    if (!safe) b.add(gen.cut());
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
