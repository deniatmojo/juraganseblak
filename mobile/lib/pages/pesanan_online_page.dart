import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pesanan Online — menyalin web/src/pages/admin/PesananOnline.jsx:
/// tab 📋 Pesanan (ACC pembayaran QRIS manual oleh admin/kasir, alur tahap
/// antrian > diproses > siap/diantar > selesai, tolak/batalkan, auto-refresh
/// 15 detik, badge 🪑 Meja) dan tab 🪑 QR Meja (CRUD meja + QR per meja
/// + lembar cetak semua QR sebagai PDF yang bisa di-share/save — padanan
/// window.print() di web).
class PesananOnlinePage extends StatefulWidget {
  final AppUser user;
  const PesananOnlinePage({super.key, required this.user});

  @override
  State<PesananOnlinePage> createState() => _PesananOnlinePageState();
}

const _progressLabel = {
  'queue': 'Antrian',
  'processing': 'Diproses',
  'ready': 'Siap/Diantar',
  'done': 'Selesai',
};

const _typeLabel = {
  'dinein': 'Dine-In',
  'delivery': 'Delivery',
  'pickup': 'Ambil di Tempat',
};

/// Tombol tahap berikutnya sesuai alur (web NEXT_STEP/NEXT_LABEL).
const _nextStep = {'queue': 'processing', 'processing': 'ready', 'ready': 'done'};
const _nextLabel = {
  'processing': 'Proses Dapur',
  'ready': 'Siap/Diantar',
  'done': 'Tandai Selesai',
};

String _hhmm(dynamic dt) {
  final s = '$dt';
  return s.length >= 16 ? s.substring(11, 16) : '';
}

class _PesananOnlinePageState extends State<PesananOnlinePage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  bool busy = false;
  String? error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
    // Daftar pesanan online menyala terus: refresh otomatis tiap 15 detik.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tab.dispose();
    super.dispose();
  }

  /// Pesanan online saja — sama seperti web: GET /orders lalu filter
  /// channel === 'online'.
  Future<void> _load() async {
    try {
      final rows = await api.get('/orders');
      if (mounted) {
        setState(() {
          orders = (rows as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .where((r) => r['channel'] == 'online')
              .toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => busy = true);
    try {
      await fn();
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _accPayment(Map<String, dynamic> o) =>
      _run(() => api.post('/payments/confirm-manual', {'order_id': o['id']}));

  void _setProgress(Map<String, dynamic> o, String progress) =>
      _run(() => api.patch('/online/progress',
          {'order_id': o['id'], 'progress': progress}));

  /// Tolak / batalkan — prompt alasan lalu POST /orders/:id/void (web
  /// PesananOnline.jsx:289-293).
  Future<void> _cancel(Map<String, dynamic> o) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Tolak / Batalkan', style: AppText.display(size: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${o['order_no']} — ${o['customer_name'] ?? '—'}',
              style: AppText.body(size: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Alasan', hintText: 'mis. pembayaran tidak masuk'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    await _run(() => api.post('/orders/${o['id']}/void',
        {'reason': ctrl.text.trim()}));
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        orders.where((o) => o['status'] == 'pending').toList();
    final inProgress = orders
        .where((o) => o['status'] == 'paid' && o['progress'] != 'done')
        .toList();
    final finished = orders
        .where((o) =>
            (o['status'] == 'paid' && o['progress'] == 'done') ||
            o['status'] == 'canceled')
        .toList();

    return Column(children: [
      // Tab 📋 Pesanan / 🪑 QR Meja (web: pill switch di atas halaman)
      Container(
        color: AppColors.cream,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TabBar(
          controller: _tab,
          labelColor: AppColors.chili,
          unselectedLabelColor: Colors.black45,
          indicatorColor: AppColors.chili,
          labelStyle: AppText.body(size: 12, weight: FontWeight.w700),
          tabs: const [
            Tab(text: '📋 Pesanan'),
            Tab(text: '🪑 QR Meja'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: [
            RefreshIndicator(
              color: AppColors.chili,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppColors.redBg,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(error!,
                          style: AppText.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: AppColors.chili)),
                    ),
                  _section(
                    'Menunggu ACC',
                    'cek rekening/QRIS, lalu ACC — otomatis masuk antrian',
                    pending.length,
                    AppColors.ember,
                    loading,
                    pending,
                    emptyText: 'Tidak ada pesanan menunggu konfirmasi 👍',
                  ),
                  const SizedBox(height: 24),
                  _section(
                    'Antrian & Diproses',
                    'update tahap pesanan sampai selesai',
                    inProgress.length,
                    AppColors.chili,
                    loading,
                    inProgress,
                    emptyText: 'Antrian kosong.',
                  ),
                  const SizedBox(height: 24),
                  _section(
                    'Selesai & Dibatalkan',
                    null,
                    finished.length,
                    Colors.black45,
                    loading,
                    finished,
                    emptyText: 'Belum ada riwayat.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login sebagai ${widget.user.name} · daftar menyegarkan sendiri tiap 15 detik.',
                    style: AppText.body(size: 10, color: Colors.black38),
                  ),
                ],
              ),
            ),
            const _QrMejaView(),
          ],
        ),
      ),
    ]);
  }

  Widget _section(String title, String? hint, int count, Color accent,
      bool loading, List<Map<String, dynamic>> list,
      {required String emptyText}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title, style: AppText.display(size: 19)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999)),
          child: Text('$count',
              style: AppText.body(
                  size: 11, weight: FontWeight.w800, color: accent)),
        ),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 10, color: Colors.black38)),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      if (loading)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
              child: Text('Memuat…',
                  style: AppText.body(size: 12, color: Colors.black38))),
        )
      else if (list.isEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12)),
          child: Text(emptyText,
              style: AppText.body(size: 12, color: Colors.black38)),
        )
      else
        for (final o in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OrderCard(
              order: o,
              busy: busy,
              onAcc: _accPayment,
              onCancel: _cancel,
              onProgress: _setProgress,
            ),
          ),
    ]);
  }
}

