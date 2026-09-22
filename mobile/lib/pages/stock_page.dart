import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StockPage extends StatefulWidget {
  final AppUser user;
  const StockPage({super.key, required this.user});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final List<StockItem> items = List.of(MockData.stock);
  final List<String> movements = [];

  int get critical => items.where((i) => i.isLow).length;

  void _moveDialog(StockItem item, String type) {
    final ctrl = TextEditingController();
    final title = {
      'in': 'Barang Masuk (Restock)',
      'out': 'Barang Keluar (Waste/Pakai)',
      'adjust': 'Set Stok (Stok Opname)',
    }[type]!;
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title, style: AppText.display(size: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${item.name} · sisa ${item.qty} ${item.unit}',
              style: AppText.body(size: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: type == 'adjust' ? 'Jumlah baru (${item.unit})' : 'Jumlah (${item.unit})'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () {
              final v = double.tryParse(ctrl.text) ?? 0;
              setState(() {
                if (type == 'in') {
                  item.qty += v;
                } else if (type == 'out') {
                  item.qty = (item.qty - v).clamp(0, double.infinity);
                } else {
                  item.qty = v;
                }
                movements.insert(
                    0,
                    '${title.split(' ').first} ${item.name}: ${v % 1 == 0 ? v.toInt() : v} ${item.unit}');
                if (movements.length > 10) movements.removeLast();
              });
              Navigator.pop(d);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 2.1,
          children: [
            StatCard(
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.char,
                iconBg: AppColors.char.withValues(alpha: 0.05),
                value: '${items.length}',
                label: 'Total Jenis Bahan'),
            StatCard(
                icon: Icons.error_outline,
                iconColor: AppColors.chili,
                iconBg: AppColors.redBg,
                value: '$critical',
                label: 'Stok Kritis'),
            StatCard(
                icon: Icons.check_circle_outline,
                iconColor: AppColors.greenOk,
                iconBg: AppColors.greenBg,
                value: '${items.length - critical}',
                label: 'Stok Aman'),
          ],
        ),
        const SizedBox(height: 20),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('Daftar Bahan Baku'), Text('')],
                ),
              ),
              for (final item in items)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Color(0x0A000000)))),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: Text(item.name,
                            style: AppText.body(
                                size: 13, weight: FontWeight.w700)),
                      ),
                      StatusChip(
                          item.isLow ? 'Kritis' : 'Aman',
                          fg: item.isLow ? AppColors.chili : AppColors.greenOk,
                          bg: item.isLow ? AppColors.redBg : AppColors.greenBg),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('${item.qty % 1 == 0 ? item.qty.toInt() : item.qty} ${item.unit}',
                          style: AppText.body(
                              size: 12, weight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (item.qty / (item.minQty * 2))
                                .clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.05),
                            color: item.isLow
                                ? AppColors.chili
                                : const Color(0xFF22C55E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('min ${item.minQty % 1 == 0 ? item.minQty.toInt() : item.minQty}',
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
                                color: AppColors.chili
                                    .withValues(alpha: 0.4)),
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
        if (movements.isNotEmpty) ...[
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
                for (final m in movements)
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    leading: const Icon(Icons.swap_vert, size: 18),
                    title: Text(m,
                        style: AppText.body(size: 12, color: Colors.black54)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
