import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../branch_service.dart';
import '../services/thermal_printer.dart';
import '../theme.dart';
import '../widgets/common.dart';

class Product {
  final int id;
  final String name;
  final String category;
  final double price;
  final String? imageUrl;
  const Product(this.id, this.name, this.category, this.price, this.imageUrl);
}

class _ToppingSel {
  final Product item;
  int qty;
  _ToppingSel(this.item, this.qty);
}

/// Baris keranjang: item biasa (minuman) ATAU porsi prasmanan.
/// Untuk porsi, `item` = produk jenis kuah (kategori 'kuah') dan `toppings`
/// berisi isian pilihan pelanggan; qty = jumlah porsi.
class _CartLine {
  final Product item; // item biasa; utk porsi = produk jenis kuah
  final bool isPorsi;
  final List<_ToppingSel> toppings;
  int qty;
  String? note;
  _CartLine(this.item, this.qty)
      : isPorsi = false,
        toppings = const [];
  _CartLine.porsi(this.item, this.toppings, this.qty, {this.note})
      : isPorsi = true;

  /// Total harga satu baris: porsi = (kuah + topping) x jumlah porsi.
  double get lineTotal {
    if (!isPorsi) return item.price * qty;
    return (item.price + toppings.fold(0.0, (s, t) => s + t.item.price * t.qty)) *
        qty;
  }
}

/// POS — mengikuti Pos.jsx web: metode Cash & QRIS saja, konfirmasi dua
/// langkah (pesanan baru masuk setelah konfirmasi kedua), QRIS dinamis
/// gateway dengan polling, antrian pesanan hari ini + lunaskan manual.
/// Layout mengikuti web: semuanya dalam satu alur scroll (tanpa sticky).
class PosPage extends StatefulWidget {
  final AppUser user;
  const PosPage({super.key, required this.user});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  String search = '';
  String activeCat = 'semua';
  String payMethod = 'cash';
  final List<_CartLine> cart = [];

  List<Product> menuItems = [];
  List<(String, String)> categories = [('semua', 'Semua')];
  double taxRate = 0.10;
  double serviceRate = 0.05;
  double roundingStep = 0; // 0 = tanpa pembulatan, 1000 = naik per Rp1.000
  String storeName = '';
  String storeAddress = '';
  String storePhone = '';
  String storeFooter = '';

  bool loading = true;
  bool submitting = false;
  String? error;

  // Konfigurasi pembayaran dari settings
  String gateway = 'none';
  String qrisImage = '';
  String qrisMerchant = '';

  // Modal pembayaran: {'type': 'confirm', 'stage': 1|2} | {'type': 'gateway', ...}
  Map<String, dynamic>? payModal;

  Map<String, dynamic>? shift;
  Timer? _pollTimer;

  // Antrian pesanan
  List<Map<String, dynamic>> queueOrders = [];
  String queueFilter = 'semua'; // semua | pending | paid
  bool queueLoading = false;

  static const payMethods = {
    'cash': ('Cash', Icons.payments_outlined),
    'qris': ('QRIS', Icons.qr_code),
  };
  static const payLabels = {
    'cash': 'Cash',
    'qris': 'QRIS',
    'debit': 'Debit/Kredit',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _origin => ApiClient.baseUrl.replaceAll(RegExp(r'/api$'), '');

  String _imgUrl(String? path) {
    final s = path ?? '';
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    return '$_origin$s';
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        api.get('/products'),
        api.get('/categories'),
        api.get('/settings'),
      ]);
      final products = (results[0] as List).map((p) {
        final m = Map<String, dynamic>.from(p as Map);
        return Product(
            m['id'] is int ? m['id'] : int.parse('${m['id']}'),
            m['name'] ?? '',
            m['category'] ?? '',
            (num.tryParse('${m['price']}') ?? 0).toDouble(),
            m['image_url']);
      }).toList();
      final cats = <(String, String)>[('semua', 'Semua')];
      for (final c in results[1] as List) {
        final m = Map<String, dynamic>.from(c as Map);
        cats.add(('${m['key']}', '${m['label']}'));
      }
      final settings = Map<String, dynamic>.from(results[2] as Map);
      if (mounted) {
        setState(() {
          menuItems = products;
          categories = cats;
          taxRate = (num.tryParse('${settings['tax_rate']}') ?? 0.1).toDouble();
          serviceRate =
              (num.tryParse('${settings['service_rate']}') ?? 0.05).toDouble();
          roundingStep =
              (num.tryParse('${settings['rounding_step']}') ?? 0).toDouble();
          storeName = '${settings['store_name'] ?? ''}';
          storeAddress = '${settings['store_address'] ?? ''}';
          storePhone = '${settings['store_phone'] ?? ''}';
          storeFooter = '${settings['receipt_footer'] ?? ''}';
          gateway = '${settings['payment_gateway'] ?? 'none'}';
          qrisImage = '${settings['qris_static_image'] ?? ''}';
          qrisMerchant = '${settings['qris_static_merchant'] ?? ''}';
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
      }
    }
    _loadShift();
  }

  Future<void> _loadShift() async {
    try {
      final s = await api.get('/shifts/active');
      if (mounted) setState(() => shift = Map<String, dynamic>.from(s as Map));
    } catch (_) {
      if (mounted) setState(() => shift = null);
    }
  }

  void add(Product m) {
    setState(() {
      final line = cart.where((c) => c.item.id == m.id).firstOrNull;
      if (line != null) {
        line.qty++;
      } else {
        cart.add(_CartLine(m, 1));
      }
    });
  }

  // Bahan builder porsi seblak prasmanan: jenis kuah (WAJIB) & topping bebas.
  List<Product> get kuahItems =>
      menuItems.where((m) => m.category == 'kuah').toList();
  List<Product> get toppingItems =>
      menuItems.where((m) => m.category == 'topping').toList();

