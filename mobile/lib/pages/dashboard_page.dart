import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DashboardPage extends StatelessWidget {
  final AppUser user;
  const DashboardPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final income = MockData.recentOrders
        .where((t) => t.status == 'Lunas')
        .fold<int>(0, (s, t) => s + t.total);
    final cards = [
      (
        Icons.payments_outlined,
        AppColors.chili,
        AppColors.chili.withValues(alpha: 0.1),
        formatRp(income),
        'Total Pendapatan Hari Ini'
      ),
      (
        Icons.receipt_long_outlined,
        AppColors.ember,
        AppColors.ember.withValues(alpha: 0.1),
        '${MockData.recentOrders.length} Pesanan',
        'Total Pesanan Hari Ini'
      ),
      (
        Icons.restaurant_menu,
        AppColors.chili,
        AppColors.redBg,
        '${MockData.menu.length} Item',
        'Item Menu Aktif'
      ),
      (
        Icons.group_outlined,
        AppColors.char,
        AppColors.char.withValues(alpha: 0.05),
        '128 Transaksi',
        'Transaksi Bulan Ini'
      ),
    ];

    return ListView(
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SectionCard(
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
                                style: AppText.body(
                                    size: 11, color: Colors.black45)),
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
                        height: 220, child: _WeeklyChart(MockData.weekly)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.char,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INFO',
                        style: AppText.body(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppColors.ember)),
                    const SizedBox(height: 6),
                    Text('DATA LANGSUNG',
                        style: AppText.display(size: 20, color: AppColors.cream)),
                    const SizedBox(height: 14),
                    Text(
                      'Grafik & kartu di samping diambil dari transaksi nyata. (Tahap 1: data contoh — koneksi server menyusul.)',
                      style: AppText.body(
                          size: 12,
                          color: AppColors.cream.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                        style:
                            AppText.body(size: 15, weight: FontWeight.w700)),
                    Text('Lihat semua',
                        style: AppText.body(
                            size: 12, weight: FontWeight.w700, color: AppColors.chili)),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final t in MockData.recentOrders)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0x0A000000)))),
                  child: Row(children: [
                    Expanded(
                        flex: 2,
                        child: Text(t.id,
                            style: AppText.body(size: 13, weight: FontWeight.w600))),
                    Expanded(
                        flex: 2,
                        child: Text(t.customer, style: AppText.body(size: 13))),
                    Expanded(
                        child: Text(t.type,
                            style: AppText.body(size: 12, color: Colors.black45))),
                    Expanded(
                        child: Text(formatRp(t.total),
                            style: AppText.body(
                                size: 13, weight: FontWeight.w600))),
                    t.status == 'Lunas'
                        ? StatusChip.ok('Lunas')
                        : StatusChip.warn('Pending'),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Grafik garis sederhana pengganti Chart.js (garis chili + titik ember).
class _WeeklyChart extends StatelessWidget {
  final List<int> data;
  const _WeeklyChart(this.data);

  static const labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

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
    final w = size.width - 24;
    final h = size.height - 30;
    final max = data.reduce((a, b) => a > b ? a : b) * 1.15;

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
      canvas.drawCircle(
          p, 5, Paint()..color = AppColors.ember);
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          3,
          Paint()
            ..color = AppColors.ember
            ..style = PaintingStyle.fill);
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < _WeeklyChart.labels.length; i++) {
      tp.text = TextSpan(
          text: _WeeklyChart.labels[i],
          style: TextStyle(fontSize: 10, color: Colors.black45));
      tp.layout();
      tp.paint(canvas,
          Offset(12 + i * w / 6 - tp.width / 2, h + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.data != data;
}