/// Kartu satu pesanan online — mirror OrderCard web (PesananOnline.jsx:25-95).
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool busy;
  final void Function(Map<String, dynamic>) onAcc;
  final Future<void> Function(Map<String, dynamic>) onCancel;
  final void Function(Map<String, dynamic>, String) onProgress;

  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onAcc,
    required this.onCancel,
    required this.onProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = order['status'] == 'pending';
    final isCanceled = order['status'] == 'canceled';
    final progress = '${order['progress'] ?? ''}';
    final nextKey = _nextStep[progress == '' ? 'queue' : progress];

    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${order['order_no']}', style: AppText.display(size: 17)),
              Text(
                '${_hhmm(order['created_at'])}'
                ' · ${_typeLabel['${order['order_type']}'] ?? 'Online'}'
                '${progress.isNotEmpty ? ' · ${_progressLabel[progress] ?? progress}' : ''}',
                style: AppText.body(size: 11, color: Colors.black45),
              ),
              // Badge meja (web: "🪑 Meja X — antar ke sini")
              if ('${order['table_no'] ?? ''}'.isNotEmpty &&
                  '${order['table_no']}' != 'null')
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.ember,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('🪑 Meja ${order['table_no']} — antar ke sini',
                      style: AppText.body(
                          size: 10, weight: FontWeight.w800,
                          color: AppColors.char)),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Text(
            formatRp(num.tryParse('${order['total']}') ?? 0),
            style: AppText.body(
                    size: 14,
                    weight: FontWeight.w800,
                    color: isCanceled
                        ? Colors.black26
                        : isPending
                            ? const Color(0xFFD97706)
                            : AppColors.chili)
                .copyWith(
                    decoration:
                        isCanceled ? TextDecoration.lineThrough : null),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
            '${order['customer_name'] ?? '—'} · ${order['customer_phone'] ?? '—'}',
            style: AppText.body(size: 12, weight: FontWeight.w700)),
        if ('${order['schedule_at'] ?? ''}'.isNotEmpty &&
            '${order['schedule_at']}' != 'null')
          Text('📅 ${order['schedule_at']}',
              style: AppText.body(size: 11, color: Colors.black45)),
        if ('${order['delivery_address'] ?? ''}'.isNotEmpty &&
            '${order['delivery_address']}' != 'null')
          Text('📍 ${order['delivery_address']}',
              style: AppText.body(size: 11, color: Colors.black45)),
        if ('${order['customer_note'] ?? ''}'.isNotEmpty &&
            '${order['customer_note']}' != 'null')
          Text('📝 ${order['customer_note']}',
              style: AppText.body(size: 11, color: Colors.black45)),
        const SizedBox(height: 4),
        Text('${order['items_preview'] ?? '-'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 11, color: Colors.black54)),
        const SizedBox(height: 12),
        // Tombol aksi (web PesananOnline.jsx:55-92)
        if (isPending) ...[
          Row(children: [
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.chili,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: busy ? null : () => onAcc(order),
                child: Text('ACC Pembayaran',
                    style: AppText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black12),
                    foregroundColor: AppColors.chili,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: busy ? null : () => onCancel(order),
                child: Text('Tolak',
                    style: AppText.body(size: 12, weight: FontWeight.w700)),
              ),
            ),
          ]),
        ] else if (order['status'] == 'paid') ...[
          Row(children: [
            if (nextKey != null)
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.char,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: busy ? null : () => onProgress(order, nextKey),
                  child: Text(_nextLabel[nextKey] ?? 'Lanjut',
                      style: AppText.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black12),
                    foregroundColor: AppColors.chili,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: busy ? null : () => onCancel(order),
                child: Text('Batalkan',
                    style: AppText.body(size: 12, weight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ============================================================================
// TAB QR MEJA — kelola daftar meja + QR per meja (web QrMejaView)
// ============================================================================

class _QrMejaView extends StatefulWidget {
  const _QrMejaView();

  @override
  State<_QrMejaView> createState() => _QrMejaViewState();
}

class _QrMejaViewState extends State<_QrMejaView> {
  List<Map<String, dynamic>> tables = [];
  bool loading = true;
  bool busy = false;
  bool exporting = false;
  String? error;

  /// Origin QR = domain produksi (Android selalu memakai server produksi —
  /// padanan window.location.origin di web).
  static String get _origin =>
      ApiClient.baseUrl.replaceAll(RegExp(r'/api$'), '');

  String qrUrlFor(Map<String, dynamic> t) => '$_origin/order?meja=${t['id']}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await api.get('/online/tables');
      if (mounted) {
        setState(() {
          tables = (rows as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => busy = true);
    try {
      await fn();
      await _load();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _rename(Map<String, dynamic> t) async {
    final ctrl = TextEditingController(text: '${t['label']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Ganti Nama Meja', style: AppText.display(size: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama meja'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final label = ctrl.text.trim();
    if (label.isEmpty || label == '${t['label']}') return;
    await _run(() => api.patch('/online/tables/${t['id']}', {'label': label}));
  }

  void _toggle(Map<String, dynamic> t) => _run(() => api.patch(
      '/online/tables/${t['id']}',
      {'is_active': (t['is_active'] == 1 || t['is_active'] == true) ? 0 : 1}));

  void _remove(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(
            'Hapus Meja ${t['label']}? QR yang sudah ditempel di meja akan tidak valid.',
            style: AppText.body(size: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => api.del('/online/tables/${t['id']}'));
  }

  /// Render QR ke PNG bytes untuk PDF lembar cetak.
  Future<Uint8List?> _qrPng(String url) async {
    try {
      final painter = QrPainter(
        data: url,
        version: QrVersions.auto,
        gapless: true,
      );
      final data = await painter.toImageData(300);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// "🖨️ Cetak Semua QR" — padanan window.print() + TableQrPrintSheet web:
  /// lembar A4 grid 2 kolom, kartu per meja aktif (judul, QR, 3 langkah),
  /// dibagikan lewat sheet share agar bisa disimpan/dicetak.
  Future<void> _printAllQr() async {
    final active = tables
        .where((t) => t['is_active'] == 1 || t['is_active'] == true)
        .toList();
    if (active.isEmpty) return;
    setState(() => exporting = true);
    try {
      final qrBytes = <String, Uint8List?>{};
      for (final t in active) {
        qrBytes['${t['id']}'] = await _qrPng(qrUrlFor(t));
      }
      final doc = pw.Document(
          title: 'QR Meja — Juragan Seblak', creator: 'Juragan Seblak ERP');
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(14, 16, 14, 16),
        header: (ctx) => pw.Column(children: [
          if (ctx.pageNumber == 1) ...[
            pw.Text('JURAGAN SEBLAK',
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0x16110F))),
            pw.SizedBox(height: 4),
            pw.Text('Scan QR di bawah untuk memesan dari meja',
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColor.fromInt(0x6B16110F))),
          ],
          pw.SizedBox(height: 12),
        ]),
        build: (_) => [
          pw.Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final t in active)
                pw.Container(
                  width: (PdfPageFormat.a4.width - 28 - 14) / 2,
                  padding: const pw.EdgeInsets.all(18),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFF16110F), width: 2),
                    borderRadius: pw.BorderRadius.circular(14),
                  ),
                  child: pw.Column(children: [
                    pw.Text('MEJA ${t['label']}'.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0x16110F))),
                    pw.SizedBox(height: 10),
                    if (qrBytes['${t['id']}'] != null)
                      pw.Image(pw.MemoryImage(qrBytes['${t['id']}']!),
                          width: 130, height: 130),
                    pw.SizedBox(height: 10),
                    pw.Text('1. Scan QR dengan kamera HP',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('2. Pilih menu & kirim pesanan',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                        '3. Bayar di meja — pesanan diantar ke meja ${t['label']}',
                        style: const pw.TextStyle(fontSize: 9)),
                  ]),
                ),
            ],
          ),
        ],
      ));
      await Printing.sharePdf(
          bytes: await doc.save(),
          filename: 'QR-Meja-Juragan-Seblak.pdf');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = tables
        .where((t) => t['is_active'] == 1 || t['is_active'] == true)
        .length;
    return RefreshIndicator(
      color: AppColors.chili,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Setiap meja punya QR sendiri — tempel di meja, pembeli cukup scan, pesan, dan bayar di tempat. Pelayan melihat nomor meja di daftar pesanan.',
            style: AppText.body(size: 11, color: Colors.black45),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black12),
                foregroundColor: AppColors.char,
                minimumSize: const Size.fromHeight(46)),
            onPressed:
                exporting || loading || activeCount == 0 ? null : _printAllQr,
            icon: exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_outlined, size: 18),
            label: Text(exporting ? 'Menyiapkan PDF…' : '🖨️ Cetak Semua QR',
                style: AppText.body(size: 12, weight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(error!,
                  style: AppText.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.chili)),
            ),
          _AddTableRow(
              busy: busy,
              onAdd: (label) => _run(() async {
                    await api.post('/online/tables', {'label': label});
                  })),
          const SizedBox(height: 14),
          if (loading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                  child: Text('Memuat…',
                      style:
                          AppText.body(size: 12, color: Colors.black38))),
            )
          else if (tables.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12)),
              child: Text('Belum ada meja. Tambahkan meja pertama di atas.',
                  style: AppText.body(size: 12, color: Colors.black38)),
            )
          else
            for (final t in tables)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TableQrCard(
                  table: t,
                  qrUrl: qrUrlFor(t),
                  busy: busy,
                  onRename: _rename,
                  onToggle: _toggle,
                  onDelete: _remove,
                ),
              ),
        ],
      ),
    );
  }
}