  /// "Tambah Porsi" — buka sheet racikan: pilih kuah + topping + jumlah porsi.
  void openPorsiBuilder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PorsiBuilderSheet(
        kuahItems: kuahItems,
        toppingItems: toppingItems,
        onAdd: (kuah, toppings, qty, note) {
          setState(() {
            cart.add(_CartLine.porsi(kuah, toppings, qty,
                note: (note == null || note.trim().isEmpty) ? null : note.trim()));
          });
        },
      ),
    );
  }

  void changeQty(_CartLine line, int delta) {
    setState(() {
      line.qty += delta;
      if (line.qty <= 0) cart.remove(line);
    });
  }

  double get subtotal => cart.fold(0.0, (s, c) => s + c.lineTotal);
  // Sama persis dengan server (pricing.js): pajak & layanan dibulatkan ke rupiah,
  // lalu total dinaikkan ke kelipatan roundingStep bila pembulatan aktif.
  double get tax => (subtotal * taxRate).roundToDouble();
  double get service => (subtotal * serviceRate).roundToDouble();
  double get _rawTotal => subtotal + tax + service;
  double get grandTotal => roundingStep > 0
      ? (_rawTotal / roundingStep).ceilToDouble() * roundingStep
      : _rawTotal;
  double get rounding => grandTotal - _rawTotal;

  String _pct(double rate) {
    final s = (rate * 100).toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// Owner/admin tak terkunci mengikuti cabang di header; bila "Semua cabang"
  /// dipilih, cabang harus dipilih dulu sebelum membuka shift / bertransaksi.
  bool get _needsBranchPick =>
      widget.user.isAdmin &&
      !widget.user.isLockedAdmin &&
      branchService.effectiveId(widget.user) == null;

  String _branchNameOf(Map<String, dynamic> o) {
    final id = int.tryParse('${o['branch_id']}');
    return id == null ? '' : branchService.nameOf(id);
  }
  int get totalQty => cart.fold(0, (s, c) => s + c.qty);

  // ---------- CHECKOUT: konfirmasi dua langkah / gateway ----------

  /// Titik masuk tombol Bayar — padanan startCheckout() Pos.jsx.
  void startCheckout() {
    if (cart.isEmpty || submitting) return;
    if (shift == null) {
      setState(() => error = _needsBranchPick
          ? 'Pilih satu cabang di header (bukan "Semua cabang") lalu buka shift.'
          : 'Shift belum dibuka di cabang ini. Buka shift dulu untuk menerima pesanan.');
      return;
    }
    if (payMethod == 'qris' && gateway != 'none') {
      createGatewayOrder();
      return;
    }
    // Cash & QRIS statis: pesanan BARU dibuat setelah konfirmasi kedua.
    setState(() => payModal = {'type': 'confirm', 'stage': 1});
  }

  /// Payload items untuk POST /orders: porsi prasmanan
  /// {kuah_id, qty, note, toppings:[{product_id, qty}]} dan item biasa
  /// {product_id, qty, note}.
  List<Map<String, dynamic>> _itemsPayload() => [
        for (final c in cart)
          if (c.isPorsi)
            {
              'kuah_id': c.item.id,
              'qty': c.qty,
              'note':
                  (c.note?.trim().isEmpty ?? true) ? null : c.note!.trim(),
              'toppings': [
                for (final t in c.toppings)
                  {'product_id': t.item.id, 'qty': t.qty},
              ],
            }
          else
            {
              'product_id': c.item.id,
              'qty': c.qty,
              'note':
                  (c.note?.trim().isEmpty ?? true) ? null : c.note!.trim(),
            },
      ];

  Future<void> createOrder() async {
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final order = await api.post('/orders', {
        'items': _itemsPayload(),
        'pay_method': payMethod,
        'channel': 'pos',
      });
      final o = Map<String, dynamic>.from(order as Map);
      if (!mounted) return;
      setState(() => payModal = null);
      _showReceipt(o);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  /// QRIS dinamis: pesanan 'pending' → QR gateway → polling webhook.
  Future<void> createGatewayOrder() async {
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final order = await api.post('/orders', {
        'items': _itemsPayload(),
        'pay_method': 'qris',
        'channel': 'pos',
        'pending': true,
      });
      final o = Map<String, dynamic>.from(order as Map);
      final payment = await api.post('/payments/create', {'order_id': o['id']});
      if (!mounted) return;
      setState(() {
        payModal = {
          'type': 'gateway',
          'order': o,
          'payment': Map<String, dynamic>.from(payment as Map),
        };
      });
      _pollStatus('${o['order_no']}');
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _pollStatus(String orderNo) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (!mounted ||
          payModal == null ||
          payModal!['type'] != 'gateway') {
        t.cancel();
        return;
      }
      try {
        final o = await api.get('/payments/status/$orderNo');
        if (o is Map && '${o['status']}' == 'paid' && mounted) {
          t.cancel();
          final order = Map<String, dynamic>.from(payModal!['order'] as Map);
          setState(() => payModal = null);
          _showReceipt({...order, ...Map<String, dynamic>.from(o)});
        }
      } catch (_) {/* polling lanjut bila request gagal sesaat */}
    });
  }

  Future<void> _confirmGatewayManual() async {
    final order = Map<String, dynamic>.from(payModal!['order'] as Map);
    try {
      await api.post('/payments/confirm-manual', {'order_id': order['id']});
      if (!mounted) return;
      setState(() => payModal = null);
      _showReceipt({...order, 'status': 'paid'});
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ---------- ANTRIAN PESANAN ----------

  Future<void> _loadQueue() async {
    setState(() => queueLoading = true);
    try {
      final d = _today();
      final data = await api.get('/orders?from=$d&to=$d');
      if (mounted) {
        setState(() => queueOrders = (data as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => queueLoading = false);
    }
  }

  void openQueue() {
    _loadQueue();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QueueSheet(state: this),
    );
  }

  Future<void> _lunaskan(Map<String, dynamic> o) async {
    try {
      await api.post('/payments/confirm-manual', {'order_id': o['id']});
      await _loadQueue();
      await _loadShift();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ---------- RECEIPT ----------

  void _showReceipt(Map<String, dynamic> o) {
    // Keranjang dikosongkan SEKARANG — saat pesanan sudah tersimpan — bukan
    // saat dialog ditutup. Baris struk diambil dari respons server
    // (berisi porsi_no/item_role), sehingga struk baru & cetak ulang dari
    // antrian memakai jalur yang sama. Tombol "Pesanan Baru" MAUPUN tombol
    // back meninggalkan keranjang kosong (perilaku closeReceipt() web).
    setState(() => cart.clear());
    _loadShift();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceiptDialog(
        receipt: o,
        cashier: widget.user.name,
        items: _itemsFromOrder(o),
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeFooter: storeFooter,
        onPrint: (kind) => _printOrder(kind, o),
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  // ---------- CETAK TERMAL 58mm (ESC/POS Bluetooth — padanan window.print) ----------

  /// Cadangan bila respons server belum memuat created_at (format DB lokal).
  static String _nowStamp() {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${t(n.month)}-${t(n.day)} ${t(n.hour)}:${t(n.minute)}:${t(n.second)}';
  }

  static String _fmtDateId(dynamic dt) {
    final s = '$dt' == 'null' ? _nowStamp() : '$dt';
    if (s.length < 16) return s;
    return '${s.substring(0, 10).split('-').reversed.join('/')} ${s.substring(11, 16).replaceAll(':', '.')}';
  }

  /// Konversi baris order dari respons/detail pesanan server menjadi
  /// ThermalItem — menyertakan porsi_no & item_role untuk pengelompokan
  /// porsi prasmanan di struk/resep dapur.
  List<ThermalItem> _itemsFromOrder(Map<String, dynamic> o) => [
        for (final i in (o['items'] as List? ?? []))
          ...() {
            final m = Map<String, dynamic>.from(i as Map);
            final role = '${m['item_role'] ?? ''}';
            return [
              ThermalItem(
                  int.tryParse('${m['qty']}') ?? 0,
                  '${m['name'] ?? ''}',
                  (num.tryParse('${m['unit_price']}') ?? 0).toDouble(),
                  m['note'] == null || '${m['note']}'.isEmpty || '${m['note']}' == 'null'
                      ? null
                      : '${m['note']}',
                  porsiNo: m['porsi_no'] == null
                      ? null
                      : int.tryParse('${m['porsi_no']}'),
                  role: role.isEmpty || role == 'null' ? null : role),
            ];
          }(),
      ];

  /// Cetak dari struk baru — item diambil dari respons pesanan (bukan `cart`,
  /// yang sudah dikosongkan saat struk muncul).
  Future<void> _printOrder(String kind, Map<String, dynamic> o) async {
    await _doPrint(kind, o, _itemsFromOrder(o),
        cashierOverride: widget.user.name);
  }

  /// Cetak ulang dari antrian — ambil detail pesanan dulu (padanan
  /// printFromQueue() Pos.jsx).
  Future<void> _printFromQueue(Map<String, dynamic> o, String kind) async {
    try {
      final detail =
          Map<String, dynamic>.from(await api.get('/orders/${o['id']}') as Map);
      await _doPrint(kind, detail, _itemsFromOrder(detail),
          cashierOverride: '${detail['cashier_name'] ?? widget.user.name}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.chili,
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: AppText.body(size: 12, color: Colors.white)),
        ));
      }
    }
  }

  Future<void> _doPrint(String kind, Map<String, dynamic> o,
      List<ThermalItem> items,
      {String? cashierOverride}) async {
    num n(String k) => num.tryParse('${o[k]}') ?? 0;
    try {
      await ThermalPrinter.print(
        context,
        ThermalData(
          kind: kind,
          no: '${o['order_no'] ?? ''}',
          date: _fmtDateId(o['created_at'] ?? _nowStamp()),
          cashier: cashierOverride ?? '${o['cashier_name'] ?? widget.user.name}',
          customer: o['customer_name'] == null || '${o['customer_name']}' == 'null'
              ? null
              : '${o['customer_name']}',
          table: o['table_no'] == null || '${o['table_no']}' == 'null'
              ? null
              : '${o['table_no']}',
          method: payLabels['${o['pay_method']}'] ?? '${o['pay_method']}',
          storeName: storeName,
          storeAddress: storeAddress,
          storePhone: storePhone,
          footer:
              '${o['receipt_footer'] ?? storeFooter}'.isEmpty || '${o['receipt_footer'] ?? ''}' == 'null'
                  ? (storeFooter.isEmpty ? 'Terima kasih!' : storeFooter)
                  : '${o['receipt_footer']}',
          items: items,
          subtotal: n('subtotal').toDouble(),
          tax: n('tax_amount').toDouble(),
          service: n('service_amount').toDouble(),
          rounding: n('rounding_amount').toDouble(),
          total: n('total').toDouble(),
          branch: _branchNameOf(o),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.char,
          content: Text('Terkirim ke printer — $kind.',
              style: AppText.body(size: 12, color: Colors.white)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.chili,
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: AppText.body(size: 12, color: Colors.white)),
        ));
      }
    }
  }

  // ---------- SHIFT ----------

  Future<void> _shiftDialog() async {
    final ctrl = TextEditingController();
    final closing = shift != null;
    if (!closing && _needsBranchPick) {
      setState(() => error =
          'Pilih satu cabang di header (bukan "Semua cabang") untuk membuka shift.');
      return;
    }
    // Cabang shift: owner/admin mengikuti header (terkunci), admin terkunci
    // memakai cabangnya, kasir memilih sendiri (default cabang akunnya).
    final u = widget.user;
    int? branchChoice = branchService.effectiveId(u) ?? u.branchId ??
        (branchService.branches.isEmpty ? null : branchService.branches.first.id);
    final branchLocked = u.isAdmin && branchService.effectiveId(u) != null;
    double cashTotal = 0;
    if (closing) {
      final totals = Map<String, dynamic>.from(shift!['totals'] as Map? ?? {});
      cashTotal = (num.tryParse('${totals['cash_total']}') ?? 0).toDouble();
    }
    final action = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(closing ? 'Tutup Shift' : 'Mulai Shift',
            style: AppText.display(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              closing
                  ? 'Penjualan tunai shift ini: ${formatRp(cashTotal)}. Hitung uang di laci dan catat sebagai kas akhir.'
                  : 'Hitung uang kas di laci dan catat sebagai kas awal.',
              style: AppText.body(size: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            if (!closing && branchService.branches.isNotEmpty) ...[
              StatefulBuilder(
                builder: (_, setD) => DropdownButtonFormField<int>(
                  initialValue: branchChoice,
                  decoration: const InputDecoration(labelText: 'Cabang'),
                  items: [
                    for (final b in branchService.branches)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: branchLocked
                      ? null
                      : (v) => setD(() => branchChoice = v),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      closing ? 'Kas Akhir di Laci (Rp)' : 'Kas Awal (Rp)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, closing ? 'close' : 'open'),
            child: Text(closing ? 'Tutup & Rekap' : 'Buka Shift'),
          ),
        ],
      ),
    );
    if (action == null) return;
    try {
      if (action == 'open') {
        final s = await api.post('/shifts', {
          'opening_cash': num.tryParse(ctrl.text) ?? 0,
          if (branchChoice != null) 'branch_id': branchChoice,
        });
        setState(() => shift = Map<String, dynamic>.from(s as Map));
      } else {
        final rekap = await api.post('/shifts/${shift!['id']}/close',
            {'closing_cash': num.tryParse(ctrl.text) ?? 0});
        setState(() => shift = null);
        if (mounted) {
          final r = Map<String, dynamic>.from(rekap as Map);
          showDialog(
            context: context,
            builder: (d) => AlertDialog(
              title: Text('Rekap Shift', style: AppText.display(size: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rekapRow('Pesanan', '${r['order_count']}'),
                  _rekapRow('Total Penjualan', formatRp(r['sales_total'] ?? 0)),
                  _rekapRow('Tunai', formatRp(r['cash_total'] ?? 0)),
                  _rekapRow('QRIS', formatRp(r['qris_total'] ?? 0)),
                  _rekapRow('Debit/Kredit', formatRp(r['debit_total'] ?? 0)),
                  _rekapRow('Kas Awal', formatRp(r['opening_cash'] ?? 0)),
                  _rekapRow('Kas Seharusnya', formatRp(r['expected_cash'] ?? 0)),
                  _rekapRow('Kas Akhir (laci)', formatRp(r['closing_cash'] ?? 0)),
                  _rekapRow(
                      'Selisih',
                      (num.tryParse('${r['selisih']}') ?? 0) == 0
                          ? 'Pas'
                          : formatRp(r['selisih'] ?? 0)),
                ],
              ),
              actions: [
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.char, elevation: 0),
                  onPressed: () => Navigator.pop(d),
                  child: const Text('Selesai'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Widget _rekapRow(String l, String r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: AppText.body(size: 12, color: Colors.black45)),
            Text(r, style: AppText.body(size: 12, weight: FontWeight.w600)),
          ],
        ),
      );

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    }
    if (error != null && menuItems.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!,
              textAlign: TextAlign.center,
              style: AppText.body(size: 13, color: AppColors.chili)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Coba lagi')),
        ]),
      );
    }

    final wide = MediaQuery.of(context).size.width > 900;
    if (wide) {
      // Tablet/landscape: dua kolom seperti web. Overlay pembayaran harus
      // di dalam Stack — Positioned.fill di luar Stack membuat layar kosong.
      return Stack(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: _menuColumn(shrinkWrap: false)),
            const SizedBox(width: 16),
            SizedBox(width: 380, child: _cartCard()),
          ]),
        ),
        if (payModal != null) _payModalOverlay(),
      ]);
    }
    // Ponsel: satu alur scroll — menu dulu, keranjang di bawah (seperti web).
    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _menuColumn(shrinkWrap: true),
          const SizedBox(height: 16),
          _cartCard(),
        ]),
      ),
      if (payModal != null) _payModalOverlay(),
    ]);
  }

  Widget _menuColumn({required bool shrinkWrap}) {
    final menuList = menuItems
        .where((m) =>
            // Porsi prasmanan (kuah/topping) hanya via builder, bukan grid.
            m.category != 'kuah' &&
            m.category != 'topping' &&
            (activeCat == 'semua' || m.category == activeCat) &&
            m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    final w = MediaQuery.of(context).size.width;
    final cols = w > 900 ? 3 : 2;

    final grid = GridView.count(
      crossAxisCount: cols,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        for (final m in menuList)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => add(m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      child: Image.network(
                        _imgUrl(m.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.chili.withValues(alpha: 0.08),
                          child: Icon(Icons.ramen_dining,
                              color: AppColors.chili.withValues(alpha: 0.5),
                              size: 28),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                                size: 12, weight: FontWeight.w700)),
                        Text(formatRp(m.price),
                            style: AppText.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: AppColors.chili)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (menuList.isEmpty)
          Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Menu tidak ditemukan.',
                      style: AppText.body(size: 13, color: Colors.black26)))),
      ],
    );

    final content = Column(children: [
      _shiftBar(),
      TextField(
        onChanged: (v) => setState(() => search = v),
        decoration: InputDecoration(
          hintText: 'Cari menu...',
          prefixIcon: const Icon(Icons.search, color: Colors.black26),
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.$2),
                  selected: activeCat == c.$1,
                  onSelected: (_) => setState(() => activeCat = c.$1),
                  labelStyle: AppText.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: activeCat == c.$1
                          ? Colors.white
                          : Colors.black54),
                  selectedColor: AppColors.char,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black12),
                  showCheckmark: false,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _porsiTile(),
      grid,
    ]);

    if (shrinkWrap) return content;
    // Lebar: search & chips tetap di atas, grid di-scroll sendiri.
    return Column(children: [
      _shiftBar(),
      TextField(
        onChanged: (v) => setState(() => search = v),
        decoration: InputDecoration(
          hintText: 'Cari menu...',
          prefixIcon: const Icon(Icons.search, color: Colors.black26),
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.$2),
                  selected: activeCat == c.$1,
                  onSelected: (_) => setState(() => activeCat = c.$1),
                  labelStyle: AppText.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: activeCat == c.$1
                          ? Colors.white
                          : Colors.black54),
                  selectedColor: AppColors.char,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black12),
                  showCheckmark: false,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _porsiTile(),
      Expanded(child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: menuItems
            .where((m) =>
                m.category != 'kuah' &&
                m.category != 'topping' &&
                (activeCat == 'semua' || m.category == activeCat) &&
                m.name.toLowerCase().contains(search.toLowerCase()))
            .map((m) => _menuCard(m))
            .toList(),
      )),
    ]);
  }

  Widget _menuCard(Product m) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => add(m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  _imgUrl(m.imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.chili.withValues(alpha: 0.08),
                    child: Icon(Icons.ramen_dining,
                        color: AppColors.chili.withValues(alpha: 0.5),
                        size: 28),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 12, weight: FontWeight.w700)),
                  Text(formatRp(m.price),
                      style: AppText.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppColors.chili)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tile pembuka builder porsi seblak — tampil di atas grid menu.
  Widget _porsiTile() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: AppColors.chili.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: openPorsiBuilder,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.chili.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.chili,
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      const Icon(Icons.add, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Porsi Seblak Prasmanan',
                            style: AppText.body(
                                size: 13, weight: FontWeight.w700)),
                        Text(
                            'Racik kuah (Nyemek/Sedang/Full Kuah) + topping sesuai selera',
                            style: AppText.body(
                                size: 11, color: Colors.black45)),
                      ]),
                ),
                const Icon(Icons.chevron_right, color: AppColors.chili),
              ]),
            ),
          ),
        ),
      );

  Widget _shiftBar() {
    final active = shift != null;
    String info;
    if (active) {
      final totals = Map<String, dynamic>.from(shift!['totals'] as Map? ?? {});
      final openedAt = '${shift!['opened_at'] ?? ''}';
      final opened = openedAt.length >= 16 ? openedAt.substring(11, 16) : '—';
      final bn = '${shift!['branch_name'] ?? ''}';
      info =
          'Shift aktif sejak $opened${bn.isEmpty || bn == 'null' ? '' : ' · $bn'} · ${totals['order_count'] ?? 0} pesanan · ${formatRp(totals['sales_total'] ?? 0)}';
    } else if (_needsBranchPick) {
      info =
          'Pilih satu cabang di header (bukan "Semua cabang") untuk membuka shift & bertransaksi.';
    } else {
      final bn = branchService.effectiveId(widget.user) == null
          ? 'Cabang'
          : branchService.nameOf(branchService.effectiveId(widget.user));
      info =
          '🔒 $bn TUTUP — belum bisa menerima pesanan (POS maupun online). Tekan Mulai Shift untuk membuka.';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.greenBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: active ? const Color(0xFFBBF7D0) : Colors.black12),
      ),
      child: Row(children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              color: active ? const Color(0xFF22C55E) : Colors.black26,
              shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(info,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: active ? const Color(0xFF166534) : AppColors.chili)),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: openQueue,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black26),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
          ),
          child: Text('Antrian',
              style: AppText.body(size: 11, weight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: (!active && _needsBranchPick) ? null : _shiftDialog,
          style: FilledButton.styleFrom(
            backgroundColor: active ? AppColors.char : AppColors.chili,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(active ? 'Tutup Shift' : 'Mulai Shift',
              style: AppText.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _cartCard() {
    // Penomoran porsi mengikuti urutan baris porsi di keranjang.
    final porsiNo = <_CartLine, int>{};
    var porsiCounter = 0;
    for (final l in cart) {
      if (l.isPorsi) porsiNo[l] = ++porsiCounter;
    }
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pesanan Saat Ini',
                      style: AppText.body(size: 15, weight: FontWeight.w700)),
                  Text('Kasir ${widget.user.name} · $totalQty item',
                      style: AppText.body(size: 11, color: Colors.black45)),
                ]),
                if (cart.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => cart.clear()),
                    child: Text('Kosongkan',
                        style: AppText.body(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppColors.chili)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (cart.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Keranjang kosong — pilih menu di atas.',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 12, color: Colors.black26)),
              )
            else
              Column(
                children: [
                  for (final line in cart)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      line.isPorsi
                                          ? '${line.qty}x ${line.item.name}'
                                          : line.item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.body(
                                          size: 13,
                                          weight: FontWeight.w600)),
                                  Text(
                                      line.isPorsi
                                          ? 'Porsi ${porsiNo[line]} · ${line.toppings.isEmpty ? 'tanpa topping' : line.toppings.map((t) => '${t.qty > 1 ? '${t.qty}x ' : ''}${t.item.name}').join(', ')}'
                                          : formatRp(line.item.price),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.body(
                                          size: 11, color: Colors.black45)),
                                ]),
                          ),
                          _QtyButton(
                              icon: Icons.remove,
                              onTap: () => changeQty(line, -1)),
                          SizedBox(
                              width: 26,
                              child: Text('${line.qty}',
                                  textAlign: TextAlign.center,
                                  style: AppText.body(
                                      size: 13, weight: FontWeight.w700))),
                          _QtyButton(
                              icon: Icons.add,
                              onTap: () => changeQty(line, 1)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(formatRp(line.lineTotal),
                                textAlign: TextAlign.right,
                                style: AppText.body(
                                    size: 12, weight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _noteDialog(line),
                            child: Icon(
                              Icons.edit_note,
                              size: 20,
                              color: line.note != null
                                  ? AppColors.chili
                                  : Colors.black26,
                            ),
                          ),
                        ]),
                        if (line.isPorsi && line.toppings.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                line.toppings
                                    .map((t) =>
                                        '+ ${t.qty > 1 ? '${t.qty}x ' : ''}${t.item.name}')
                                    .join('  '),
                                style: AppText.body(
                                    size: 10, color: Colors.black45)),
                          ),
                        if (line.note != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('↳ ${line.note}',
                                style: AppText.body(
                                    size: 11, color: Colors.black45)),
                          ),
                      ]),
                    ),
                ],
              ),
            const Divider(height: 20),
            _totalRow('Subtotal', formatRp(subtotal)),
            _totalRow('Pajak (${_pct(taxRate)}%)', formatRp(tax)),
            // Pembulatan digabung ke Service di tampilan (tercatat terpisah di sistem).
            _totalRow(
                rounding > 0
                    ? 'Service Charge'
                    : 'Service Charge (${_pct(serviceRate)}%)',
                formatRp(service + rounding)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand Total',
                    style: AppText.body(size: 14, weight: FontWeight.w700)),
                Text(formatRp(grandTotal),
                    style: AppText.display(size: 22, color: AppColors.chili)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final e in payMethods.entries)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => payMethod = e.key),
                      child: Container(
                        margin:
                            EdgeInsets.only(right: e.key == 'qris' ? 0 : 10),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: payMethod == e.key
                              ? AppColors.chili
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: payMethod == e.key
                                  ? AppColors.chili
                                  : Colors.black12),
                        ),
                        child: Column(children: [
                          Icon(e.value.$2,
                              size: 20,
                              color: payMethod == e.key
                                  ? Colors.white
                                  : Colors.black54),
                          const SizedBox(height: 4),
                          Text(e.value.$1,
                              style: AppText.body(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: payMethod == e.key
                                      ? Colors.white
                                      : Colors.black54)),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!,
                  style: AppText.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.chili)),
            ],
            const SizedBox(height: 12),
            primaryButton(
                submitting
                    ? 'Menyimpan...'
                    : shift == null
                        ? 'Buka shift dulu untuk menerima pesanan'
                        : 'Bayar & Cetak Resi',
                onPressed: cart.isEmpty || submitting || shift == null
                    ? null
                    : startCheckout),
          ],
        ),
      );
  }

  Widget _totalRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppText.body(size: 12, color: Colors.black45)),
            Text(value, style: AppText.body(size: 12, color: Colors.black54)),
          ],
        ),
      );

  void _noteDialog(_CartLine line) {
    final ctrl = TextEditingController(text: line.note ?? '');
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Catatan untuk dapur',
            style: AppText.body(size: 15, weight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'mis. pedas level 3'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () {
              setState(() => line.note =
                  ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
              Navigator.pop(d);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ---------- MODAL PEMBAYARAN ----------

  Widget _payModalOverlay() {
    if (payModal!['type'] == 'confirm') {
      return _confirmOverlay();
    }
    return _gatewayOverlay();
  }

  Widget _confirmOverlay() {
    final stage = payModal!['stage'] as int;
    return Positioned.fill(
      child: Material(
        color: AppColors.char.withValues(alpha: 0.7),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: stage == 1
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (payMethod == 'qris' && qrisImage.isNotEmpty) ...[
                          if (qrisMerchant.isNotEmpty)
                            Text('a.n $qrisMerchant',
                                style: AppText.body(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: Colors.black54)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _imgUrl(qrisImage),
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 200, height: 200),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        const SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                              color: AppColors.chili, strokeWidth: 4),
                        ),
                        const SizedBox(height: 14),
                        Text('MENUNGGU PEMBAYARAN',
                            textAlign: TextAlign.center,
                            style: AppText.display(size: 18)),
                        Text(
                          payMethod == 'qris'
                              ? 'Minta pelanggan scan QR dan bayar'
                              : 'Terima uang dari pelanggan',
                          textAlign: TextAlign.center,
                          style: AppText.body(
                              size: 12, color: Colors.black45),
                        ),
                        const SizedBox(height: 10),
                        Text(formatRp(grandTotal),
                            style: AppText.display(
                                size: 26, color: AppColors.chili)),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => payModal = null),
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Colors.black26),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999))),
                                  child: Text('Pembeli Batal',
                                      style: AppText.body(
                                          size: 12,
                                          weight: FontWeight.w700)))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: FilledButton(
                                  onPressed: () => setState(
                                      () => payModal = {
                                            'type': 'confirm',
                                            'stage': 2
                                          }),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.chili,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999))),
                                  child: Text('Uang Diterima',
                                      style: AppText.body(
                                          size: 12,
                                          weight: FontWeight.w700,
                                          color: Colors.white)))),
                        ]),
                        const SizedBox(height: 12),
                        Text(
                          'Pesanan belum tersimpan — baru masuk setelah konfirmasi dua kali.',
                          textAlign: TextAlign.center,
                          style: AppText.body(
                              size: 10, color: Colors.black38),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                              color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                          child: const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFD97706), size: 30),
                        ),
                        const SizedBox(height: 14),
                        Text('YAKIN SUDAH DITERIMA?',
                            textAlign: TextAlign.center,
                            style: AppText.display(size: 18)),
                        const SizedBox(height: 6),
                        Text(
                          '${formatRp(grandTotal)} via ${payLabels[payMethod] ?? payMethod}. Setelah dikonfirmasi, pesanan langsung masuk & stok terpotong.',
                          textAlign: TextAlign.center,
                          style: AppText.body(
                              size: 12, color: Colors.black45),
                        ),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: () => setState(
                                      () => payModal = {
                                            'type': 'confirm',
                                            'stage': 1
                                          }),
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Colors.black26),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999))),
                                  child: Text('Belum / Batal',
                                      style: AppText.body(
                                          size: 12,
                                          weight: FontWeight.w700)))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: FilledButton(
                                  onPressed: () {
                                    setState(() => payModal = null);
                                    createOrder();
                                  },
                                  style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999))),
                                  child: Text('Ya, Lunas & Cetak',
                                      style: AppText.body(
                                          size: 12,
                                          weight: FontWeight.w700,
                                          color: Colors.white)))),
                        ]),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gatewayOverlay() {
    final payment =
        Map<String, dynamic>.from(payModal!['payment'] as Map? ?? {});
    final order = Map<String, dynamic>.from(payModal!['order'] as Map? ?? {});
    final qrString = '${payment['qr_string'] ?? ''}';
    final qrUrl = '${payment['qr_url'] ?? ''}';
    final checkoutUrl = '${payment['checkout_url'] ?? ''}';

    return Positioned.fill(
      child: Material(
        color: AppColors.char.withValues(alpha: 0.7),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('BAYAR VIA QRIS',
                      style: AppText.display(size: 18)),
                  Text('${order['order_no']} · menunggu pembayaran...',
                      style: AppText.body(size: 11, color: Colors.black45)),
                  const SizedBox(height: 14),
                  if (qrUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(_imgUrl(qrUrl),
                          width: 220, height: 220, fit: BoxFit.cover),
                    )
                  else if (qrString.isNotEmpty)
                    Container(
                      width: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(qrString,
                          textAlign: TextAlign.center,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 8, color: Colors.black54)),
                    )
                  else if (checkoutUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Buka halaman pembayaran gateway: $checkoutUrl',
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 11, color: AppColors.chili)),
                    ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(formatRp(grandTotal),
                      style:
                          AppText.display(size: 22, color: AppColors.chili)),
                  Text('Struk muncul otomatis setelah pembayaran diterima.',
                      style: AppText.body(size: 10, color: Colors.black38)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _confirmGatewayManual,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999))),
                    child: Text('Konfirmasi Manual (dana sudah diterima)',
                        style: AppText.body(
                            size: 12, weight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => payModal = null),
                    child: Text(
                        'Tutup — pesanan tersimpan, lunaskan lewat Antrian',
                        style: AppText.body(
                            size: 10, color: Colors.black38)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
            shape: BoxShape.circle, border: Border.all(color: Colors.black26)),
        child: Icon(icon, size: 14),
      ),
    );
  }
}

