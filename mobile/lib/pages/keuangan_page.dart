import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class KeuanganPage extends StatefulWidget {
  final AppUser user;
  const KeuanganPage({super.key, required this.user});

  @override
  State<KeuanganPage> createState() => _KeuanganPageState();
}

class _KeuanganPageState extends State<KeuanganPage> {
  String range = 'today';
  final List<FinanceTx> txs = List.of(MockData.financeTx);

  static const catLabels = {
    'penjualan': 'Penjualan',
    'void': 'Void Pesanan',
    'belanja': 'Belanja Bahan',
    'gaji': 'Gaji',
    'operasional': 'Operasional',
    'utilitas': 'Utilitas',
    'lain': 'Lain-lain',
  };

  int get income =>
      txs.where((t) => t.type == 'income').fold(0, (s, t) => s + t.amount);
  int get expense =>
      txs.where((t) => t.type == 'expense').fold(0, (s, t) => s + t.amount);
  int get profit => income - expense;

  void _addTx() {
    final amount = TextEditingController();
    final note = TextEditingController();
    String type = 'expense';
    String category = 'operasional';
    showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text('Catat Transaksi Manual',
              style: AppText.display(size: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('Pemasukan'),
                selected: type == 'income',
                showCheckmark: false,
                selectedColor: AppColors.char,
                onSelected: (_) => setD(() => type = 'income'),
              ),
              ChoiceChip(
                label: const Text('Pengeluaran'),
                selected: type == 'expense',
                showCheckmark: false,
                selectedColor: AppColors.char,
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
                  DropdownMenuItem(
                      value: c, child: Text(catLabels[c]!)),
              ],
              onChanged: (v) => setD(() => category = v ?? category),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah (Rp)')),
            const SizedBox(height: 12),
            TextField(
                controller: note,
                decoration:
                    const InputDecoration(labelText: 'Catatan (opsional)')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.chili, elevation: 0),
              onPressed: () {
                setState(() => txs.insert(
                    0,
                    FinanceTx(
                        type,
                        category,
                        int.tryParse(amount.text) ?? 0,
                        note.text.trim(),
                        '2026-09-22')));
                Navigator.pop(d);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
                        color: range == r.$1 ? Colors.white : Colors.black54),
                    onSelected: (_) => setState(() => range = r.$1),
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
                    child: _summary('Pemasukan', formatRp(income),
                        AppColors.greenOk)),
                Expanded(
                    child: _summary(
                        'Pengeluaran', '− ${formatRp(expense)}', AppColors.chili)),
                Expanded(
                    child: _summary('Laba Bersih', formatRp(profit),
                        AppColors.ember)),
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
                      color: t.type == 'income'
                          ? AppColors.greenBg
                          : AppColors.redBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                        t.type == 'income'
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 20,
                        color: t.type == 'income'
                            ? AppColors.greenOk
                            : AppColors.chili),
                  ),
                  title: Text(catLabels[t.category] ?? t.category,
                      style:
                          AppText.body(size: 13, weight: FontWeight.w700)),
                  subtitle: Text('${t.date} · ${t.note}',
                      style:
                          AppText.body(size: 11, color: Colors.black45)),
                  trailing: Text(
                    '${t.type == 'income' ? '+' : '−'} ${formatRp(t.amount)}',
                    style: AppText.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: t.type == 'income'
                            ? AppColors.greenOk
                            : AppColors.chili),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 11, color: Colors.black45)),
          const SizedBox(height: 4),
          Text(value,
              style: AppText.display(size: 17, color: color)),
        ],
      );
}
