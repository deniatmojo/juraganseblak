import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Keuangan — padanan KeuanganLayout web: Ringkasan, Laba Rugi, Arus Kas,
/// Buku Besar, dan Jurnal Umum (endpoint /api/finance/*, owner-only).
class KeuanganPage extends StatefulWidget {
  final AppUser user;
  const KeuanganPage({super.key, required this.user});

  @override
  State<KeuanganPage> createState() => _KeuanganPageState();
}

class _KeuanganPageState extends State<KeuanganPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String range = 'today';
  String? error;

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  late String from;
  late String to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = _dayKey(now);
    to = _dayKey(now);
    _tab = TabController(length: 5, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      _load();
    });
    _load();
  }

  void _applyPreset(String key) {
    final now = DateTime.now();
    setState(() {
      range = key;
      to = _dayKey(now);
      switch (key) {
        case 'week':
          from = _dayKey(now.subtract(const Duration(days: 6)));
          break;
        case 'month':
          from = _dayKey(DateTime(now.year, now.month, 1));
          break;
        case 'lastmonth':
          from = _dayKey(DateTime(now.year, now.month - 1, 1));
          to = _dayKey(DateTime(now.year, now.month, 0));
          break;
        default:
          from = to;
      }
    });
    _load();
  }

  Future<void> _load() async {
    // Data dimuat per-tab oleh halaman masing-masing; tab switch memicu
    // rebuild dan halaman mengambil data sendiri.
    setState(() => error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter rentang
        Container(
          color: AppColors.cream,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final p in [
                ('today', 'Hari Ini'),
                ('week', '7 Hari'),
                ('month', 'Bulan Ini'),
                ('lastmonth', 'Bulan Lalu'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.$2),
                    selected: range == p.$1,
                    showCheckmark: false,
                    selectedColor: AppColors.char,
                    labelStyle: AppText.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color:
                            range == p.$1 ? Colors.white : Colors.black54),
                    onSelected: (_) => _applyPreset(p.$1),
                  ),
                ),
              const SizedBox(width: 4),
              Text('$from s/d $to',
                  style: AppText.body(size: 10, color: Colors.black45)),
            ]),
          ),
        ),
        TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: AppColors.chili,
          unselectedLabelColor: Colors.black45,
          indicatorColor: AppColors.chili,
          labelStyle: AppText.body(size: 12, weight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Laba Rugi'),
            Tab(text: 'Arus Kas'),
            Tab(text: 'Buku Besar'),
            Tab(text: 'Jurnal'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _SummaryTab(from: from, to: to, onReload: _noop),
              _ReportTab(
                  path: '/finance/income-statement',
                  from: from,
                  to: to,
                  builder: _incomeStatement),
              _ReportTab(
                  path: '/finance/cash-flow',
                  from: from,
                  to: to,
                  builder: _cashFlow),
              _LedgerTab(from: from, to: to),
              _ReportTab(
                  path: '/finance/journal',
                  from: from,
                  to: to,
                  builder: _journal),
            ],
          ),
        ),
      ],
    );
  }

  void _noop() {}

  // ---------- Builder tiap laporan ----------

  List<Widget> _incomeStatement(Map<String, dynamic> d) {
    final revenues = (d['revenues'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    final expenses = (d['expenses'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    final inv = Map<String, dynamic>.from(d['inventory'] as Map? ?? {});
    return [
      _repTitle('PENDAPATAN'),
      for (final r in revenues)
        _repRow('${r['label']}', formatRp(r['amount'] ?? 0)),
      _repRow('Total Pendapatan', formatRp(d['revenue_total'] ?? 0), bold: true),
      _repTitle('HARGA POKOK PENJUALAN'),
      _repRow('HPP Resep', formatRp(d['hpp_recipe'] ?? 0)),
      _repRow('HPP Terpakai', formatRp(d['hpp'] ?? 0), bold: true),
      if (inv.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Persediaan: awal ${formatRp(inv['opening'])} + belanja ${formatRp(inv['purchases'])} − akhir ${formatRp(inv['closing'])}',
            style: AppText.body(size: 10, color: Colors.black38),
          ),
        ),
      _repRow('Laba Kotor', formatRp(d['gross_profit'] ?? 0), bold: true),
      _repTitle('BEBAN OPERASIONAL'),
      for (final r in expenses)
        _repRow('${r['label']}', formatRp(r['amount'] ?? 0)),
      _repRow('Total Beban', formatRp(d['expense_total'] ?? 0), bold: true),
      const Divider(),
      _repRow('LABA BERSIH', formatRp(d['net_profit'] ?? 0),
          bold: true,
          color: (num.tryParse('${d['net_profit']}') ?? 0) >= 0
              ? AppColors.greenOk
              : AppColors.chili),
    ];
  }

  List<Widget> _cashFlow(Map<String, dynamic> d) {
    Widget group(String label, Map<String, dynamic> g) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _repTitle(label),
            for (final det in (g['details'] as List? ?? []))
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _repRow(
                    '${det['label']} ${det['kind'] == 'in' ? '↑' : '↓'}',
                    formatRp(det['amount'] ?? 0)),
              ),
            _repRow('Arus kas bersih', formatRp(g['net'] ?? 0), bold: true),
          ],
        );
    return [
      _repRow('Saldo Awal', formatRp(d['opening_balance'] ?? 0), bold: true),
      group('OPERASIONAL', Map<String, dynamic>.from(d['operating'] as Map)),
      group('INVESTASI', Map<String, dynamic>.from(d['investing'] as Map)),
      group('PENDANAAN', Map<String, dynamic>.from(d['financing'] as Map)),
      const Divider(),
      _repRow('Perubahan Bersih', formatRp(d['net_change'] ?? 0)),
      _repRow('SALDO AKHIR', formatRp(d['closing_balance'] ?? 0), bold: true),
    ];
  }

  List<Widget> _journal(Map<String, dynamic> d) {
    final entries = (d['entries'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    return [
      for (final e in entries.take(100))
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Color(0x0A000000)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text('${e['description']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                            size: 12, weight: FontWeight.w600))),
                Text(formatRp(e['amount'] ?? 0),
                    style: AppText.body(
                        size: 12, weight: FontWeight.w700)),
              ]),
              Text('D: ${e['debit_account']}   K: ${e['credit_account']}',
                  style: AppText.body(size: 10, color: Colors.black45)),
            ],
          ),
        ),
      _repRow('Total Debit', formatRp(d['total_debit'] ?? 0), bold: true),
      _repRow('Total Kredit', formatRp(d['total_kredit'] ?? 0), bold: true),
    ];
  }
}