/// Bottom sheet antrian pesanan hari ini — padanan modal Antrian web
/// (auto-refresh 15 detik, cetak struk/resep dapur, lunaskan).
class _QueueSheet extends StatefulWidget {
  final _PosPageState state;
  const _QueueSheet({required this.state});

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Polling antrian tiap 15 detik selama sheet terbuka (Pos.jsx:284-290).
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await widget.state._loadQueue();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: StatefulBuilder(
        builder: (context, setSheet) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ANTRIAN PESANAN',
                            style: AppText.display(size: 18)),
                        Text(
                          'Hari ini · ${s.queueOrders.where((o) => o['status'] != 'canceled').length} pesanan aktif'
                          ' · ${s.queueOrders.where((o) => o['status'] == 'pending').length} menunggu bayar',
                          style:
                              AppText.body(size: 11, color: Colors.black45),
                        ),
                      ]),
                ),
                TextButton(
                  onPressed: () async {
                    await s._loadQueue();
                    setSheet(() {});
                  },
                  child: Text(s.queueLoading ? 'Memuat...' : 'Segarkan',
                      style: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: AppColors.chili)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                for (final f in [
                  ('semua', 'Semua'),
                  ('pending', 'Menunggu Bayar'),
                  ('paid', 'Lunas'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: s.queueFilter == f.$1,
                      showCheckmark: false,
                      selectedColor: AppColors.chili,
                      labelStyle: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: s.queueFilter == f.$1
                              ? Colors.white
                              : Colors.black54),
                      onSelected: (_) {
                        s.queueFilter = f.$1;
                        setSheet(() {});
                      },
                    ),
                  ),
              ]),
            ),
            const Divider(height: 16),
            Expanded(
              child: Builder(builder: (context) {
                final shown = s.queueOrders.where((o) =>
                    s.queueFilter == 'semua'
                        ? o['status'] != 'canceled'
                        : o['status'] == s.queueFilter);
                if (shown.isEmpty) {
                  return Center(
                      child: Text('Tidak ada pesanan pada filter ini.',
                          style:
                              AppText.body(size: 12, color: Colors.black26)));
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    for (final o in shown)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: o['status'] == 'pending'
                                  ? const Color(0xFFFCD34D)
                                  : Colors.black12),
                          color: o['status'] == 'pending'
                              ? const Color(0xFFFFFBEB)
                              : Colors.white,
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text('${o['order_no']}',
                                    style: AppText.body(
                                        size: 13, weight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                Text(
                                    '${('${o['created_at'] ?? ''}'.length >= 16) ? '${o['created_at']}'.substring(11, 16) : ''}',
                                    style: AppText.body(
                                        size: 11, color: Colors.black45)),
                                const SizedBox(width: 8),
                                o['status'] == 'paid'
                                    ? StatusChip.ok('Lunas')
                                    : o['status'] == 'pending'
                                        ? StatusChip.warn('Menunggu')
                                        : StatusChip('Batal',
                                            fg: Colors.black45,
                                            bg: Colors.black
                                                .withValues(alpha: 0.05)),
                                const Spacer(),
                                Text(
                                    formatRp(num.tryParse(
                                            '${o['total']}') ??
                                        0),
                                    style: AppText.body(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        color: AppColors.chili)),
                              ]),
                              const SizedBox(height: 4),
                              Text(
                                  '${_payLabel(o['pay_method'])} · ${o['items_preview'] ?? '—'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                      size: 11, color: Colors.black45)),
                              if (o['void_reason'] != null &&
                                  '${o['void_reason']}'.isNotEmpty &&
                                  '${o['void_reason']}' != 'null')
                                Text('Dibatalkan: ${o['void_reason']}',
                                    style: AppText.body(
                                        size: 11,
                                        color: AppColors.chili)),
                              const SizedBox(height: 8),
                              Row(children: [
                                // Cetak ulang dari antrian (Pos.jsx:662-663)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Colors.black26),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6)),
                                  onPressed: o['status'] == 'canceled'
                                      ? null
                                      : () => s
                                          ._printFromQueue(o, 'struk'),
                                  child: Text('Cetak Struk',
                                      style: AppText.body(
                                          size: 10,
                                          weight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: AppColors.ember
                                              .withValues(alpha: 0.4)),
                                      foregroundColor: AppColors.ember,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6)),
                                  onPressed: o['status'] == 'canceled'
                                      ? null
                                      : () => s
                                          ._printFromQueue(o, 'dapur'),
                                  child: Text('Cetak Resep Dapur',
                                      style: AppText.body(
                                          size: 10,
                                          weight: FontWeight.w700)),
                                ),
                                const Spacer(),
                                if (o['status'] == 'pending')
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF16A34A),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999))),
                                    onPressed: () async {
                                      await s._lunaskan(o);
                                      setSheet(() {});
                                    },
                                    child: Text('Lunaskan',
                                        style: AppText.body(
                                            size: 11,
                                            weight: FontWeight.w700,
                                            color: Colors.white)),
                                  ),
                              ]),
                            ]),
                      ),
                  ],
                );
              }),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.cream,
              child: Text(
                'Antrian menyegarkan otomatis tiap 15 detik · cetakan format kertas termal 58mm via Bluetooth.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 10, color: Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _payLabel(dynamic m) =>
      {'cash': 'Cash', 'qris': 'QRIS', 'debit': 'Debit/Kredit'}['$m'] ?? '$m';
}

