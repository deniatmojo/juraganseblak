import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GajiPage extends StatefulWidget {
  final AppUser user;
  const GajiPage({super.key, required this.user});

  @override
  State<GajiPage> createState() => _GajiPageState();
}

class _GajiPageState extends State<GajiPage> {
  late List<PayrollRow> rows;

  @override
  void initState() {
    super.initState();
    rows = MockData.payroll(MockData.employees);
  }

  int get totalGaji => rows.fold(0, (s, r) => s + r.gaji);
  int get totalKasbon => rows.fold(0, (s, r) => s + r.kasbonOpen);
  int get totalBayar => rows.fold(0, (s, r) => s + r.total);

  void _pay(PayrollRow r) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Bayar Gaji', style: AppText.display(size: 17)),
        content: Text(
          'Bayar gaji ${r.employee.name} sebesar ${formatRp(r.total)} '
          '(${r.daysPresent} hari${r.kasbonOpen > 0 ? ', dikurangi kasbon ${formatRp(r.kasbonOpen)}' : ''})? '
          'Akan tercatat di Keuangan.',
          style: AppText.body(size: 12, color: Colors.black54),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () {
              setState(() => r.kasbonOpen = 0);
              Navigator.pop(d);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AppColors.char,
                content: Text(
                    'Gaji ${r.employee.name} dibayar: ${formatRp(r.total)}',
                    style: AppText.body(size: 12, color: Colors.white)),
              ));
            },
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
  }

  void _kasbon(PayrollRow r) {
    final amount = TextEditingController();
    final note = TextEditingController();
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title:
            Text('Kasbon: ${r.employee.name}', style: AppText.display(size: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah (Rp)')),
          const SizedBox(height: 10),
          TextField(
              controller: note,
              decoration:
                  const InputDecoration(labelText: 'Catatan (opsional)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () {
              setState(() =>
                  r.kasbonOpen += int.tryParse(amount.text) ?? 0);
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
        SectionCard(
          child: Row(
            children: [
              Expanded(
                  child: _sum('Total Gaji', formatRp(totalGaji), AppColors.char)),
              Expanded(
                  child: _sum('Kasbon', '− ${formatRp(totalKasbon)}', AppColors.chili)),
              Expanded(
                  child: _sum('Dibayar', formatRp(totalBayar), AppColors.ember)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Rekap Gaji Karyawan',
                        style:
                            AppText.body(size: 15, weight: FontWeight.w700)),
                    Text('1 — 22 Sep 2026',
                        style: AppText.body(size: 11, color: Colors.black45)),
                  ],
                ),
              ),
              for (final r in rows)
                Column(
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(r.employee.name,
                                    style: AppText.body(
                                        size: 14,
                                        weight: FontWeight.w700)),
                                Text(
                                    '${r.employee.position} · ${r.daysPresent} hari hadir · ${r.daysLate} terlambat · ${r.daysOff} izin/sakit',
                                    style: AppText.body(
                                        size: 11, color: Colors.black45)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatRp(r.gaji),
                                  style: AppText.body(
                                      size: 14,
                                      weight: FontWeight.w700)),
                              if (r.kasbonOpen > 0)
                                Text('− kasbon ${formatRp(r.kasbonOpen)}',
                                    style: AppText.body(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: AppColors.chili)),
                              Text(
                                  'Dibayar ${formatRp(r.total)}',
                                  style: AppText.body(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: AppColors.ember)),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _kasbon(r),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: AppColors.chili
                                        .withValues(alpha: 0.4)),
                                foregroundColor: AppColors.chili,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(999)),
                              ),
                              child: Text('+ Kasbon',
                                  style: AppText.body(
                                      size: 11, weight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () => _pay(r),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.chili,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(999)),
                              ),
                              child: Text('Bayar Gaji',
                                  style: AppText.body(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sum(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 11, color: Colors.black45)),
          const SizedBox(height: 4),
          Text(value, style: AppText.display(size: 16, color: color)),
        ],
      );
}
