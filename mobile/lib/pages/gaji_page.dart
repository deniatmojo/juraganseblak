import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Gaji & Payroll — GET /payroll?from&to; kasbon POST /employees/:id/kasbon,
/// bayar POST /payroll/pay (tercatat di Keuangan).
class GajiPage extends StatefulWidget {
  final AppUser user;
  const GajiPage({super.key, required this.user});

  @override
  State<GajiPage> createState() => _GajiPageState();
}

class _GajiPageState extends State<GajiPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? error;

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  late String from;
  late String to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = _dayKey(DateTime(now.year, now.month, 1));
    to = _dayKey(now);
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await api.get('/payroll?from=$from&to=$to');
      if (mounted) {
        setState(() => rows = (data as List)
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

  Future<void> _pickDate(bool isFrom) async {
    final initial =
        DateTime.tryParse(isFrom ? from : to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        from = _dayKey(picked);
      } else {
        to = _dayKey(picked);
      }
    });
    _load();
  }

  Future<void> _kasbon(Map<String, dynamic> r) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Kasbon: ${r['name']}', style: AppText.display(size: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: amount,
              autofocus: true,
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
    try {
      await api.post('/employees/${r['id']}/kasbon', {
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

  Future<void> _pay(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Bayar Gaji', style: AppText.display(size: 17)),
        content: Text(
          'Bayar gaji ${r['name']} sebesar ${formatRp(num.tryParse('${r['total']}') ?? 0)} '
          '(${r['days_present']} hari${(num.tryParse('${r['kasbon_open']}') ?? 0) > 0 ? ', dikurangi kasbon ${formatRp(num.tryParse('${r['kasbon_open']}') ?? 0)}' : ''})? '
          'Akan tercatat di Keuangan.',
          style: AppText.body(size: 12, color: Colors.black54),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await api.post('/payroll/pay', {
        'employee_id': r['id'],
        'from': from,
        'to': to,
      });
      await _load();
      if (mounted) {
        final m = Map<String, dynamic>.from(res as Map);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.char,
          content: Text(
              'Gaji ${m['employee']} dibayar: ${formatRp(num.tryParse('${m['total']}') ?? 0)} (${m['days']} hari). Tercatat di Keuangan.',
              style: AppText.body(size: 12, color: Colors.white)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalGaji =
        rows.fold<double>(0, (s, r) => s + (num.tryParse('${r['gaji']}') ?? 0));
    final totalKasbon = rows.fold<double>(
        0, (s, r) => s + (num.tryParse('${r['kasbon_open']}') ?? 0));
    final totalBayar =
        rows.fold<double>(0, (s, r) => s + (num.tryParse('${r['total']}') ?? 0));

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
                _dateField('Dari', from, () => _pickDate(true)),
                const SizedBox(width: 12),
                _dateField('Sampai', to, () => _pickDate(false)),
              ]),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                      child: _sum('Total Gaji', formatRp(totalGaji), AppColors.char)),
                  Expanded(
                      child:
                          _sum('Kasbon', '− ${formatRp(totalKasbon)}', AppColors.chili)),
                  Expanded(
                      child: _sum('Dibayar', formatRp(totalBayar), AppColors.ember)),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rekap Gaji Karyawan',
                          style:
                              AppText.body(size: 15, weight: FontWeight.w700)),
                      Text('$from — $to',
                          style:
                              AppText.body(size: 11, color: Colors.black45)),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${r['name']}',
                                      style: AppText.body(
                                          size: 14,
                                          weight: FontWeight.w700)),
                                  Text(
                                      '${r['posisi'] ?? '—'} · ${r['days_present']} hari hadir · ${r['days_late']} terlambat · ${r['days_off']} izin/sakit',
                                      style: AppText.body(
                                          size: 11, color: Colors.black45)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatRp(num.tryParse('${r['gaji']}') ?? 0),
                                    style: AppText.body(
                                        size: 14, weight: FontWeight.w700)),
                                if ((num.tryParse('${r['kasbon_open']}') ?? 0) > 0)
                                  Text(
                                      '− kasbon ${formatRp(num.tryParse('${r['kasbon_open']}') ?? 0)}',
                                      style: AppText.body(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: AppColors.chili)),
                                Text(
                                    'Dibayar ${formatRp(num.tryParse('${r['total']}') ?? 0)}',
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
                                      borderRadius: BorderRadius.circular(999)),
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999)),
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
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Belum ada data.',
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

  Widget _dateField(String label, String value, VoidCallback onTap) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(labelText: label),
              child: Text(value, style: AppText.body(size: 13)),
            ),
          ),
        );

  Widget _sum(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 11, color: Colors.black45)),
          const SizedBox(height: 4),
          Text(value, style: AppText.display(size: 16, color: color)),
        ],
      );
}