/// Struk setelah pesanan lunas. Baris item dari server (ThermalItem dengan
/// porsi_no/item_role) — porsi prasmanan tampil berkelompok.
class _ReceiptDialog extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final String cashier;
  final List<ThermalItem> items;
  final String storeName, storeAddress, storePhone, storeFooter;
  final void Function(String kind) onPrint;
  final VoidCallback onClose;

  const _ReceiptDialog({
    required this.receipt,
    required this.cashier,
    required this.items,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.storeFooter,
    required this.onPrint,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    Widget dashed() => const Divider(height: 14);
    final method =
        {'cash': 'Cash', 'qris': 'QRIS', 'debit': 'Debit/Kredit'}[
                '${receipt['pay_method']}'] ??
            '${receipt['pay_method']}';
    final created = '${receipt['created_at'] ?? ''}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${receipt['store_name'] ?? storeName}',
                style: AppText.display(size: 20)),
            if (storeAddress.isNotEmpty)
              Text(storeAddress,
                  style: AppText.body(size: 10, color: Colors.black45)),
            if (storePhone.isNotEmpty)
              Text('Telp: $storePhone',
                  style: AppText.body(size: 10, color: Colors.black45)),
            dashed(),
            _row('No. Struk', '${receipt['order_no']}'),
            _row('Kasir', cashier),
            _row('Tanggal',
                created.length >= 16 ? created.substring(0, 16) : created),
            dashed(),
            for (final it in items) ...[
              if (it.role == 'kuah') ...[
                _row('${it.qty}x ${it.name} (Porsi ${it.porsiNo})',
                    formatRp(it.price * it.qty)),
                if (it.note != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('↳ ${it.note}',
                        style: AppText.body(size: 10, color: Colors.black45)),
                  ),
              ] else if (it.role == 'topping') ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _row('+ ${it.qty}x ${it.name}',
                      formatRp(it.price * it.qty)),
                ),
              ] else ...[
                _row('${it.qty}x ${it.name}', formatRp(it.price * it.qty)),
                if (it.note != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('↳ ${it.note}',
                        style: AppText.body(size: 10, color: Colors.black45)),
                  ),
              ],
            ],
            dashed(),
            _row('Subtotal', formatRp(receipt['subtotal'] ?? 0)),
            _row('Pajak', formatRp(receipt['tax_amount'] ?? 0)),
            _row(
                'Service',
                formatRp((num.tryParse('${receipt['service_amount']}') ?? 0) +
                    (num.tryParse('${receipt['rounding_amount']}') ?? 0))),
            dashed(),
            _row('Total', formatRp(receipt['total'] ?? 0), bold: true),
            _row('Metode', method),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.chili.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999)),
              child: Text('LUNAS',
                  style: AppText.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.chili)),
            ),
            const SizedBox(height: 8),
            Text('${receipt['receipt_footer'] ?? storeFooter}',
                textAlign: TextAlign.center,
                style: AppText.body(size: 10, color: Colors.black38)),
            const SizedBox(height: 16),
            // Tombol cetak termal (padanan Pos.jsx:783-790)
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.char,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => onPrint('struk'),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: Text('Cetak Struk',
                      style: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ember,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => onPrint('dapur'),
                  icon: const Icon(Icons.restaurant_outlined, size: 16),
                  label: Text('Cetak Resep Dapur',
                      style: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            primaryButton('Kirim WhatsApp',
                color: const Color(0xFF16A34A),
                onPressed: () => _sendWhatsApp(context)),
            const SizedBox(height: 10),
            primaryButton('Pesanan Baru',
                color: AppColors.char, onPressed: onClose),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsApp(BuildContext context) async {
    final buf = StringBuffer();
    buf.writeln('*${receipt['store_name'] ?? storeName}*');
    if (storeAddress.isNotEmpty) buf.writeln(storeAddress);
    buf.writeln();
    buf.writeln('No: ${receipt['order_no']}');
    buf.writeln('Kasir: $cashier');
    buf.writeln();
    for (final it in items) {
      if (it.role == 'kuah') {
        buf.writeln(
            '${it.qty}x ${it.name} (Porsi ${it.porsiNo}) - ${formatRp(it.price * it.qty)}');
        if (it.note != null) buf.writeln('    catatan: ${it.note}');
      } else if (it.role == 'topping') {
        buf.writeln('    + ${it.qty}x ${it.name} - ${formatRp(it.price * it.qty)}');
      } else {
        buf.writeln('${it.qty}x ${it.name} - ${formatRp(it.price * it.qty)}');
        if (it.note != null) buf.writeln('    catatan: ${it.note}');
      }
    }
    buf.writeln();
    buf.writeln('Subtotal: ${formatRp(receipt['subtotal'] ?? 0)}');
    buf.writeln('Pajak: ${formatRp(receipt['tax_amount'] ?? 0)}');
    buf.writeln(
        'Service: ${formatRp((num.tryParse('${receipt['service_amount']}') ?? 0) + (num.tryParse('${receipt['rounding_amount']}') ?? 0))}');
    buf.writeln('*Total: ${formatRp(receipt['total'] ?? 0)}*');
    buf.writeln();
    buf.writeln('${receipt['receipt_footer'] ?? storeFooter}');

    final uri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(buf.toString())}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tidak bisa membuka WhatsApp')));
      }
    }
  }

  Widget _row(String l, String r, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l,
                style: AppText.body(
                    size: 12,
                    color: bold ? AppColors.char : Colors.black54,
                    weight: bold ? FontWeight.w700 : FontWeight.w500)),
            Flexible(
              child: Text(r,
                  textAlign: TextAlign.right,
                  style: AppText.body(
                      size: 12,
                      color: bold ? AppColors.char : Colors.black54,
                      weight: bold ? FontWeight.w700 : FontWeight.w500)),
            ),
          ],
        ),
      );
}