/// Tab Ringkasan — transaksi + catat manual (padanan Keuangan.jsx).
class _SummaryTab extends StatefulWidget {
  final String from, to;
  final VoidCallback onReload;
  const _SummaryTab(
      {required this.from, required this.to, required this.onReload});

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
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
    'modal': 'Modal',
    'lain': 'Lain-lain',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _SummaryTab old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from || old.to != widget.to) _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final data =
          await api.get('/transactions?from=${widget.from}&to=${widget.to}');
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
                    size: 12,
                    weight: FontWeight.w700,
                    color: type == 'income' ? Colors.white : Colors.black54),
                onSelected: (_) => setD(() => type = 'income'),
              ),
              ChoiceChip(
                label: const Text('Pengeluaran'),
                selected: type == 'expense',
                showCheckmark: false,
                selectedColor: AppColors.char,
                labelStyle: AppText.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color:
                        type == 'expense' ? Colors.white : Colors.black54),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (error != null)
          Text(error!,
              style: AppText.body(
                  size: 12, weight: FontWeight.w700, color: AppColors.chili)),
        SectionCard(
          child: Column(children: [
            Row(
              children: [
                Expanded(
                    child: _sum('Pemasukan', formatRp(income), AppColors.greenOk)),
                Expanded(
                    child: _sum(
                        'Pengeluaran', '− ${formatRp(expense)}', AppColors.chili)),
                Expanded(
                    child: _sum('Laba Bersih', formatRp(income - expense),
                        AppColors.ember)),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.chili,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999))),
              onPressed: _addTx,
              icon: const Icon(Icons.add, size: 16),
              label: Text('Catat Transaksi Manual',
                  style: AppText.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final t in txs)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  dense: true,
                  leading: Icon(
                      t['type'] == 'income'
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 18,
                      color: t['type'] == 'income'
                          ? AppColors.greenOk
                          : AppColors.chili),
                  title: Text(catLabels['${t['category']}'] ?? '${t['category']}',
                      style:
                          AppText.body(size: 12, weight: FontWeight.w700)),
                  subtitle: Text(
                      '${t['created_at'] ?? ''}${t['note'] != null && t['note'] != '' ? ' · ${t['note']}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 10, color: Colors.black45)),
                  trailing: Text(
                    '${t['type'] == 'income' ? '+' : '−'} ${formatRp(num.tryParse('${t['amount']}') ?? 0)}',
                    style: AppText.body(
                        size: 12,
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
                        style:
                            AppText.body(size: 12, color: Colors.black26))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sum(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 10, color: Colors.black45)),
          const SizedBox(height: 4),
          Text(value, style: AppText.display(size: 15, color: color)),
        ],
      );
}

