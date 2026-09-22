import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Dashboard — statistik dihitung dari GET /orders + /products,
/// padanan logika Dashboard.jsx web.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  String? error;
  double incomeToday = 0;
  int ordersToday = 0;
  int activeMenu = 0;
  int monthCount = 0;
  List<int> weekly = [];
  List<(String, String, String, double, String)> recent = [];

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final results =
          await Future.wait([api.get('/orders'), api.get('/products')]);
      final orders = (results[0] as List)
          .map((o) => Map<String, dynamic>.from(o as Map))
          .toList();
      final products = results[1] as List;
      final paid =
          orders.where((o) => o['status'] == 'paid').toList();
      final todays = paid
          .where((o) => _s(o['created_at']).substring(0, 10) == _today)
          .toList();
      final monthPrefix = _today.substring(0, 7);

      final days = <int>[];
      for (int i = 6; i >= 0; i--) {
        final d = DateTime.now().subtract(Duration(days: i));
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        days.add(paid
            .where((o) => _s(o['created_at']).startsWith(key))
            .fold<double>(0, (s, o) => s + _num(o['total']))
            .round());
      }

      if (mounted) {
        setState(() {
          incomeToday =
              todays.fold<double>(0, (s, o) => s + _num(o['total']));
          ordersToday = todays.length;
          activeMenu = products.length;
          monthCount = paid
              .where((o) => _s(o['created_at']).startsWith(monthPrefix))
              .length;
          weekly = days;
          recent = paid.take(5).map((o) {
            return (
              '${o['order_no']}',
              '${o['customer_name'] ?? 'Umum'}'.isEmpty
                  ? 'Umum'
                  : '${o['customer_name'] ?? 'Umum'}',
              o['channel'] == 'online' ? 'Online' : 'Dine-in',
              _num(o['total']),
              '${o['status']}' == 'paid' ? 'Lunas' : 'Pending',
            );
          }).toList();
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

  static String _s(dynamic v) => '$v';
  static double _num(dynamic v) =>
      (num.tryParse('$v') ?? 0).toDouble();

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    }
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!, style: AppText.body(size: 13, color: AppColors.chili)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Coba lagi')),
        ]),
      );
    }

    final cards = [
      (
        Icons.payments_outlined,
        AppColors.chili,
        AppColors.chili.withValues(alpha: 0.1),
        formatRp(incomeToday),
        'Total Pendapatan Hari Ini'
      ),
      (
        Icons.receipt_long_outlined,
        AppColors.ember,
        AppColors.ember.withValues(alpha: 0.1),
        '$ordersToday Pesanan',
        'Total Pesanan Hari Ini'
      ),
      (
        Icons.restaurant_menu,
        AppColors.chili,
        AppColors.redBg,
        '$activeMenu Item',
        'Item Menu Aktif'
      ),
      (
        Icons.group_outlined,
        AppColors.char,
        AppColors.char.withValues(alpha: 0.05),
        '$monthCount Transaksi',
        'Transaksi Bulan Ini'
      ),
    ];

    return RefreshIndicator(
      color: AppColors.chili,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 640 ? 4 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.05,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final c in cards)
                StatCard(
                    icon: c.$1,
                    iconColor: c.$2,
                    iconBg: c.$3,
                    value: c.$4,
                    label: c.$5,
                    badge: 'Live'),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tren Penjualan Mingguan',
                            style: AppText.body(
                                size: 15, weight: FontWeight.w700)),
                        Text('7 hari terakhir',
                            style:
                                AppText.body(size: 11, color: Colors.black45)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.char,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text('Rp',
                          style: AppText.body(
                              size: 11,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                    height: 220, child: _WeeklyChart(weekly)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transaksi Terakhir',
                          style: AppText.body(
                              size: 15, weight: FontWeight.w700)),
                      Text('Lihat: menu Keuangan',
                          style: AppText.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: AppColors.chili)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (final t in recent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: const BoxDecoration(border: Border(
                        bottom: BorderSide(color: Color(0x0A000000)))),
                    child: Row(children: [
                      Expanded(
                          flex: 2,
                          child: Text(t.$1,
                              style: AppText.body(
                                  size: 13, weight: FontWeight.w600))),
                      Expanded(
                          flex: 2,
                          child: Text(t.$2, style: AppText.body(size: 13))),
                      Expanded(
                          child: Text(t.$3,
                              style: AppText.body(
                                  size: 12, color: Colors.black45))),
                      Expanded(
                          child: Text(formatRp(t.$4),
                              style: AppText.body(
                                  size: 13, weight: FontWeight.w600))),
                      t.$5 == 'Lunas'
                          ? StatusChip.ok('Lunas')
                          : StatusChip.warn('Pending'),
                    ]),
                  ),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Belum ada transaksi.',
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
}

/// Grafik garis sederhana pengganti Chart.js (garis chili + titik ember).
class _WeeklyChart extends StatelessWidget {
  final List<int> data;
  const _WeeklyChart(this.data);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ChartPainter(data), size: Size.infinite);
  }
}

class _ChartPainter extends CustomPainter {
  final List<int> data;
  _ChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final w = size.width - 24;
    final h = size.height - 30;
    final max = (data.reduce((a, b) => a > b ? a : b) * 1.15)
        .clamp(1.0, double.infinity);

    final grid = Paint()
      ..color = const Color(0xFFF1EAE1)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = i * h / 4;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), grid);
    }

    final pts = <Offset>[
      for (int i = 0; i < data.length; i++)
        Offset(12 + i * w / (data.length - 1), h - (data[i] / max) * h),
    ];

    final path = Path()..addPolygon(pts, false);
    final fill = Path.from(path)
      ..lineTo(12 + w, h)
      ..lineTo(12, h)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x40C81E1E), Color(0x00C81E1E)])
              .createShader(Rect.fromLTWH(0, 0, size.width, h)));
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.chili
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    for (final p in pts) {
      canvas.drawCircle(p, 5, Paint()..color = AppColors.ember);
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3, Paint()..color = AppColors.ember);
    }

    const labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < data.length && i < labels.length; i++) {
      tp.text = TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 10, color: Colors.black45));
      tp.layout();
      tp.paint(canvas, Offset(12 + i * w / (data.length - 1) - tp.width / 2, h + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.data != data;
}