/// Sheet racikan porsi seblak prasmanan — padanan builder Porsi di web
/// (Pos.jsx & Order.jsx): jenis kuah WAJIB dipilih (Nyemek/Sedang/Full
/// Kuah), topping bebas dengan jumlah, atur jumlah porsi, catatan dapur.
class _PorsiBuilderSheet extends StatefulWidget {
  final List<Product> kuahItems;
  final List<Product> toppingItems;
  final void Function(
          Product kuah, List<_ToppingSel> toppings, int qty, String? note)
      onAdd;

  const _PorsiBuilderSheet({
    required this.kuahItems,
    required this.toppingItems,
    required this.onAdd,
  });

  @override
  State<_PorsiBuilderSheet> createState() => _PorsiBuilderSheetState();
}

class _PorsiBuilderSheetState extends State<_PorsiBuilderSheet> {
  Product? kuah;
  final Map<int, int> toppings = {}; // product_id topping -> qty
  int qty = 1;
  final noteCtrl = TextEditingController();
  String? error;

  double get total {
    if (kuah == null) return 0;
    final toppingSum = widget.toppingItems
        .fold(0.0, (s, t) => s + (toppings[t.id] ?? 0) * t.price);
    return (kuah!.price + toppingSum) * qty;
  }

  void _toggleTopping(Product t) {
    setState(() {
      if (toppings[t.id] != null) {
        toppings.remove(t.id);
      } else {
        toppings[t.id] = 1;
      }
    });
  }

