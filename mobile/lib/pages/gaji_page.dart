import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../services/pdf_reports.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Gaji & Payroll — menyalin web/src/pages/admin/Gaji.jsx:
/// GET /payroll?from&to, GET /payroll/history (rekap pembayaran + filter
/// tahun/bulan/karyawan), POST /employees/:id/kasbon, POST /payroll/pay,
/// banner sukses dengan "Unduh Slip Gaji (PDF)".
class GajiPage extends StatefulWidget {
  final AppUser user;
  const GajiPage({super.key, required this.user});

  @override
  State<GajiPage> createState() => _GajiPageState();
}

class _GajiPageState extends State<GajiPage> {
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> history = [];
  bool loading = true;
  String? error;
  Map<String, dynamic>? justPaid;
  bool exportingSlip = false;

  // Filter rekap riwayat pembayaran (web Gaji.jsx:109-112)
  int histYear = DateTime.now().year;
  int? histMonth; // null = semua bulan
  int? histEmp; // null = semua karyawan

  static const months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

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
    _loadHistory();
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

  Future<void> _loadHistory() async {
    final q = StringBuffer('year=$histYear');
    if (histMonth != null) q.write('&month=$histMonth');
    if (histEmp != null) q.write('&employee_id=$histEmp');
    try {
      final data = await api.get('/payroll/history?$q');
      if (mounted) {
        setState(() => history = (data as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => history = []);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial =
        DateTime.tryParse(isFrom ? from : to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
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
        title: Text('Catat Kasbon', style: AppText.display(size: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r['name']} — dipotong dari gaji berikutnya.',
              style: AppText.body(size: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah (Rp)')),
          const SizedBox(height: 10),
          TextField(
              controller: note,
              decoration:
                  const InputDecoration(labelText: 'Keterangan')),
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

  /// Konfirmasi bayar — rincian sama seperti web Gaji.jsx:341-359.
  Future<void> _pay(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Bayar Gaji', style: AppText.display(size: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r['name']} — periode $from s/d $to',
              style: AppText.body(size: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          _payRow('${r['days_present']} hari × ${formatRp(num.tryParse('${r['daily_rate']}') ?? 0)}',
              formatRp(num.tryParse('${r['gaji']}') ?? 0)),
          _payRow('Kasbon belum lunas',
              '− ${formatRp(num.tryParse('${r['kasbon_open']}') ?? 0)}'),
          const Divider(),
          _payRow('Pending Bayar',
              formatRp(num.tryParse('${r['pending']}') ?? 0)),
          const SizedBox(height: 8),
          Text(
              'Setelah dibayar: tercatat di Keuangan, masuk rekap pembayaran, dan slip gaji (PDF) bisa diunduh.',
              style: AppText.body(size: 10, color: Colors.black38)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Bayar & Catat'),
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
      setState(() => justPaid = Map<String, dynamic>.from(res as Map));
      await _load();
      await _loadHistory();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _slipPdf() async {
    if (justPaid == null) return;
    setState(() => exportingSlip = true);
    try {
      await shareSlipGajiPdf(justPaid!);
    } finally {
      if (mounted) setState(() => exportingSlip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalGaji =
        rows.fold<double>(0, (s, r) => s + (num.tryParse('${r['gaji']}') ?? 0));
    final totalKasbon = rows.fold<double>(
        0, (s, r) => s + (num.tryParse('${r['kasbon_open']}') ?? 0));
    final totalPending = rows.fold<double>(
        0, (s, r) => s + (num.tryParse('${r['pending']}') ?? 0).clamp(0, double.infinity));

    final histTotal = history.fold<double>(
        0, (s, h) => s + (num.tryParse('${h['total']}') ?? 0));
    final histGaji = history.fold<double>(
        0, (s, h) => s + (num.tryParse('${h['gaji']}') ?? 0));
    final histKasbon = history.fold<double>(
        0, (s, h) => s + (num.tryParse('${h['kasbon']}') ?? 0));
    final histDays = history.fold<int>(
        0, (s, h) => s + (int.tryParse('${h['days']}') ?? 0));
    final years =
        List<int>.generate(5, (i) => DateTime.now().year - i);

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
                      child: _sum('Pending Bayar', formatRp(totalPending),
                          AppColors.ember)),
                ],
              ),
            ]),
          ),
          // ---- Banner sukses bayar → slip PDF (web Gaji.jsx:181-198) ----
          if (justPaid != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.char,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: const Color(0x3350C878),
                        borderRadius: BorderRadius.circular(999)),
                    child: const Icon(Icons.check,
                        color: Color(0xFF4ADE80), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Gaji ${justPaid!['employee']} dibayar',
                        style: AppText.display(size: 15, color: AppColors.cream)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                    onPressed: () => setState(() => justPaid = null),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  '${formatRp(num.tryParse('${justPaid!['total']}') ?? 0)} — periode ${justPaid!['from']} s/d ${justPaid!['to']} (${justPaid!['days']} hari${(num.tryParse('${justPaid!['kasbon']}') ?? 0) > 0 ? ', dikurangi kasbon ${formatRp(num.tryParse('${justPaid!['kasbon']}') ?? 0)}' : ''}). Tercatat di Keuangan & rekap di bawah.',
                  style: AppText.body(size: 11, color: AppColors.cream.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.chili,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44)),
                  onPressed: exportingSlip ? null : _slipPdf,
                  icon: exportingSlip
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: Text('Unduh Slip Gaji (PDF)',
                      style: AppText.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ]),
            ),
          ],
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
                                      '${r['posisi'] ?? '—'} · ${r['days_present']} hadir · ${r['days_late']} terlambat · ${r['days_off']} izin/sakit',
                                      style: AppText.body(
                                          size: 11, color: Colors.black45)),
                                  Text(
                                      'Tarif ${num.tryParse('${r['daily_rate']}') != null && num.tryParse('${r['daily_rate']}')! > 0 ? formatRp(num.tryParse('${r['daily_rate']}')!) : '—'} · Pending ${num.tryParse('${r['pending']}') != null && num.tryParse('${r['pending']}')! > 0 ? formatRp(num.tryParse('${r['pending']}')!) : 'Lunas ✓'}',
                                      style: AppText.body(
                                          size: 11,
                                          color: AppColors.ember)),
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
                            if ((num.tryParse('${r['pending']}') ?? 0) > 0)
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: () => _pay(r),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.char,
                                    elevation: 0,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(999)),
                                  ),
                                  child: Text('Bayar',
                                      style: AppText.body(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: Colors.white)),
                                ),
                              )
                            else
                              const Spacer(),
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
          const SizedBox(height: 20),
          // ---- Rekap Pembayaran Gaji (web Gaji.jsx:255-319) ----
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rekap Pembayaran Gaji',
                            style: AppText.body(
                                size: 15, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            'Riwayat gaji yang sudah dibayar — bisa difilter per tahun, bulan, atau karyawan.',
                            style: AppText.body(
                                size: 11, color: Colors.black45)),
                      ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: histYear,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Tahun',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: [
                          for (final y in years)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => histYear = v);
                          _loadHistory();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: histMonth,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Semua Bulan',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Semua Bulan')),
                          for (var i = 0; i < months.length; i++)
                            DropdownMenuItem(
                                value: i + 1, child: Text(months[i])),
                        ],
                        onChanged: (v) {
                          setState(() => histMonth = v);
                          _loadHistory();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: histEmp,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Semua Karyawan',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Semua Karyawan')),
                          for (final r in rows)
                            DropdownMenuItem(
                                value: int.tryParse('${r['id']}'),
                                child: Text('${r['name']}',
                                    overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          setState(() => histEmp = v);
                          _loadHistory();
                        },
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                for (final h in history)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Color(0x0A000000)))),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${h['name']}',
                                  style: AppText.body(
                                      size: 13, weight: FontWeight.w700)),
                              Text(
                                  '${h['paid_at'] ?? ''} · ${h['posisi'] ?? '—'} · ${h['periode_from']} — ${h['periode_to']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                      size: 10, color: Colors.black45)),
                              Text(
                                  '${h['days']} hari · Gaji ${formatRp(num.tryParse('${h['gaji']}') ?? 0)}${(num.tryParse('${h['kasbon']}') ?? 0) > 0 ? ' · Kasbon −${formatRp(num.tryParse('${h['kasbon']}') ?? 0)}' : ''}',
                                  style: AppText.body(
                                      size: 11, color: Colors.black54)),
                            ]),
                      ),
                      Text(
                          formatRp(num.tryParse('${h['total']}') ?? 0),
                          style: AppText.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppColors.ember)),
                    ]),
                  ),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Belum ada pembayaran pada filter ini.',
                        style: AppText.body(
                            size: 12, color: Colors.black26)),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    color: AppColors.cream,
                    child: Text(
                        'Total (${history.length} pembayaran) — $histDays hari · Gaji ${formatRp(histGaji)}${histKasbon > 0 ? ' · Kasbon −${formatRp(histKasbon)}' : ''} · Dibayarkan ${formatRp(histTotal)}',
                        style: AppText.body(
                            size: 11, weight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _payRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label, style: AppText.body(size: 12, color: Colors.black54))),
          Text(value, style: AppText.body(size: 12, weight: FontWeight.w700)),
        ]),
      );

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
