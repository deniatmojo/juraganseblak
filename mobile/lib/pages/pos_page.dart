import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class _CartLine {
  final MenuItem item;
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

  // Shift kasir (lokal, Tahap 1)
  bool shiftOpen = false;
  String shiftSince = '';
  int openingCash = 0;
  int orderCount = 0;
  int salesTotal = 0;

  static const payMethods = {
    'cash': ('Cash', Icons.payments_outlined),
    'qris': ('QRIS', Icons.qr_code),
    'debit': ('Debit/Kredit', Icons.credit_card),
  };

  void add(MenuItem m) {
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

  int get subtotal => cart.fold(0, (s, c) => s + c.item.price * c.qty);
  double get tax => subtotal * 0.10;
  double get service => subtotal * 0.05;
  double get grandTotal => subtotal + tax + service;

  void checkout() {
    if (cart.isEmpty) return;
    final no =
        'TRX-${(922 + orderCount).toString().padLeft(4, '0')}';
    setState(() {
      orderCount++;
      salesTotal += grandTotal.round();
    });
    showDialog(
      context: context,
      builder: (_) => _ReceiptDialog(
        no: no,
        cashier: widget.user.name,
        lines: List.of(cart),
        subtotal: subtotal,
        tax: tax,
        service: service,
        total: grandTotal,
        method: payMethods[payMethod]!.$1,
        onClose: () {
          Navigator.pop(context);
          setState(() => cart.clear());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 840;
    final menuList = MockData.menu
        .where((m) =>
            (activeCat == 'semua' || m.category == activeCat) &&
            m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    final menuSection = Column(
      children: [
        // Shift bar
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: shiftOpen ? AppColors.greenBg : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: shiftOpen
                    ? const Color(0xFFBBF7D0)
                    : Colors.black12),
          ),
          child: Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: shiftOpen ? const Color(0xFF22C55E) : Colors.black26,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                shiftOpen
                    ? 'Shift aktif sejak $shiftSince · Kas awal ${formatRp(openingCash)} · $orderCount pesanan · ${formatRp(salesTotal)}'
                    : 'Belum ada shift aktif — checkout tetap bisa, tapi tidak tercatat di rekap kas.',
                style: AppText.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: shiftOpen ? const Color(0xFF166534) : Colors.black45),
              ),
            ),
            TextButton(
              onPressed: _shiftDialog,
              child: Text(
                shiftOpen ? 'Tutup Shift' : 'Mulai Shift',
                style: AppText.body(size: 11, weight: FontWeight.w700),
              ),
            ),
          ]),
        ),
        // Search
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
        // Kategori
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in [
                const ('semua', 'Semua'),
                ...MockData.categories.map((c) => (c.key, c.label)),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.$2),
                    selected: activeCat == c.$1,
                    onSelected: (_) => setState(() => activeCat = c.$1),
                    labelStyle: AppText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: activeCat == c.$1 ? Colors.white : Colors.black54),
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
            crossAxisCount:
                MediaQuery.of(context).size.width > 560 ? 3 : 2,
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
                    onTap: m.isAvailable ? () => add(m) : null,
                    child: Opacity(
                      opacity: m.isAvailable ? 1 : 0.45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(14)),
                              color:
                                  AppColors.chili.withValues(alpha: 0.08),
                            ),
                            child: Icon(Icons.ramen_dining,
                                color: AppColors.chili
                                    .withValues(alpha: 0.5),
                                size: 30),
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
                                Text(
                                    m.isAvailable
                                        ? formatRp(m.price)
                                        : 'Habis',
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

    final cartSection = Container(
      width: wide ? 400 : double.infinity,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pesanan Saat Ini',
                      style:
                          AppText.body(size: 15, weight: FontWeight.w700)),
                  Text(
                      'Kasir ${widget.user.name} · ${cart.fold<int>(0, (s, c) => s + c.qty)} item',
                      style:
                          AppText.body(size: 11, color: Colors.black45)),
                ],
              ),
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
                                  ],
                                ),
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
          _totalRow('Pajak (10%)', formatRp(tax)),
          _totalRow('Service Charge (5%)', formatRp(service)),
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
                      margin: EdgeInsets.only(
                          right: e.key == 'debit' ? 0 : 8),
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
          const SizedBox(height: 14),
          primaryButton('Bayar & Cetak Resi',
              onPressed: cart.isEmpty ? null : checkout),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: menuSection),
                const SizedBox(width: 16),
                cartSection,
              ],
            )
          : Column(
              children: [
                Expanded(child: menuSection),
                SizedBox(
                  height: 360,
                  child: cartSection,
                ),
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
          decoration: const InputDecoration(
              hintText: 'mis. pedas level 3'),
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

  void _shiftDialog() {
    final ctrl = TextEditingController();
    final closing = shiftOpen;
    showDialog(
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
                  ? 'Penjualan tunai shift ini: ${formatRp(salesTotal)}. Hitung uang di laci dan catat sebagai kas akhir.'
                  : 'Hitung uang kas di laci dan catat sebagai kas awal.',
              style: AppText.body(size: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: closing ? 'Kas Akhir di Laci (Rp)' : 'Kas Awal (Rp)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () {
              Navigator.pop(d);
              setState(() {
                if (closing) {
                  shiftOpen = false;
                } else {
                  shiftOpen = true;
                  shiftSince =
                      '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}';
                  openingCash = int.tryParse(ctrl.text) ?? 0;
                  orderCount = 0;
                  salesTotal = 0;
                }
              });
            },
            child: Text(closing ? 'Tutup & Rekap' : 'Buka Shift'),
          ),
        ],
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

class _ReceiptDialog extends StatelessWidget {
  final String no;
  final String cashier;
  final List<_CartLine> lines;
  final num subtotal, tax, service, total;
  final String method;
  final VoidCallback onClose;

  const _ReceiptDialog({
    required this.no,
    required this.cashier,
    required this.lines,
    required this.subtotal,
    required this.tax,
    required this.service,
    required this.total,
    required this.method,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    Widget dashed() => const Divider(height: 14);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('JURAGAN SEBLAK', style: AppText.display(size: 20)),
            Text('Jl. Raya Pandan No. 12, Pandaan',
                style: AppText.body(size: 10, color: Colors.black45)),
            Text('Telp: 0812-3456-7890',
                style: AppText.body(size: 10, color: Colors.black45)),
            dashed(),
            _row('No. Struk', no),
            _row('Kasir', cashier),
            _row('Tanggal',
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${TimeOfDay.now().format(context)}'),
            dashed(),
            for (final l in lines) ...[
              _row('${l.qty}x ${l.item.name}',
                  formatRp(l.item.price * l.qty)),
              if (l.note != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('↳ ${l.note}',
                      style:
                          AppText.body(size: 10, color: Colors.black45)),
                ),
            ],
            dashed(),
            _row('Subtotal', formatRp(subtotal)),
            _row('Pajak', formatRp(tax)),
            _row('Service', formatRp(service)),
            dashed(),
            _row('Total', formatRp(total), bold: true),
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
                      size: 13, weight: FontWeight.w700, color: AppColors.chili)),
            ),
            const SizedBox(height: 8),
            Text('Terima kasih, sampai jumpa lagi 🔥',
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