  void _changeToppingQty(Product t, int delta) {
    setState(() {
      final q = (toppings[t.id] ?? 0) + delta;
      if (q <= 0) {
        toppings.remove(t.id);
      } else {
        toppings[t.id] = q;
      }
    });
  }

  void _submit() {
    if (kuah == null) {
      setState(() =>
          error = 'Wajib pilih jenis kuah dulu (Nyemek, Sedang, atau Full Kuah)');
      return;
    }
    final sel = [
      for (final t in widget.toppingItems)
        if (toppings[t.id] != null) _ToppingSel(t, toppings[t.id]!),
    ];
    widget.onAdd(kuah!, sel, qty, noteCtrl.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget step(String title, {String? accent}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(
            TextSpan(
              text: title,
              style: AppText.body(size: 12, weight: FontWeight.w700,
                  color: Colors.black54),
              children: accent == null
                  ? null
                  : [
                      TextSpan(
                          text: ' — $accent',
                          style: AppText.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: AppColors.chili)),
                    ],
            ),
          ),
        );

    Widget qtyButton(IconData icon, VoidCallback onTap,
            {bool filled = false}) =>
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.chili : Colors.transparent,
              border: Border.all(
                  color: filled ? AppColors.chili : Colors.black26),
            ),
            child: Icon(icon,
                size: 15,
                color: filled ? Colors.white : Colors.black87),
          ),
        );

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RACIK PORSI SEBLAK',
                          style: AppText.display(size: 18)),
                      Text(
                          'Kuah wajib dipilih, isi topping sesuai selera pembeli',
                          style: AppText.body(size: 11, color: Colors.black45)),
                    ]),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                step('1. Jenis Kuah', accent: 'WAJIB'),
                if (widget.kuahItems.isEmpty)
                  Text(
                      'Belum ada jenis kuah — tambahkan produk berkategori "Jenis Kuah" di halaman Menu.',
                      style: AppText.body(size: 11, color: Colors.black26))
                else
                  for (final k in widget.kuahItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          kuah = k;
                          error = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: kuah?.id == k.id
                                    ? AppColors.chili
                                    : Colors.black12),
                            color: kuah?.id == k.id
                                ? AppColors.chili.withValues(alpha: 0.06)
                                : Colors.transparent,
                          ),
                          child: Row(children: [
                            Icon(
                              kuah?.id == k.id
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: kuah?.id == k.id
                                  ? AppColors.chili
                                  : Colors.black26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(k.name,
                                  style: AppText.body(size: 13,
                                      weight: FontWeight.w600)),
                            ),
                            Text(formatRp(k.price),
                                style: AppText.body(size: 12,
                                    weight: FontWeight.w700,
                                    color: AppColors.chili)),
                          ]),
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                step('2. Isian / Topping', accent: 'sesuai selera'),
                if (widget.toppingItems.isEmpty)
                  Text(
                      'Belum ada topping — tambahkan produk berkategori "Topping Seblak" di halaman Menu.',
                      style: AppText.body(size: 11, color: Colors.black26))
                else
                  for (final t in widget.toppingItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: (toppings[t.id] ?? 0) > 0
                                  ? AppColors.chili
                                  : Colors.black12),
                          color: (toppings[t.id] ?? 0) > 0
                              ? AppColors.chili.withValues(alpha: 0.06)
                              : Colors.transparent,
                        ),
                        child: Row(children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _toggleTopping(t),
                              child: Row(children: [
                                Icon(
                                  (toppings[t.id] ?? 0) > 0
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 20,
                                  color: (toppings[t.id] ?? 0) > 0
                                      ? AppColors.chili
                                      : Colors.black26,
                                ),
                                const SizedBox(width: 10),
                                Text(t.name, style:
                                    AppText.body(size: 13, weight:
                                        FontWeight.w600)),
                                const SizedBox(width: 8),
                                Text(formatRp(t.price), style:
                                    AppText.body(size: 11,
                                        color: Colors.black45)),
                              ]),
                            ),
                          ),
                          if ((toppings[t.id] ?? 0) == 0)
                            qtyButton(Icons.add, () => _toggleTopping(t),
                                filled: true)
                          else ...[
                            qtyButton(Icons.remove,
                                () => _changeToppingQty(t, -1)),
                            SizedBox(
                                width: 26,
                                child: Text('${toppings[t.id]}',
                                    textAlign: TextAlign.center,
                                    style: AppText.body(size: 13,
                                        weight: FontWeight.w700))),
                            qtyButton(Icons.add,
                                () => _changeToppingQty(t, 1),
                                filled: true),
                          ],
                        ]),
                      ),
                    ),
                const SizedBox(height: 12),
                step('3. Jumlah Porsi & Catatan Dapur'),
                Row(children: [
                  qtyButton(
                      Icons.remove,
                      () => setState(
                          () => qty = qty > 1 ? qty - 1 : 1)),
                  SizedBox(
                      width: 44,
                      child: Text('$qty porsi',
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 12,
                              weight: FontWeight.w700))),
                  qtyButton(Icons.add,
                      () => setState(() => qty++), filled: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        hintText: 'mis. pedas level 3',
                        isDense: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(error!,
                        style: AppText.body(size: 11,
                            weight: FontWeight.w700,
                            color: AppColors.chili)),
                  ),
                ),
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SUBTOTAL PORSI', style: AppText.body(size: 10,
                          weight: FontWeight.w700,
                          color: Colors.black45)),
                      Text(formatRp(total), style: AppText.display(
                          size: 20, color: AppColors.chili)),
                    ]),
                const SizedBox(width: 16),
                Expanded(
                  child: primaryButton('Tambah ke Keranjang',
                      onPressed: _submit),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
