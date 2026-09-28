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

/// Satu item notifikasi pada lonceng header.
class _Notif {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final int count;
  final String? routeTitle; // halaman tujuan bila tersedia untuk role ini

  const _Notif({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.count,
    this.routeTitle,
  });
}

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

  // Pusat notifikasi role-aware — lonceng header (AdminLayout web, diperluas
  // sesuai permintaan): stok kritis semua role, pesanan online owner/admin/
  // kasir, absensi, dan keuangan (kasbon/gaji pending) HANYA owner.
  List<_Notif> notifs = [];
  Timer? notifTimer;

  @override
  void initState() {
    super.initState();
    // Matriks menu = navItems di web/src/components/AdminLayout.jsx:
    // owner semua; admin tanpa Keuangan/Karyawan/Gaji; kasir POS+Absensi;
    // karyawan hanya Absensi.
    final entriesAll = <NavEntry>[
      NavEntry('Dashboard', 'Ringkasan operasional hari ini', Icons.home_outlined,
          ['owner', 'admin'], DashboardPage()),
      NavEntry('Kasir / POS', 'Kasir ${widget.user.name}', Icons.point_of_sale_outlined,
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
    _loadNotifications();
    notifTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _loadNotifications());
  }

  int _notifTotal() => notifs.fold(0, (s, n) => s + n.count);

  Future<void> _loadNotifications() async {
    final list = await _fetchNotifications();
    if (mounted) setState(() => notifs = list);
  }

  Future<List<_Notif>> _fetchNotifications() async {
    final role = widget.user.role;
    final n = DateTime.now();
    final two = (int v) => v.toString().padLeft(2, '0');
    final today = '${n.year}-${two(n.month)}-${two(n.day)}';
    final monthStart = '${n.year}-${two(n.month)}-01';
    final list = <_Notif>[];

    // 1) Stok kritis — semua role (sama seperti lonceng web).
    try {
      final items = await api.get('/stock');
      final low = (items as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .where((i) => i['is_low'] == 1 || i['is_low'] == true)
          .toList();
      if (low.isNotEmpty) {
        list.add(_Notif(
          icon: Icons.inventory_2_outlined,
          color: AppColors.chili,
          title: 'Stok kritis: ${low.length} bahan',
          detail: low
              .take(3)
              .map((s) => '${s['name']} (${s['qty']} ${s['unit']})')
              .join(', ') + (low.length > 3 ? ', …' : ''),
          count: low.length,
          routeTitle: (role == 'owner' || role == 'admin') ? 'Stock' : null,
        ));
      }
    } catch (_) {}

    // 2) Pesanan online — owner/admin/kasir (bukan keuangan, tapi operasional).
    if (role == 'owner' || role == 'admin' || role == 'kasir') {
      try {
        final rows = (await api.get('/orders') as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .where((o) => o['channel'] == 'online')
            .toList();
        final pending =
            rows.where((o) => o['status'] == 'pending').length;
        final queue = rows
            .where((o) => o['status'] == 'paid' && o['progress'] != 'done')
            .length;
        if (pending > 0) {
          list.add(_Notif(
            icon: Icons.shop_two_outlined,
            color: AppColors.ember,
            title: 'Pesanan online menunggu ACC: $pending',
            detail: 'Cek rekening/QRIS lalu ACC agar pesanan masuk antrian.',
            count: pending,
            routeTitle: 'Pesanan Online',
          ));
        }
        if (queue > 0) {
          list.add(_Notif(
            icon: Icons.schedule,
            color: AppColors.char,
            title: 'Antrian online belum selesai: $queue',
            detail: 'Proses sampai siap/diantar, lalu tandai selesai.',
            count: queue,
            routeTitle: 'Pesanan Online',
          ));
        }
      } catch (_) {}
    }

    // 3) Absensi — owner/admin: karyawan belum absen; kasir/karyawan: diri sendiri.
    try {
      final rows = (await api.get('/attendance?date=$today') as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      if (role == 'owner' || role == 'admin') {
        final belum = rows
            .where((r) => r['clock_in'] == null && r['status'] == null)
            .length;
        if (belum > 0) {
          list.add(_Notif(
            icon: Icons.fact_check_outlined,
            color: AppColors.ember,
            title: '$belum karyawan belum absen masuk',
            detail: 'Kehadiran hari ini belum lengkap.',
            count: belum,
            routeTitle: 'Absensi',
          ));
        }
      } else if (rows.isNotEmpty) {
        final me = rows.first;
        if (me['clock_in'] == null) {
          list.add(_Notif(
            icon: Icons.fact_check_outlined,
            color: AppColors.ember,
            title: 'Kamu belum clock in hari ini',
            detail: 'Absen masuk agar tercatat di rekap absensi.',
            count: 1,
            routeTitle: 'Absensi',
          ));
        }
      }
    } catch (_) {}

    // 4) Keuangan (kasbon & pending gaji bulan ini) — HANYA owner.
    if (role == 'owner') {
      try {
        final rows = (await api.get('/payroll?from=$monthStart&to=$today') as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final kasbon = rows.fold<num>(
            0, (s, r) => s + (num.tryParse('${r['kasbon_open']}') ?? 0));
        final pendingPay = rows.fold<num>(
            0, (s, r) => s + (num.tryParse('${r['pending']}') ?? 0));
        if (kasbon > 0 || pendingPay > 0) {
          list.add(_Notif(
            icon: Icons.payments_outlined,
            color: AppColors.chili,
            title: 'Kasbon & pending gaji menunggu',
            detail:
                'Kasbon belum lunas ${formatRp(kasbon)} · Pending bayar ${formatRp(pendingPay)} (bulan ini).',
            count: 1,
            routeTitle: 'Gaji',
          ));
        }
      } catch (_) {}
    }
    return list;
  }

  void _showNotifSheet() {
    _loadNotifications();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Row(children: [
              Expanded(
                child: Text('Notifikasi',
                    style: AppText.body(size: 15, weight: FontWeight.w700)),
              ),
              if (notifs.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.redBg,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('${_notifTotal()} item',
                      style: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: AppColors.chili)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sesuai hak akses role ${widget.user.roleLabel}.',
                style: AppText.body(size: 10, color: Colors.black38),
              ),
            ),
          ),
          const Divider(height: 1),
          if (notifs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Tidak ada notifikasi 👍',
                  style: AppText.body(size: 13, color: Colors.black38)),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final n in notifs)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n.color.withValues(alpha: 0.12),
                      child: Icon(n.icon, size: 20, color: n.color),
                    ),
                    title: Text(n.title,
                        style: AppText.body(
                            size: 13, weight: FontWeight.w700)),
                    subtitle: Text(n.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.body(size: 11, color: Colors.black45)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: n.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('${n.count}',
                            style: AppText.body(
                                size: 11,
                                weight: FontWeight.w800,
                                color: n.color)),
                      ),
                      if (n.routeTitle != null &&
                          entries.any((e) => e.title == n.routeTitle))
                        const Icon(Icons.chevron_right,
                            size: 18, color: Colors.black26),
                    ]),
                    onTap: n.routeTitle == null
                        ? null
                        : () {
                            final i = entries
                                .indexWhere((e) => e.title == n.routeTitle);
                            if (i < 0) return;
                            Navigator.pop(sheetCtx);
                            setState(() => index = i);
                          },
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    notifTimer?.cancel();
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
                  // Lonceng notifikasi role-aware
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifikasi',
                        icon: const Icon(Icons.notifications_outlined,
                            color: AppColors.char),
                        onPressed: _showNotifSheet,
                      ),
                      if (_notifTotal() > 0)
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
                            child: Text('${_notifTotal()}',
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
