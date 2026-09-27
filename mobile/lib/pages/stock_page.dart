import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Stok bahan baku — menyalin web/src/pages/admin/Stock.jsx:
/// GET /stock + /stock/movements, POST /stock/:id/move (dengan unit_cost &
/// catatan agar belanja bahan otomatis tercatat di Keuangan), POST /stock.
class StockPage extends StatefulWidget {
  final AppUser user;
  const StockPage({super.key, required this.user});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> movements = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait(
          [api.get('/stock'), api.get('/stock/movements?limit=10')]);
      if (mounted) {
        setState(() {
          items = (results[0] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          movements = (results[1] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
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

  /// Modal mutasi (masuk/keluar/opname) — sama seperti web: type 'in'
  /// menampilkan "Harga Beli per {unit} *" + preview total pembelian,
  /// semua tipe punya "Catatan (opsional)".
  Future<void> _moveDialog(Map<String, dynamic> item, String type) async {
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final title = {
      'in': 'Barang Masuk (Restock)',
      'out': 'Barang Keluar (Waste/Pakai)',
      'adjust': 'Set Stok (Stok Opname)',
    }[type]!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(title, style: AppText.display(size: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${item['name']} — saat ini ${_fmt(item['qty'])} ${item['unit']}',
                style: AppText.body(size: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              onChanged: (_) => setD(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: type == 'adjust'
                      ? 'Jumlah Stok Hasil Opname'
                      : type == 'in'
                          ? 'Jumlah Masuk'
                          : 'Jumlah Keluar',
                  suffixText: '${item['unit']}'),
            ),
            if (type == 'in') ...[
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                onChanged: (_) => setD(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                decoration: const InputDecoration(
                    labelText: 'Harga Beli per unit *',
                    prefixText: 'Rp ',
                    hintText: 'mis. 35000'),
              ),
              if ((_num(qtyCtrl.text) ?? 0) > 0 &&
                  (_num(costCtrl.text) ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Total pembelian: ${formatRp((_num(qtyCtrl.text) ?? 0) * (_num(costCtrl.text) ?? 0))} — otomatis tercatat di Keuangan sebagai belanja bahan.',
                    style: AppText.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.ember),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText:
                      type == 'in' ? 'Belanja dari supplier...' : ''),
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
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await api.post('/stock/${item['id']}/move', {
        'type': type,
        'qty': _num(qtyCtrl.text) ?? 0,
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        'unit_cost': _num(costCtrl.text) ?? 0,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Modal Bahan Baru — nama, kategori, satuan, stok awal, harga per unit,
  /// batas minimum (menyalin web Stock.jsx:258-304).
  Future<void> _addDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    String category = 'Protein';
    String unit = 'kg';
    const categories = ['Protein', 'Bumbu', 'Pokok', 'Pelengkap', 'Lain-lain'];
    const units = ['kg', 'gram', 'liter', 'ml', 'pcs', 'pack'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text('Bahan Baru', style: AppText.display(size: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama Bahan')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration:
                      const InputDecoration(labelText: 'Kategori'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setD(() => category = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                  items: [
                    for (final u in units)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => setD(() => unit = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Stok Awal')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Harga per $unit',
                        prefixText: 'Rp ')),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: minCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Batas Minimum')),
            const SizedBox(height: 8),
            Text(
              'Harga per unit dipakai untuk menilai persediaan & menghitung HPP di laporan Laba Rugi. Stok awal tidak dihitung sebagai pembelian.',
              style: AppText.body(size: 10, color: Colors.black38),
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
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (nameCtrl.text.trim().isEmpty) return;
    try {
      await api.post('/stock', {
        'name': nameCtrl.text.trim(),
        'category': category,
        'unit': unit,
        'qty': _num(qtyCtrl.text) ?? 0,
        'min_qty': _num(minCtrl.text) ?? 0,
        'unit_cost': _num(costCtrl.text) ?? 0,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  static String _fmt(dynamic v) {
    final n = num.tryParse('$v') ?? 0;
    return n % 1 == 0 ? '${n.toInt()}' : '$n';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    }
    final critical = items.where((i) => i['is_low'] == 1 || i['is_low'] == true).length;

    return RefreshIndicator(
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
          Row(children: [
            Expanded(
                child: StatCardRow(
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppColors.char,
                    iconBg: AppColors.char.withValues(alpha: 0.05),
                    value: '${items.length}',
                    label: 'Jenis Bahan')),
            const SizedBox(width: 10),
            Expanded(
                child: StatCardRow(
                    icon: Icons.error_outline,
                    iconColor: AppColors.chili,
                    iconBg: AppColors.redBg,
                    value: '$critical',
                    label: 'Kritis')),
            const SizedBox(width: 10),
            Expanded(
                child: StatCardRow(
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.greenOk,
                    iconBg: AppColors.greenBg,
                    value: '${items.length - critical}',
                    label: 'Aman')),
          ]),
          const SizedBox(height: 20),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(children: [
                    Expanded(
                      child: Text('Daftar Bahan Baku',
                          style: AppText.body(
                              size: 15, weight: FontWeight.w700)),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.chili,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999))),
                      onPressed: _addDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('+ Bahan Baru',
                          style: AppText.body(
                              size: 11,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ]),
                ),
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: const BoxDecoration(border: Border(
                        bottom: BorderSide(color: Color(0x0A000000)))),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: Text('${item['name']}',
                              style: AppText.body(
                                  size: 13, weight: FontWeight.w700)),
                        ),
                        Text(
                            '${item['category']} · ${(_num(item['unit_cost']) ?? 0) > 0 ? '${formatRp(_num(item['unit_cost']) ?? 0)}/${item['unit']}' : 'belum diatur'}',
                            style: AppText.body(
                                size: 11, color: Colors.black38)),
                        const SizedBox(width: 8),
                        StatusChip(
                            item['is_low'] == 1 || item['is_low'] == true
                                ? 'Kritis'
                                : 'Aman',
                            fg: item['is_low'] == 1 || item['is_low'] == true
                                ? AppColors.chili
                                : AppColors.greenOk,
                            bg: item['is_low'] == 1 || item['is_low'] == true
                                ? AppColors.redBg
                                : AppColors.greenBg),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('${_fmt(item['qty'])} ${item['unit']}',
                            style: AppText.body(
                                size: 12, weight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: ((_num(item['qty']) ?? 0) /
                                      ((_num(item['min_qty']) ?? 0) * 2))
                                  .clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.05),
                              color: item['is_low'] == 1 || item['is_low'] == true
                                  ? AppColors.chili
                                  : const Color(0xFF22C55E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('min ${_fmt(item['min_qty'])}',
                            style: AppText.body(
                                size: 11, color: Colors.black45)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _moveDialog(item, 'in'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.char),
                              foregroundColor: AppColors.char,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            ),
                            child: Text('+ Masuk',
                                style: AppText.body(
                                    size: 11, weight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _moveDialog(item, 'out'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color:
                                      AppColors.chili.withValues(alpha: 0.4)),
                              foregroundColor: AppColors.chili,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            ),
                            child: Text('− Keluar',
                                style: AppText.body(
                                    size: 11, weight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _moveDialog(item, 'adjust'),
                            child: Text('Opname',
                                style: AppText.body(
                                    size: 11, weight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text('Pergerakan Terakhir',
                      style:
                          AppText.body(size: 15, weight: FontWeight.w700)),
                ),
                if (movements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child: Text('Belum ada pergerakan stok.',
                            style: AppText.body(
                                size: 12, color: Colors.black26))),
                  ),
                for (final m in movements)
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(
                        m['type'] == 'in'
                            ? Icons.south_west
                            : m['type'] == 'adjust'
                                ? Icons.tune
                                : Icons.north_east,
                        size: 18,
                        color: m['type'] == 'in'
                            ? AppColors.greenOk
                            : m['type'] == 'adjust'
                                ? AppColors.ember
                                : AppColors.chili),
                    title: Text(
                        '${m['item_name']} — ${m['type'] == 'in' ? 'Masuk' : m['type'] == 'adjust' ? 'Opname' : 'Keluar'} ${_fmt(m['qty'])}',
                        style: AppText.body(size: 12, color: Colors.black54)),
                    subtitle: Text(
                        '${m['by_name'] ?? 'Sistem'}${m['note'] != null && m['note'] != '' ? ' · ${m['note']}' : ''}',
                        style:
                            AppText.body(size: 11, color: Colors.black38)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double? _num(dynamic v) => num.tryParse('$v')?.toDouble();
}
