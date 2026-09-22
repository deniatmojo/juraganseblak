import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
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

class _CartLine {
  final Product item;
  int qty;
  String? note;
  _CartLine(this.item, this.qty);
}

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

  bool loading = true;
  String? error;

  Map<String, dynamic>? shift; // shift aktif dari /shifts/active
  bool submitting = false;

  static const payMethods = {
    'cash': ('Cash', Icons.payments_outlined),
    'qris': ('QRIS', Icons.qr_code),
    'debit': ('Debit/Kredit', Icons.credit_card),
  };

  @override
  void initState() {
    super.initState();
    _load();
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

  void changeQty(_CartLine line, int delta) {
    setState(() {
      line.qty += delta;
      if (line.qty <= 0) cart.remove(line);
    });
  }

  double get subtotal => cart.fold(0.0, (s, c) => s + c.item.price * c.qty);
  double get tax => subtotal * taxRate;
  double get service => subtotal * serviceRate;
  double get grandTotal => subtotal + tax + service;

  Future<void> checkout() async {
    if (cart.isEmpty || submitting) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final order = await api.post('/orders', {
        'items': cart
            .map((c) => {
                  'product_id': c.item.id,
                  'qty': c.qty,
                  'note': (c.note?.trim().isEmpty ?? true) ? null : c.note!.trim(),
                })
            .toList(),
        'pay_method': payMethod,
        'channel': 'pos',
      });
      final o = Map<String, dynamic>.from(order as Map);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReceiptDialog(
          receipt: o,
          cashier: widget.user.name,
          lines: List.of(cart),
          onClose: () {
            Navigator.pop(context);
            setState(() => cart.clear());
            _loadShift();
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 840;
    final menuList = menuItems
        .where((m) =>
            (activeCat == 'semua' || m.category == activeCat) &&
            m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    Widget body;

    if (loading) {
      body = const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    } else if (error != null && menuItems.isEmpty) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!,
              textAlign: TextAlign.center,
              style: AppText.body(size: 13, color: AppColors.chili)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Coba lagi')),
        ]),
      );
    } else {
      final menuSection = _menuSection(menuList);
      final cartSection = _cartSection();
      body = wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: menuSection),
              const SizedBox(width: 16),
              cartSection,
            ])
          : Column(children: [
              Expanded(child: menuSection),
              SizedBox(height: 360, child: cartSection),
            ]);
    }

    return Padding(padding: const EdgeInsets.all(16), child: body);
  }

  Widget _menuSection(List<Product> menuList) => Column(
        children: [
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
          Expanded(
            child: GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 560 ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
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
                          Container(
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                              color: AppColors.chili.withValues(alpha: 0.08),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                              child: Image.network(
                                m.imageUrl ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.ramen_dining,
                                    color: AppColors.chili
                                        .withValues(alpha: 0.5),
                                    size: 30),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.body(
                                        size: 13, weight: FontWeight.w700)),
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
                      child: Text('Menu tidak ditemukan.',
                          style: AppText.body(
                              size: 13, color: Colors.black26))),
              ],
            ),
          ),
        ],
      );

  Widget _shiftBar() {
    final active = shift != null;
    String info;
    if (active) {
      final totals = Map<String, dynamic>.from(shift!['totals'] as Map? ?? {});
      final opened = '${shift!['opened_at'] ?? ''}'.substring(11, 16);
      info =
          'Shift aktif sejak $opened · Kas awal ${formatRp(shift!['opening_cash'] ?? 0)}'
          ' · ${totals['order_count'] ?? 0} pesanan · ${formatRp(totals['sales_total'] ?? 0)}';
    } else {
      info =
          'Belum ada shift aktif — checkout tetap bisa, tapi tidak tercatat di rekap kas.';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.greenBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: active ? const Color(0xFFBBF7D0) : Colors.black12),
      ),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: active ? const Color(0xFF22C55E) : Colors.black26,
              shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(info,
              style: AppText.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: active ? const Color(0xFF166534) : Colors.black45)),
        ),
        TextButton(
          onPressed: _shiftDialog,
          child: Text(active ? 'Tutup Shift' : 'Mulai Shift',
              style: AppText.body(size: 11, weight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _cartSection() => Container(
        width: MediaQuery.of(context).size.width > 840 ? 400 : double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(20),
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
                  Text(
                      'Kasir ${widget.user.name} · ${cart.fold<int>(0, (s, c) => s + c.qty)} item',
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
            const SizedBox(height: 8),
            Expanded(
              child: cart.isEmpty
                  ? Center(
                      child: Text(
                        'Keranjang masih kosong.\nPilih menu di sebelah kiri.',
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 12, color: Colors.black26),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final line in cart)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(children: [
                              Row(children: [
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(line.item.name,
                                            style: AppText.body(
                                                size: 13,
                                                weight: FontWeight.w600)),
                                        Text(formatRp(line.item.price),
                                            style: AppText.body(
                                                size: 11,
                                                color: Colors.black45)),
                                      ]),
                                ),
                                _QtyButton(
                                    icon: Icons.remove,
                                    onTap: () => changeQty(line, -1)),
                                SizedBox(
                                    width: 28,
                                    child: Text('${line.qty}',
                                        textAlign: TextAlign.center,
                                        style: AppText.body(
                                            size: 13,
                                            weight: FontWeight.w700))),
                                _QtyButton(
                                    icon: Icons.add,
                                    onTap: () => changeQty(line, 1)),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 86,
                                  child: Text(
                                      formatRp(line.item.price * line.qty),
                                      textAlign: TextAlign.right,
                                      style: AppText.body(
                                          size: 12,
                                          weight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 6),
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
            ),
            const Divider(height: 24),
            _totalRow('Subtotal', formatRp(subtotal)),
            _totalRow('Pajak (${(taxRate * 100).round()}%)', formatRp(tax)),
            _totalRow('Service Charge (${(serviceRate * 100).round()}%)',
                formatRp(service)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand Total',
                    style: AppText.body(size: 14, weight: FontWeight.w700)),
                Text(formatRp(grandTotal),
                    style: AppText.display(size: 22, color: AppColors.chili)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final e in payMethods.entries)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => payMethod = e.key),
                      child: Container(
                        margin:
                            EdgeInsets.only(right: e.key == 'debit' ? 0 : 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
                              size: 18,
                              color: payMethod == e.key
                                  ? Colors.white
                                  : Colors.black54),
                          const SizedBox(height: 4),
                          Text(e.value.$1,
                              style: AppText.body(
                                  size: 10,
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
            const SizedBox(height: 14),
            primaryButton(submitting ? 'Menyimpan...' : 'Bayar & Cetak Resi',
                onPressed: cart.isEmpty || submitting ? null : checkout),
          ],
        ),
      );

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

  Future<void> _shiftDialog() async {
    final ctrl = TextEditingController();
    final closing = shift != null;
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
        final s = await api.post(
            '/shifts', {'opening_cash': num.tryParse(ctrl.text) ?? 0});
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

/// Struk dari respons POST /orders (field sama seperti Pos.jsx web).
class _ReceiptDialog extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final String cashier;
  final List<_CartLine> lines;
  final VoidCallback onClose;

  const _ReceiptDialog({
    required this.receipt,
    required this.cashier,
    required this.lines,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    Widget dashed() => const Divider(height: 14);
    final method = {
      'cash': 'Cash',
      'qris': 'QRIS',
      'debit': 'Debit/Kredit',
    }['${receipt['pay_method']}'] ?? '${receipt['pay_method']}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${receipt['store_name'] ?? 'Juragan Seblak'}',
                style: AppText.display(size: 20)),
            if (receipt['store_address'] != null)
              Text('${receipt['store_address']}',
                  style: AppText.body(size: 10, color: Colors.black45)),
            if (receipt['store_phone'] != null)
              Text('Telp: ${receipt['store_phone']}',
                  style: AppText.body(size: 10, color: Colors.black45)),
            dashed(),
            _row('No. Struk', '${receipt['order_no']}'),
            _row('Kasir', cashier),
            _row('Tanggal', '${receipt['created_at'] ?? ''}'.substring(0, 16)),
            dashed(),
            for (final l in lines) ...[
              _row('${l.qty}x ${l.item.name}', formatRp(l.item.price * l.qty)),
              if (l.note != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('↳ ${l.note}',
                      style: AppText.body(size: 10, color: Colors.black45)),
                ),
            ],
            dashed(),
            _row('Subtotal', formatRp(receipt['subtotal'] ?? 0)),
            _row('Pajak', formatRp(receipt['tax_amount'] ?? 0)),
            _row('Service', formatRp(receipt['service_amount'] ?? 0)),
            dashed(),
            _row('Total', formatRp(receipt['total'] ?? 0), bold: true),
            _row('Metode', method),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
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
            Text('${receipt['receipt_footer'] ?? 'Terima kasih, sampai jumpa lagi 🔥'}',
                textAlign: TextAlign.center,
                style: AppText.body(size: 10, color: Colors.black38)),
            const SizedBox(height: 16),
            primaryButton('Pesanan Baru', onPressed: onClose),
          ],
        ),
      ),
    );
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
            Text(r,
                style: AppText.body(
                    size: 12,
                    color: bold ? AppColors.char : Colors.black54,
                    weight: bold ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      );
}
