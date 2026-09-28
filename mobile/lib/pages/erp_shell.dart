import 'dart:async';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import 'dashboard_page.dart';
import 'pos_page.dart';
import 'pesanan_online_page.dart';
import 'menu_page.dart';
import 'absensi_page.dart';
import 'stock_page.dart';
import 'pembayaran_page.dart';
import 'keuangan_page.dart';
import 'karyawan_page.dart';
import 'gaji_page.dart';

class NavEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> roles; // kosong = semua role (matriks AdminLayout.jsx web)
  final Widget page;
  const NavEntry(this.title, this.subtitle, this.icon, this.roles, this.page);
}

/// Kerangka ERP: sidebar drawer gelap + header putih dengan jam hidup,
/// persis pola AdminLayout.jsx di web. Karyawan (kasir) hanya melihat
/// POS & Absensi.
class ErpShell extends StatefulWidget {
  final AppUser user;
  const ErpShell({super.key, required this.user});

  @override
  State<ErpShell> createState() => _ErpShellState();
}

class _ErpShellState extends State<ErpShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late List<NavEntry> entries;
  int index = 0;
  DateTime now = DateTime.now();
  Timer? timer;

  // Notifikasi stok kritis — padanan AdminLayout.jsx:105-130 (refresh 60 dtk).
  List<Map<String, dynamic>> lowStock = [];
  Timer? stockTimer;

  @override
  void initState() {
    super.initState();
    // Matriks menu = navItems di web/src/components/AdminLayout.jsx:
    // owner semua; admin tanpa Keuangan/Karyawan/Gaji; kasir POS+Absensi;
    // karyawan hanya Absensi.
    final entriesAll = <NavEntry>[
      NavEntry('Dashboard', 'Ringkasan operasional hari ini', Icons.home_outlined,
          ['owner', 'admin'], DashboardPage()),
      NavEntry('Kasir / POS', 'Meja 07 · Dine-in', Icons.point_of_sale_outlined,
          ['owner', 'admin', 'kasir'], PosPage(user: widget.user)),
      NavEntry('Pesanan Online', 'ACC pembayaran QRIS & pantau tahap pesanan',
          Icons.shop_two_outlined, ['owner', 'admin', 'kasir'],
          PesananOnlinePage(user: widget.user)),
      NavEntry('Menu', 'Kelola menu, harga, HPP & kategori',
          Icons.restaurant_menu_outlined, ['owner', 'admin'], MenuPage(user: widget.user)),
      NavEntry('Absensi', 'Kehadiran karyawan hari ini',
          Icons.fact_check_outlined, [], AbsensiPage(user: widget.user)),
      NavEntry('Stock', 'Pantau ketersediaan bahan dapur',
          Icons.inventory_2_outlined, ['owner', 'admin'], StockPage(user: widget.user)),
      NavEntry('Pembayaran', 'QRIS & payment gateway', Icons.credit_card_outlined,
          ['owner', 'admin'], PembayaranPage(user: widget.user)),
      NavEntry('Keuangan', 'Pemasukan & pengeluaran outlet',
          Icons.account_balance_wallet_outlined, ['owner'], KeuanganPage(user: widget.user)),
      NavEntry('Karyawan', 'Kelola akun login & data karyawan',
          Icons.people_alt_outlined, ['owner'], KaryawanPage(user: widget.user)),
      NavEntry('Gaji', 'Rekap gaji, kasbon, dan pembayaran',
          Icons.payments_outlined, ['owner'], GajiPage(user: widget.user)),
    ];
    entries = entriesAll
        .where((e) => e.roles.isEmpty || e.roles.contains(widget.user.role))
        .toList();

    // ROLE_HOME web: owner/admin → Dashboard, kasir → POS, karyawan → Absensi.
    final home = switch (widget.user.role) {
      'kasir' => 'Kasir / POS',
      'karyawan' => 'Absensi',
      _ => 'Dashboard',
    };
    index = entries.indexWhere((e) => e.title == home);
    if (index < 0) index = 0;
    timer = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => now = DateTime.now()));
    _loadLowStock();
    stockTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _loadLowStock());
  }

  Future<void> _loadLowStock() async {
    try {
      final items = await api.get('/stock');
      if (mounted) {
        setState(() => lowStock = (items as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .where((i) => i['is_low'] == 1 || i['is_low'] == true)
            .toList());
      }
    } catch (_) {
      // notifikasi bersifat info — gagal load diamkan
    }
  }

  void _showLowStockSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(children: [
              Expanded(
                child: Text('Stok Kritis',
                    style: AppText.body(size: 15, weight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.redBg,
                    borderRadius: BorderRadius.circular(999)),
                child: Text('${lowStock.length} bahan',
                    style: AppText.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.chili)),
              ),
            ]),
          ),
          const Divider(height: 1),
          if (lowStock.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Semua stok aman 👍',
                  style: AppText.body(size: 13, color: Colors.black38)),
            ),
          for (final s in lowStock)
            ListTile(
              title: Text('${s['name']}',
                  style: AppText.body(size: 13, weight: FontWeight.w700)),
              subtitle: Text('min ${s['min_qty']} ${s['unit']}',
                  style: AppText.body(size: 11, color: Colors.black45)),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.redBg,
                    borderRadius: BorderRadius.circular(999)),
                child: Text('${s['qty']} ${s['unit']}',
                    style: AppText.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.chili)),
              ),
            ),
          if (widget.user.role == 'owner')
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.char,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder()),
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  final i =
                      entries.indexWhere((e) => e.title == 'Stock');
                  if (i >= 0) setState(() => index = i);
                },
                child: Text('Kelola Stok',
                    style: AppText.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    stockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = entries[index];
    // Format manual (bukan DateFormat intl) — locale id_ID harus di-init
    // async dan bisa kalah balapan dengan render pertama di release.
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final date =
        '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.cream,
      drawer: _buildDrawer(entry),
      body: Column(
        children: [
          // HEADER
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top, left: 16, right: 8),
            child: SizedBox(
              height: 80,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.char),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(entry.title.toUpperCase(),
                            style: AppText.display(size: 22),
                            overflow: TextOverflow.ellipsis),
                        Text(entry.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 11, color: Colors.black45)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(clock,
                          style: AppText.body(
                              size: 13, weight: FontWeight.w700)),
                      Text(date,
                          style: AppText.body(size: 10, color: Colors.black45)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Lonceng notifikasi stok kritis (AdminLayout.jsx:215-255)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifikasi stok',
                        icon: const Icon(Icons.notifications_outlined,
                            color: AppColors.char),
                        onPressed: _showLowStockSheet,
                      ),
                      if (lowStock.isNotEmpty)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                                color: AppColors.chili,
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: Colors.white, width: 1.5)),
                            child: Text('${lowStock.length}',
                                style: AppText.body(
                                    size: 9,
                                    weight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    backgroundColor: AppColors.chili.withValues(alpha: 0.15),
                    child: Text(widget.user.name[0].toUpperCase(),
                        style: AppText.body(
                            size: 16, weight: FontWeight.w700, color: AppColors.chili)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: entry.page),
        ],
      ),
    );
  }

  Widget _buildDrawer(NavEntry active) {
    Widget navItem(int i) {
      final e = entries[i];
      final isActive = i == index;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: isActive ? AppColors.chili : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() => index = i);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      width: 4,
                      color: isActive ? AppColors.ember : Colors.transparent),
                ),
              ),
              child: Row(children: [
                Icon(e.icon,
                    size: 20,
                    color: isActive
                        ? Colors.white
                        : AppColors.cream.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.title,
                      style: AppText.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : AppColors.cream.withValues(alpha: 0.85))),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: AppColors.char,
      width: 280,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.charLine))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JURAGAN',
                    style: AppText.display(size: 22, color: AppColors.cream)),
                Text('SEBLAK',
                    style: AppText.display(size: 14, color: AppColors.ember)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.chili.withValues(alpha: 0.2),
                child: Text(widget.user.name[0].toUpperCase(),
                    style: AppText.body(
                        size: 16, weight: FontWeight.w700, color: AppColors.chiliLight)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.name,
                        style: AppText.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.cream)),
                    Text(widget.user.roleLabel,
                        style: AppText.body(
                            size: 11,
                            color: AppColors.cream.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [for (int i = 0; i < entries.length; i++) navItem(i)],
            ),
          ),
          const Divider(color: AppColors.charLine, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18, color: AppColors.cream),
                label: Text('Keluar',
                    style: AppText.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.cream)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.charLine),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  authService.logout();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