/// Tab Buku Besar — pilih akun, tampilkan saldo berjalan.
class _LedgerTab extends StatefulWidget {
  final String from, to;
  const _LedgerTab({required this.from, required this.to});

  @override
  State<_LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<_LedgerTab> {
  List<Map<String, dynamic>> accounts = [];
  String? account;
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final a = await api.get('/finance/accounts');
      if (mounted) {
        setState(() {
          accounts = (a as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          account = accounts.isNotEmpty ? '${accounts.first['key']}' : 'kas';
        });
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant _LedgerTab old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from || old.to != widget.to) _load();
  }

  Future<void> _load() async {
    if (account == null) return;
    setState(() { loading = true; error = null; });
    try {
      final d = await api.get(
          '/finance/ledger?account=$account&from=${widget.from}&to=${widget.to}');
      if (mounted) {
        setState(() {
          data = Map<String, dynamic>.from(d as Map);
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
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    }
    final rows = (data?['rows'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          initialValue: account,
          decoration: const InputDecoration(labelText: 'Akun'),
          items: [
            for (final a in accounts)
              DropdownMenuItem(value: '${a['key']}', child: Text('${a['label']}')),
          ],
          onChanged: (v) {
            setState(() => account = v);
            _load();
          },
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _repRow('Saldo Awal', formatRp(data?['opening'] ?? 0), bold: true),
            for (final r in rows)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0x0A000000)))),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${r['description']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                                size: 12, weight: FontWeight.w600)),
                        Text('${r['date'] ?? ''}',
                            style: AppText.body(
                                size: 9, color: Colors.black38)),
                      ])),
                  SizedBox(
                      width: 90,
                      child: Text(
                          (num.tryParse('${r['debit']}') ?? 0) > 0
                              ? 'D ${formatRp(r['debit'])}'
                              : '',
                          textAlign: TextAlign.right,
                          style: AppText.body(
                              size: 11, color: AppColors.greenOk))),
                  SizedBox(
                      width: 90,
                      child: Text(
                          (num.tryParse('${r['credit']}') ?? 0) > 0
                              ? 'K ${formatRp(r['credit'])}'
                              : '',
                          textAlign: TextAlign.right,
                          style:
                              AppText.body(size: 11, color: AppColors.chili))),
                ]),
              ),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!,
                      style: AppText.body(
                          size: 12, color: AppColors.chili))),
          ],
        ),
      ),
    ]);
  }
}

// ---------- Helper bersama ----------

Widget _repTitle(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(t,
          style: AppText.body(size: 10, weight: FontWeight.w800, color: Colors.black38)),
    );

Widget _repRow(String label, String value,
        {bool bold = false, Color? color}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: AppText.body(
                      size: 12,
                      weight: bold ? FontWeight.w700 : FontWeight.w500))),
          Text(value,
              style: AppText.body(
                  size: bold ? 13 : 12,
                  weight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? AppColors.char)),
        ],
      ),
    );

/// Tab laporan generik: fetch + render lewat builder.
class _ReportTab extends StatefulWidget {
  final String path;
  final String from, to;
  final List<Widget> Function(Map<String, dynamic>) builder;
  const _ReportTab(
      {required this.path,
      required this.from,
      required this.to,
      required this.builder});

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReportTab old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from ||
        old.to != widget.to ||
        old.path != widget.path) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final d = await api
          .get('${widget.path}?from=${widget.from}&to=${widget.to}');
      if (mounted) {
        setState(() {
          data = Map<String, dynamic>.from(d as Map);
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
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    }
    if (error != null) {
      return Center(
          child: Text(error!,
              textAlign: TextAlign.center,
              style: AppText.body(size: 12, color: AppColors.chili)));
    }
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text('${widget.from} s/d ${widget.to}',
            style: AppText.body(size: 10, color: Colors.black38)),
      ),
      ...widget.builder(data!),
      const SizedBox(height: 24),
    ]);
  }
}