/// Input "Nama meja baru" + tombol Tambah Meja (web QrMejaView form).
class _AddTableRow extends StatefulWidget {
  final bool busy;
  final Future<void> Function(String label) onAdd;
  const _AddTableRow({required this.busy, required this.onAdd});

  @override
  State<_AddTableRow> createState() => _AddTableRowState();
}

class _AddTableRowState extends State<_AddTableRow> {
  final ctrl = TextEditingController();

  void _submit() {
    final label = ctrl.text.trim();
    if (label.isEmpty) return;
    widget.onAdd(label);
    ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: ctrl,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
              hintText: 'Nama meja baru, mis. 9 / Teras-1 / VIP-2'),
        ),
      ),
      const SizedBox(width: 10),
      FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: AppColors.chili,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
        onPressed: widget.busy ? null : _submit,
        child: Text('+ Tambah Meja',
            style: AppText.body(
                size: 12, weight: FontWeight.w700, color: Colors.white)),
      ),
    ]);
  }
}

/// Kartu QR satu meja — mirror TableQrCard web.
class _TableQrCard extends StatelessWidget {
  final Map<String, dynamic> table;
  final String qrUrl;
  final bool busy;
  final void Function(Map<String, dynamic>) onRename;
  final void Function(Map<String, dynamic>) onToggle;
  final void Function(Map<String, dynamic>) onDelete;

  const _TableQrCard({
    required this.table,
    required this.qrUrl,
    required this.busy,
    required this.onRename,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final active = table['is_active'] == 1 || table['is_active'] == true;
    return Opacity(
      opacity: active ? 1 : 0.5,
      child: SectionCard(
        child: Column(children: [
          QrImageView(
            data: qrUrl,
            version: QrVersions.auto,
            size: 150,
            gapless: true,
          ),
          const SizedBox(height: 8),
          Text('🪑 Meja ${table['label']}', style: AppText.display(size: 18)),
          if (!active)
            Text('Nonaktif — QR tidak bisa dipakai',
                style: AppText.body(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.chili)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black12),
                    foregroundColor: AppColors.chili,
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: busy ? null : () => onRename(table),
                child: Text('Ganti Nama',
                    style: AppText.body(size: 10, weight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black12),
                    foregroundColor: AppColors.chili,
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: busy ? null : () => onToggle(table),
                child: Text(active ? 'Nonaktifkan' : 'Aktifkan',
                    style: AppText.body(size: 10, weight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black12),
                    foregroundColor: AppColors.chili,
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: busy ? null : () => onDelete(table),
                child: Text('Hapus',
                    style: AppText.body(size: 10, weight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
