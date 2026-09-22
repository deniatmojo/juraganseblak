import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Keuangan — GET /transactions?from&to, catat manual POST /transactions.
class KeuanganPage extends StatefulWidget {
  final AppUser user;
  const KeuanganPage({super.key, required this.user});

  @override
  State<KeuanganPage> createState() => _KeuanganPageState();
}

class _KeuanganPageState extends State<KeuanganPage> {
  String range = 'today';
  List<Map<String, dynamic>> txs = [];
  bool loading = true;
  String? error;

  static const catLabels = {
    'penjualan': 'Penjualan',
    'void': 'Void Pesanan',
    'belanja': 'Belanja Bahan',
    'gaji': 'Gaji',
    'operasional': 'Operasional',
    'utilitas': 'Utilitas',
    'lain': 'Lain-lain',
  };

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (String, String) _rangeFor(String key) {
    final now = DateTime.now();
    final to = _dayKey(now);
    String from = to;
    if (key == 'week') from = _dayKey(now.subtract(const Duration(days: 6)));
    if (key == 'month') from = _dayKey(now.subtract(const Duration(days: 29)));
    return (from, to);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    final (from, to) = _rangeFor(range);
    try {
      final data = await api.get('/transactions?from=$from&to=$to');
      if (mounted) {
        setState(() => txs = (data as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addTx() async {
    final amount = TextEditingController();
    final note = TextEditingController();
    String type = 'expense';
    String category = 'operasional';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title:
              Text('Catat Transaksi Manual', style: AppText.display(size: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('Pemasukan'),
                selected: type == 'income',
                showCheckmark: false,
                selectedColor: AppColors.char,
                labelStyle: AppText.body(
                    size: 12, weight: FontWeight.w700,
                    color: type == 'income' ? Colors.white : Colors.black54),
                onSelected: (_) => setD(() => type = 'income'),
              ),
              ChoiceChip(
                label: const Text('Pengeluaran'),
                selected: type == 'expense',
                showCheckmark: false,
                selectedColor: AppColors.char,
                labelStyle: AppText.body(
                    size: 12, weight: FontWeight.w700,
                    color: type == 'expense' ? Colors.white : Colors.black54),
                onSelected: (_) => setD(() => type = 'expense'),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final c in catLabels.keys
                    .where((k) => k != 'penjualan' && k != 'void'))
                  DropdownMenuItem(value: c, child: Text(catLabels[c]!)),
              ],
              onChanged: (v) => setD(() => category = v ?? category),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Jumlah (Rp)')),
            const SizedBox(height: 12),
            TextField(
                controller: note,
                decoration:
                    const InputDecoration(labelText: 'Catatan (opsional)')),
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
      await api.post('/transactions', {
        'type': type,
        'category': category,
        'amount': num.tryParse(amount.text) ?? 0,
        'note': note.text.trim().isEmpty ? null : note.text.trim(),
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final income = txs
        .where((t) => t['type'] == 'income')
        .fold<double>(0, (s, t) => s + (num.tryParse('${t['amount']}') ?? 0));
    final expense = txs
        .where((t) => t['type'] == 'expense')
        .fold<double>(0, (s, t) => s + (num.tryParse('${t['amount']}') ?? 0));

    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    }

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
          SectionCard(
            child: Column(children: [
              Row(children: [
                for (final r in [
                  ('today', 'Hari Ini'),
                  ('week', 'Minggu Ini'),
                  ('month', 'Bulan Ini'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.$2),
                      selected: range == r.$1,
                      showCheckmark: false,
                      selectedColor: AppColors.char,
                      labelStyle: AppText.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color:
                              range == r.$1 ? Colors.white : Colors.black54),
                      onSelected: (_) {
                        setState(() => range = r.$1);
                        _load();
                      },
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.chili,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999))),
                  onPressed: _addTx,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Catat Manual',
                      style: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                      child: _summary(
                          'Pemasukan', formatRp(income), AppColors.greenOk)),
                  Expanded(
                      child: _summary('Pengeluaran',
                          '− ${formatRp(expense)}', AppColors.chili)),
                  Expanded(
                      child: _summary(
                          'Laba Bersih', formatRp(income - expense), AppColors.ember)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text('Daftar Transaksi',
                      style:
                          AppText.body(size: 15, weight: FontWeight.w700)),
                ),
                for (final t in txs)
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t['type'] == 'income'
                            ? AppColors.greenBg
                            : AppColors.redBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                          t['type'] == 'income'
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 20,
                          color: t['type'] == 'income'
                              ? AppColors.greenOk
                              : AppColors.chili),
                    ),
                    title: Text(
                        catLabels['${t['category']}'] ?? '${t['category']}',
                        style:
                            AppText.body(size: 13, weight: FontWeight.w700)),
                    subtitle: Text(
                        '${t['created_at'] ?? ''}${t['note'] != null && t['note'] != '' ? ' · ${t['note']}' : ''}',
                        style:
                            AppText.body(size: 11, color: Colors.black45)),
                    trailing: Text(
                      '${t['type'] == 'income' ? '+' : '−'} ${formatRp(num.tryParse('${t['amount']}') ?? 0)}',
                      style: AppText.body(
                          size: 13,
                          weight: FontWeight.w700,
                          color: t['type'] == 'income'
                              ? AppColors.greenOk
                              : AppColors.chili),
                    ),
                  ),
                if (txs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Belum ada transaksi di periode ini.',
                        style: AppText.body(
                            size: 13, color: Colors.black26)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 11, color: Colors.black45)),
          const SizedBox(height: 4),
          Text(value, style: AppText.display(size: 17, color: color)),
        ],
      );
}
