import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth_service.dart';
import '../theme.dart';
import 'dashboard_page.dart';
import 'pos_page.dart';
import 'menu_page.dart';
import 'absensi_page.dart';
import 'stock_page.dart';
import 'keuangan_page.dart';
import 'karyawan_page.dart';
import 'gaji_page.dart';

class NavEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool ownerOnly;
  final Widget page;
  const NavEntry(this.title, this.subtitle, this.icon, this.ownerOnly, this.page);
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
  late List<NavEntry> entries;
  int index = 0;
  DateTime now = DateTime.now();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    entries = [
      NavEntry('Dashboard', 'Ringkasan operasional hari ini', Icons.home_outlined,
          true, DashboardPage()),
      NavEntry('Kasir / POS', 'Meja 07 · Dine-in', Icons.point_of_sale_outlined,
          false, PosPage(user: widget.user)),
      NavEntry('Menu', 'Kelola menu, harga, HPP & kategori',
          Icons.restaurant_menu_outlined, true, MenuPage(user: widget.user)),
      NavEntry('Absensi', 'Kehadiran karyawan hari ini',
          Icons.fact_check_outlined, false, AbsensiPage(user: widget.user)),
      NavEntry('Stock', 'Pantau ketersediaan bahan dapur',
          Icons.inventory_2_outlined, true, StockPage(user: widget.user)),
      NavEntry('Keuangan', 'Pemasukan & pengeluaran outlet',
          Icons.account_balance_wallet_outlined, true, KeuanganPage(user: widget.user)),
      NavEntry('Karyawan', 'Kelola akun login & data karyawan',
          Icons.people_alt_outlined, true, KaryawanPage(user: widget.user)),
      NavEntry('Gaji', 'Rekap gaji, kasbon, dan pembayaran',
          Icons.payments_outlined, true, GajiPage(user: widget.user)),
    ].where((e) => !e.ownerOnly || widget.user.isOwner).toList();

    if (!widget.user.isOwner) {
      // Kasir langsung dibuka di POS (ROLE_HOME web: /erp/pos).
      index = entries.indexWhere((e) => e.title.contains('POS'));
    }
    timer = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => now = DateTime.now()));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = entries[index];
    final clock = DateFormat.Hms('id_ID').format(now);
    final date = DateFormat('EEEE, d MMMM y', 'id_ID').format(now);

    return Scaffold(
      backgroundColor: AppColors.cream,
      endDrawer: _buildDrawer(entry),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(entry.title.toUpperCase(),
                            style: AppText.display(size: 22),
                            overflow: TextOverflow.ellipsis),
                        Text(entry.subtitle,
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
                  CircleAvatar(
                    backgroundColor: AppColors.chili.withValues(alpha: 0.15),
                    child: Text(widget.user.name[0].toUpperCase(),
                        style: AppText.body(
                            size: 16, weight: FontWeight.w700, color: AppColors.chili)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.char),
                    onPressed: () =>
                        Scaffold.of(context).openEndDrawer(),
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
                    Text(
                        widget.user.isOwner ? 'Super Admin' : 'Karyawan',
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
