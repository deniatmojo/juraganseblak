import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Absensi — menyalin web/src/pages/admin/Absensi.jsx + CabangManager.jsx:
/// clock in/out GPS, rekap pribadi (karyawan) vs semua (admin), set status,
/// Pengaturan Jadwal Kerja owner (jam masuk via ClockDial + durasi), dan
/// kelola Lokasi Absen per Cabang (link Google Maps + "Lokasi saya").
class AbsensiPage extends StatefulWidget {
  final AppUser user;
  const AbsensiPage({super.key, required this.user});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  bool busy = false;
  String? error;

  bool get isOwner => widget.user.role == 'owner';
  bool get isBoss => widget.user.isAdmin;

  // Rentang tanggal rekap/detail (web: preset today/week/month/lastmonth)
  String empPreset = 'today';
  late String empFrom;
  late String empTo;
  List<Map<String, dynamic>> empRecap = [];

  // Rekap pribadi (non-boss) — default "Hari Ini" seperti web.
  String myPreset = 'today';
  List<Map<String, dynamic>> myRecords = [];

  // Pengaturan jadwal (owner) — GET /employees
  List<Map<String, dynamic>> schedule = [];
  final Set<int> _dirtySchedule = {};
  int? savingId;

  String get _today {
    final n = DateTime.now();
    return _dayKey(n);
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _singleDay => empFrom == empTo;

  @override
  void initState() {
    super.initState();
    empFrom = _today;
    empTo = _today;
    _load();
  }

  void _applyRange(String key, {bool mine = false}) {
    final now = DateTime.now();
    String f = _today, t = _today;
    switch (key) {
      case 'week':
        f = _dayKey(now.subtract(const Duration(days: 6)));
        break;
      case 'month':
        f = _dayKey(DateTime(now.year, now.month, 1));
        break;
      case 'lastmonth':
        f = _dayKey(DateTime(now.year, now.month - 1, 1));
        t = _dayKey(DateTime(now.year, now.month, 0));
        break;
      default:
        f = _today;
    }
    setState(() {
      if (mine) {
        myPreset = key;
      } else {
        empPreset = key;
        empFrom = f;
        empTo = t;
      }
    });
    if (mine) {
      _loadMyRecap();
    } else {
      _loadAttendance();
    }
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    await _loadAttendance();
    if (mounted) setState(() => loading = false);
    _loadSchedule();
    _loadMyRecap();
  }

  Future<void> _loadAttendance() async {
    try {
      if (isBoss && !_singleDay) {
        final data =
            await api.get('/attendance/recap?from=$empFrom&to=$empTo');
        if (mounted) {
          final m = Map<String, dynamic>.from(data as Map);
          setState(() => empRecap = (m['employees'] as List? ?? [])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList());
        }
      } else {
        final data = await api.get('/attendance?date=$empFrom');
        if (mounted) {
          setState(() => rows = (data as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _loadMyRecap() async {
    if (isBoss) return;
    final now = DateTime.now();
    String f = _today, t = _today;
    switch (myPreset) {
      case 'week':
        f = _dayKey(now.subtract(const Duration(days: 6)));
        break;
      case 'month':
        f = _dayKey(DateTime(now.year, now.month, 1));
        break;
      case 'lastmonth':
        f = _dayKey(DateTime(now.year, now.month - 1, 1));
        t = _dayKey(DateTime(now.year, now.month, 0));
        break;
      default:
        f = _today;
    }
    try {
      final data = await api.get('/attendance/recap?from=$f&to=$t');
      if (mounted) {
        final m = Map<String, dynamic>.from(data as Map);
        setState(() => myRecords = (m['records'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList());
      }
    } catch (_) {
      // rekap pribadi gagal diamkan — bagian info
    }
  }

  Future<void> _loadSchedule() async {
    if (!isOwner) return;
    try {
      final data = await api.get('/employees');
      if (mounted) {
        setState(() => schedule = (data as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList());
      }
    } catch (_) {}
  }

  Map<String, dynamic>? get _myRow {
    final uid = widget.user.id;
    return rows.where((r) => r['user_id'] == uid).firstOrNull;
  }

  // GPS — absen hanya sah dalam radius titik cabang.
  Future<Position> _position() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak — izinkan akses lokasi untuk absen.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception(
          'Akses lokasi diblok permanen. Buka pengaturan aplikasi > Izin > Lokasi.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Layanan lokasi (GPS) sedang mati — nyalakan dulu.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
  }

  Future<void> _clock(bool isIn) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final pos = await _position();
      final res = await api.post('/attendance/${isIn ? 'clock-in' : 'clock-out'}', {
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
      final dist = res is Map ? res['distance_m'] : null;
      final branch = res is Map ? res['branch_name'] : null;
      await _loadAttendance();
      if (dist is num && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.char,
          content: Text(
            'Tercatat — ${dist.round()} m dari ${branch ?? 'cabang'}.',
            style: AppText.body(size: 12, weight: FontWeight.w600, color: Colors.white),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _statusDialog(Map<String, dynamic> r) async {
    final note = TextEditingController(text: r['note'] ?? '');
    String status = '${r['status'] ?? 'izin'}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text('Set Absensi', style: AppText.display(size: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['name']} — $empFrom',
                style: AppText.body(size: 12, color: Colors.black54)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in ['hadir', 'terlambat', 'izin', 'sakit', 'alpa'])
                  ChoiceChip(
                    label: Text(_label(s)),
                    selected: status == s,
                    showCheckmark: false,
                    selectedColor: AppColors.char,
                    labelStyle: AppText.body(
                        size: 11,
                        weight: FontWeight.w600,
                        color: status == s ? Colors.white : Colors.black54),
                    onSelected: (_) => setD(() => status = s),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
                controller: note,
                decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'mis. Acara keluarga')),
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
      await api.patch('/attendance/status', {
        'employee_id': r['employee_id'],
        'work_date': empFrom,
        'status': status,
        'note': note.text.trim().isEmpty ? null : note.text.trim(),
      });
      await _loadAttendance();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ---- Pengaturan jadwal (owner) — web Absensi.jsx:369-385 ----
  Future<void> _saveSchedule(Map<String, dynamic> s, String? shiftStart, num? workHours) async {
    setState(() => savingId = int.tryParse('${s['id']}'));
    try {
      await api.patch('/employees/${s['id']}', {
        'shift_start': shiftStart,
        'work_hours': workHours ?? 8,
      });
      _dirtySchedule.remove(int.tryParse('${s['id']}'));
      await Future.wait([_loadSchedule(), _loadAttendance()]);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => savingId = null);
    }
  }

  /// ClockDial — picker jam berputar (web Absensi.jsx:64-147):
  /// langkah 1 jam (0–23), langkah 2 menit (kelipatan 5).
  Future<void> _openClockDial(Map<String, dynamic> s) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ClockDialDialog(
        name: '${s['name']}',
        initial: '${s['shift_start'] ?? ''}',
      ),
    );
    if (result == null) return; // ditutup tanpa mengubah
    _dirtySchedule.add(int.tryParse('${s['id']}') ?? 0);
    setState(() {
      schedule = schedule
          .map((x) => x['id'] == s['id']
              ? (Map<String, dynamic>.from(x)..['shift_start'] = result)
              : x)
          .toList();
    });
  }

  String _label(String s) => {
        'hadir': 'Hadir',
        'terlambat': 'Terlambat',
        'izin': 'Izin',
        'sakit': 'Sakit',
        'alpa': 'Tanpa Ket.',
      }[s] ?? s;

  String _fmtTime(dynamic dt) {
    final s = '$dt';
    if (s.length < 16) return '—';
    return s.substring(11, 16);
  }

  StatusChip _chip(String? status) {
    switch (status) {
      case 'hadir':
        return StatusChip.ok('Hadir');
      case 'terlambat':
        return StatusChip.warn('Terlambat');
      case 'izin':
      case 'sakit':
        return StatusChip.warn(_label(status!));
      case 'alpa':
        return StatusChip.danger('Tanpa Ket.');
      default:
        return StatusChip('Belum',
            fg: Colors.black45, bg: Colors.black.withValues(alpha: 0.05));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hadir = rows
        .where((r) => r['status'] == 'hadir' || r['status'] == 'terlambat')
        .length;
    final izin = rows
        .where((r) => r['status'] == 'izin' || r['status'] == 'sakit')
        .length;
    final alpa =
        rows.where((r) => r['status'] == 'alpa' || r['status'] == null).length;
    final me = _myRow;
    final myStatus = !widget.user.isOwner && me == null
        ? 'Akun belum terhubung ke data karyawan — hubungi admin.'
        : me == null
            ? 'Belum absen masuk hari ini'
            : me['clock_in'] == null
                ? 'Belum absen masuk hari ini'
                : me['clock_out'] != null
                    ? 'Selesai — masuk ${_fmtTime(me['clock_in'])}, keluar ${_fmtTime(me['clock_out'])}'
                    : 'Absen masuk pukul ${_fmtTime(me['clock_in'])}'
                        '${me['est_clock_out'] != null ? ' — keluar otomatis ~${me['est_clock_out']}' : ''}';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Absen Saya',
                    style: AppText.body(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(myStatus,
                    style: AppText.body(size: 12, color: Colors.black45)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.chili))
                          : const Icon(Icons.login, size: 18),
                      label: Text('Clock In',
                          style: AppText.body(
                              size: 13, weight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.chili),
                        foregroundColor: AppColors.chili,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: () => _clock(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text('Clock Out',
                          style: AppText.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.char,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: () => _clock(false),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // ---- Rekap pribadi (karyawan biasa) — web Absensi.jsx:437 ----
          if (!isBoss) ...[
            const SizedBox(height: 20),
            _myRecapSection(),
          ],
          if (isBoss) ...[
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: StatCardRow(
                      icon: Icons.check_circle_outline,
                      iconColor: AppColors.greenOk,
                      iconBg: AppColors.greenBg,
                      value: '$hadir',
                      label: 'Hadir')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatCardRow(
                      icon: Icons.schedule,
                      iconColor: AppColors.ember,
                      iconBg: AppColors.ember.withValues(alpha: 0.1),
                      value: '$izin',
                      label: 'Izin/Sakit')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatCardRow(
                      icon: Icons.cancel_outlined,
                      iconColor: AppColors.chili,
                      iconBg: AppColors.redBg,
                      value: '$alpa',
                      label: 'Alpa')),
            ]),
            // ---- Lokasi Absen per Cabang (owner) ----
            if (isOwner) ...[
              const SizedBox(height: 20),
              _CabangManagerSection(
                onError: (msg) => setState(() => error = msg),
              ),
            ],
            // ---- Pengaturan Jadwal Kerja (owner) — web Absensi.jsx:460-537 ----
            if (isOwner) ...[
              const SizedBox(height: 20),
              _scheduleSection(),
            ],
            const SizedBox(height: 20),
            // ---- Rekap semua karyawan (web Absensi.jsx:540-647) ----
            _empRecapSection(),
          ],
          const SizedBox(height: 20),
          if (isBoss && _singleDay)
            SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text('Kehadiran Hari Ini',
                        style:
                            AppText.body(size: 15, weight: FontWeight.w700)),
                  ),
                  for (final r in rows)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.chili.withValues(alpha: 0.12),
                        child: Text('${r['name']}'.isNotEmpty
                            ? '${r['name']}'.substring(0, 1)
                            : '?',
                            style: AppText.body(
                                size: 14,
                                weight: FontWeight.w700,
                                color: AppColors.chili)),
                      ),
                      title: Text('${r['name']}',
                          style: AppText.body(
                              size: 13, weight: FontWeight.w700)),
                      subtitle: Text(
                        '${r['shift_start'] != null ? 'Jadwal ${r['shift_start']} · ' : ''}'
                        'Masuk ${_fmtTime(r['clock_in'])} · Keluar ${_fmtTime(r['clock_out'])}'
                        '${r['est_clock_out'] != null && r['clock_out'] == null && r['clock_in'] != null ? ' (estimasi ${r['est_clock_out']})' : ''}'
                        '${r['note'] != null && r['note'] != '' ? ' · ${r['note']}' : ''}',
                        style:
                            AppText.body(size: 11, color: Colors.black45),
                      ),
                      trailing: widget.user.isAdmin
                          ? TextButton(
                              onPressed: () => _statusDialog(r),
                              child: Text('Set Status',
                                  style: AppText.body(
                                      size: 11, weight: FontWeight.w700)),
                            )
                          : _chip(r['status'] as String?),
                    ),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Belum ada data karyawan.',
                          style: AppText.body(size: 12, color: Colors.black26)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Section Rekap pribadi (web Absensi.jsx:182-286 personal) ----------
  Widget _myRecapSection() {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rekap Absensi Saya',
            style: AppText.body(size: 15, weight: FontWeight.w700)),
        Text('Riwayat absensi pribadi Anda.',
            style: AppText.body(size: 11, color: Colors.black45)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final p in [
              ('today', 'Hari Ini'),
              ('week', '7 Hari Terakhir'),
              ('month', 'Bulan Ini'),
              ('lastmonth', 'Bulan Lalu'),
            ])
              ChoiceChip(
                label: Text(p.$2),
                selected: myPreset == p.$1,
                showCheckmark: false,
                selectedColor: AppColors.char,
                labelStyle: AppText.body(
                    size: 10,
                    weight: FontWeight.w700,
                    color:
                        myPreset == p.$1 ? Colors.white : Colors.black54),
                onSelected: (_) => _applyRange(p.$1, mine: true),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final r in myRecords)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${r['tanggal'] ?? r['work_date'] ?? ''}',
                style: AppText.body(size: 12, weight: FontWeight.w700)),
            subtitle: Text(
                'Masuk ${r['clock_in'] ?? '—'} · Keluar ${r['clock_out'] ?? '—'}'
                '${r['note'] != null && r['note'] != '' ? ' · ${r['note']}' : ''}',
                style: AppText.body(size: 11, color: Colors.black45)),
            trailing: _chip(r['status'] as String?),
          ),
        if (myRecords.isEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada absensi pada rentang ini.',
                  style: AppText.body(size: 12, color: Colors.black26))),
      ]),
    );
  }

  // ---------- Section Pengaturan Jadwal (owner) ----------
  Widget _scheduleSection() {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pengaturan Jadwal Kerja',
            style: AppText.body(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Atur jam masuk (format 24 jam) & durasi kerja tiap karyawan. Absen keluar tercatat otomatis saat durasi kerja terlewati.',
          style: AppText.body(size: 11, color: Colors.black45),
        ),
        const SizedBox(height: 10),
        for (final s in schedule)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: AppColors.cream,
                  radius: 16,
                  child: Text('${s['name']}'.isNotEmpty
                      ? '${s['name']}'.substring(0, 1)
                      : '?',
                      style: AppText.display(size: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['name']}',
                            style: AppText.body(
                                size: 13, weight: FontWeight.w700)),
                        Text('${s['role'] ?? '—'}',
                            style: AppText.body(
                                size: 11, color: Colors.black45)),
                      ]),
                ),
                // Estimasi keluar + badge AUTO
                if ('${s['shift_start'] ?? ''}'.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.ember.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      '${_addHours('${s['shift_start']}', num.tryParse('${s['work_hours']}') ?? 8)} AUTO',
                      style: AppText.body(
                          size: 10,
                          weight: FontWeight.w700,
                          color: AppColors.ember),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                // Tombol jam masuk → ClockDial
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black12),
                        foregroundColor: AppColors.char,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => _openClockDial(s),
                    icon: const Icon(Icons.access_time,
                        size: 16, color: AppColors.chili),
                    label: Text(
                        '${s['shift_start'] == null || '${s['shift_start']}'.isEmpty || '${s['shift_start']}' == 'null' ? '--:--' : s['shift_start']}'
                        '  ·  ${num.tryParse('${s['work_hours']}') ?? 8} jam',
                        style: AppText.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.char)),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.char,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  onPressed: !_dirtySchedule
                          .contains(int.tryParse('${s['id']}'))
                      ? null
                      : () => _saveSchedule(
                          s,
                          '${s['shift_start'] ?? ''}'.isEmpty ||
                                  '${s['shift_start']}' == 'null'
                              ? null
                              : '${s['shift_start']}',
                          num.tryParse('${s['work_hours']}')),
                  child: Text(
                      savingId == int.tryParse('${s['id']}')
                          ? 'Menyimpan...'
                          : 'Simpan',
                      style: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ]),
            ]),
          ),
        if (schedule.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Belum ada data karyawan.',
                style: AppText.body(size: 12, color: Colors.black26)),
          ),
      ]),
    );
  }

  // ---------- Section Rekap semua karyawan ----------
  Widget _empRecapSection() {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rekap Absensi Semua Karyawan',
            style: AppText.body(size: 15, weight: FontWeight.w700)),
        Text(
          _singleDay
              ? 'Detail absensi per karyawan — ${empFrom.split('-').reversed.join('/')}'
              : 'Hitungan kehadiran ${empFrom.split('-').reversed.join('/')} s/d ${empTo.split('-').reversed.join('/')}',
          style: AppText.body(size: 11, color: Colors.black45),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final p in [
              ('today', 'Hari Ini'),
              ('week', '7 Hari Terakhir'),
              ('month', 'Bulan Ini'),
              ('lastmonth', 'Bulan Lalu'),
            ])
              ChoiceChip(
                label: Text(p.$2),
                selected: empPreset == p.$1,
                showCheckmark: false,
                selectedColor: AppColors.char,
                labelStyle: AppText.body(
                    size: 10,
                    weight: FontWeight.w700,
                    color:
                        empPreset == p.$1 ? Colors.white : Colors.black54),
                onSelected: (_) => _applyRange(p.$1),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_singleDay)
          for (final r in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: CircleAvatar(
                backgroundColor: AppColors.cream,
                radius: 16,
                child: Text('${r['name']}'.isNotEmpty
                    ? '${r['name']}'.substring(0, 1)
                    : '?',
                    style: AppText.display(size: 13)),
              ),
              title: Text('${r['name']}',
                  style: AppText.body(size: 12, weight: FontWeight.w700)),
              subtitle: Text(
                  '${r['posisi'] ?? '—'} · Masuk ${_fmtTime(r['clock_in'])} · Keluar ${_fmtTime(r['clock_out'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 11, color: Colors.black45)),
              trailing: _chip(r['status'] as String?),
            )
        else
          for (final r in empRecap)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                                size: 12, weight: FontWeight.w700)),
                        Text(
                            '${r['posisi'] ?? '—'} · H ${r['hadir']} · T ${r['terlambat']} · Iz ${r['izin']} · Sa ${r['sakit']} · A ${r['alpa']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                                size: 10, color: Colors.black45)),
                      ]),
                ),
                StatusChip.ok('${r['tercatat']} hari'),
              ]),
            ),
        if ((_singleDay && rows.isEmpty) || (!_singleDay && empRecap.isEmpty))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada data.',
                  style: AppText.body(size: 12, color: Colors.black26))),
      ]),
    );
  }

  /// shift '09:00' + 8 jam → '17:00' (web Absensi.jsx:9-16)
  static String _addHours(String hhmm, num hours) {
    if (hhmm.isEmpty || hhmm == 'null') return '--:--';
    final parts = hhmm.split(':');
    if (parts.length < 2) return '--:--';
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final total = h * 60 + m + (hours * 60).round();
    final hh = ((total ~/ 60) % 24).toString().padLeft(2, '0');
    final mm = (total % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

// ============================================================================
// CLOCK DIAL — picker jam berputar 24 jam (web Absensi.jsx:64-147)
// ============================================================================
class _ClockDialDialog extends StatefulWidget {
  final String name;
  final String initial;

  const _ClockDialDialog({required this.name, required this.initial});

  @override
  State<_ClockDialDialog> createState() => _ClockDialDialogState();
}

class _ClockDialDialogState extends State<_ClockDialDialog> {
  int? hour;
  int? minute;
  bool stepHour = true;

  static const size = 260.0;
  static const center = size / 2;
  static const radius = 104.0;

  @override
  void initState() {
    super.initState();
    final parts = widget.initial.split(':');
    if (parts.isNotEmpty) {
      hour = int.tryParse(parts[0]);
      if (parts.length > 1) minute = int.tryParse(parts[1]);
    }
    stepHour = hour == null;
  }

  List<int> get values {
    if (stepHour) return List<int>.generate(24, (i) => i);
    return List<int>.generate(12, (i) => i * 5);
  }

  int get max => stepHour ? 24 : 60;
  int? get current => stepHour ? hour : minute;

  void _pick(int v) {
    if (stepHour) {
      setState(() { hour = v; stepHour = false; });
    } else {
      final hh = (hour ?? 0).toString().padLeft(2, '0');
      final mm = v.toString().padLeft(2, '0');
      Navigator.pop(context, '$hh:$mm');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Atur Jam Masuk', style: AppText.display(size: 17)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.name,
            style: AppText.body(size: 12, color: Colors.black45)),
        const SizedBox(height: 12),
        // HH : MM — klik untuk pindah langkah
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _hmtile(hour, true),
          Text(':', style: AppText.display(size: 24, color: Colors.black26)),
          _hmtile(minute, false),
        ]),
        const SizedBox(height: 6),
        Text(
          stepHour
              ? 'Pilih jam (0–23) pada pukul berputar'
              : 'Pilih menit (kelipatan 5)',
          style: AppText.body(size: 10, color: Colors.black38),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: size,
          height: size,
          child: GestureDetector(
            onTapUp: (d) {
              final local = d.localPosition;
              final dx = local.dx - center;
              final dy = local.dy - center;
              if (math.sqrt(dx * dx + dy * dy) > radius + 24) return;
              var ang = math.atan2(dy, dx) + math.pi / 2;
              if (ang < 0) ang += math.pi * 2;
              var v = ((ang / (math.pi * 2)) * max).round() % max;
              // jam 0 vs 23: nilai tepat di batas
              if (!stepHour) v = (v ~/ 5) * 5;
              _pick(v);
            },
            child: CustomPaint(
              painter: _DialPainter(
                values: values,
                max: max,
                current: current,
                stepHour: stepHour,
              ),
            ),
          ),
        ),
      ]),
      actions: [
        if (widget.initial.isNotEmpty && widget.initial != 'null')
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text('Hapus',
                style: AppText.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.chili)),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.char, elevation: 0),
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  Widget _hmtile(int? v, bool isHour) {
    final active = stepHour == isHour;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => stepHour = isHour),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
            color: active ? AppColors.chili : AppColors.cream,
            borderRadius: BorderRadius.circular(14)),
        child: Text(
            v == null ? '––' : v.toString().padLeft(2, '0'),
            style: AppText.display(
                size: 30, color: active ? Colors.white : Colors.black54)),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final List<int> values;
  final int max;
  final int? current;
  final bool stepHour;

  _DialPainter(
      {required this.values, required this.max, this.current, required this.stepHour});

  @override
  void paint(Canvas canvas, Size size) {
    const c = _ClockDialDialogState.center;
    const r = _ClockDialDialogState.radius;
    // Lingkaran latar
    canvas.drawCircle(
        const Offset(c, c),
        r + 18,
        Paint()..color = const Color(0xFFFAF3EC));
    // Jarum
    if (current != null) {
      final ang = (current! / max) * math.pi * 2 - math.pi / 2;
      final p = Offset(c + r * math.cos(ang), c + r * math.sin(ang));
      final needle = Paint()
        ..color = AppColors.chili
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(c, c), p, needle);
      canvas.drawCircle(const Offset(c, c), 6, Paint()..color = AppColors.chili);
      canvas.drawCircle(p, 14, Paint()..color = AppColors.chili);
    }
    // Angka
    for (final v in values) {
      final ang = (v / max) * math.pi * 2 - math.pi / 2;
      final p = Offset(c + r * math.cos(ang), c + r * math.sin(ang));
      final active = current == v;
      canvas.drawCircle(
          p,
          active ? 15 : 13,
          Paint()
            ..color = active ? AppColors.chili : Colors.white);
      canvas.drawCircle(
          p,
          active ? 15 : 13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x2216110F));
      final tp = TextPainter(
        text: TextSpan(
            text: v.toString().padLeft(2, '0'),
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? Colors.white : const Color(0xB016110F))),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.current != current || old.max != max || old.values != values;
}

// ============================================================================
// KELOLA LOKASI CABANG — Super Admin only (web CabangManager.jsx)
// ============================================================================

/// Ambil lat/lng dari URL Google Maps yang di-paste (web CabangManager.jsx:12-28).
Map<String, String>? parseMapsUrl(String text) {
  if (text.isEmpty) return null;
  final s = text.trim();
  final m34 = RegExp(r'!3d(-?\d+(?:\.\d+))!4d(-?\d+(?:\.\d+))').firstMatch(s);
  if (m34 != null) return {'lat': m34.group(1)!, 'lng': m34.group(2)!};
  final mq = RegExp(
          r'[?&](?:q|query|destination)=(-?\d+(?:\.\d+))\s*,\s*(-?\d+(?:\.\d+))')
      .firstMatch(s);
  if (mq != null) return {'lat': mq.group(1)!, 'lng': mq.group(2)!};
  final mAt =
      RegExp(r'@(-?\d+(?:\.\d+))\s*,\s*(-?\d+(?:\.\d+))').firstMatch(s);
  if (mAt != null) return {'lat': mAt.group(1)!, 'lng': mAt.group(2)!};
  final m2 = RegExp(r'^(-?\d{1,3}(?:\.\d+))\s*,\s*(-?\d{1,3}(?:\.\d+))$')
      .firstMatch(s);
  if (m2 != null) return {'lat': m2.group(1)!, 'lng': m2.group(2)!};
  return null;
}

class _CabangManagerSection extends StatefulWidget {
  final void Function(String) onError;

  const _CabangManagerSection({required this.onError});

  @override
  State<_CabangManagerSection> createState() => _CabangManagerSectionState();
}

class _CabangManagerSectionState extends State<_CabangManagerSection> {
  List<Map<String, dynamic>> list = [];
  Map<String, dynamic>? editing; // cabang yang sedang diedit

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await api.get('/branches');
      if (mounted) {
        setState(() => list = (data as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList());
      }
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _startEdit(Map<String, dynamic> b) => setState(() => editing = b);

  Future<void> _deactivate(Map<String, dynamic> b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(
            'Nonaktifkan cabang "${b['name']}"? Karyawan yang masih ditugaskan ke sini tidak akan bisa absen sampai dipindahkan.',
            style: AppText.body(size: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.del('/branches/${b['id']}');
      await _load();
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BranchFormSheet(initial: editing),
    );
    if (saved == true) {
      setState(() => editing = null);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lokasi Absen per Cabang',
            style: AppText.body(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Tetapkan titik koordinat tiap cabang (ambil dari Google Maps). Karyawan hanya bisa absen bila berada dalam radius titik cabangnya.',
          style: AppText.body(size: 11, color: Colors.black45),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.chili,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(44)),
              onPressed: () {
                setState(() => editing = null);
                _openForm();
              },
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text('Tambah Cabang Baru',
                  style: AppText.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        for (final b in list)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${b['name']}',
                                style: AppText.body(
                                    size: 13, weight: FontWeight.w700)),
                            if (b['address'] != null &&
                                '${b['address']}'.isNotEmpty)
                              Text('${b['address']}',
                                  style: AppText.body(
                                      size: 11, color: Colors.black45)),
                          ]),
                    ),
                    (b['is_active'] == 1 || b['is_active'] == true)
                        ? StatusChip.ok('Aktif')
                        : StatusChip('Nonaktif',
                            fg: Colors.black45,
                            bg: Colors.black.withValues(alpha: 0.05)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    '${b['lat']}, ${b['lng']} · radius ${b['radius_m']} m · ${b['employee_count'] ?? 0} karyawan',
                    style: AppText.body(size: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact),
                      onPressed: () => launchUrl(Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${b['lat']},${b['lng']}'),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.map_outlined,
                          size: 14, color: AppColors.chili),
                      label: Text('Lihat di Maps',
                          style: AppText.body(
                              size: 11,
                              weight: FontWeight.w700,
                              color: AppColors.chili)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _startEdit(b),
                      child: Text('Edit',
                          style: AppText.body(
                              size: 11,
                              weight: FontWeight.w700,
                              color: Colors.black54)),
                    ),
                    if (b['is_active'] == 1 || b['is_active'] == true)
                      TextButton(
                        onPressed: () => _deactivate(b),
                        child: Text('Nonaktifkan',
                            style: AppText.body(
                                size: 11,
                                weight: FontWeight.w700,
                                color: Colors.black54)),
                      ),
                  ]),
                ]),
          ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Belum ada cabang. Tambahkan lokasi pertama di atas.',
                style: AppText.body(size: 12, color: Colors.black26)),
          ),
      ]),
    );
  }
}

/// Bottom sheet form cabang — field sama seperti web CabangManager.jsx:133-183.
class _BranchFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;

  const _BranchFormSheet({this.initial});

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  late final name = TextEditingController(
      text: widget.initial != null ? '${widget.initial!['name']}' : '');
  late final address = TextEditingController(
      text: widget.initial != null && widget.initial!['address'] != null
          ? '${widget.initial!['address']}'
          : '');
  late final lat = TextEditingController(
      text: widget.initial != null ? '${widget.initial!['lat']}' : '');
  late final lng = TextEditingController(
      text: widget.initial != null ? '${widget.initial!['lng']}' : '');
  late final radius = TextEditingController(
      text: widget.initial != null ? '${widget.initial!['radius_m']}' : '100');
  final linkCtrl = TextEditingController();
  String? formError;
  String? notice;
  bool busy = false;
  bool geoBusy = false;

  bool get isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null && name.text.isNotEmpty) {
      notice = 'Edit Cabang: ${name.text}';
    }
  }

  void _useMapsLink() {
    final parsed = parseMapsUrl(linkCtrl.text);
    if (parsed != null) {
      setState(() {
        lat.text = parsed['lat']!;
        lng.text = parsed['lng']!;
        notice = 'Koordinat berhasil diambil dari link Google Maps.';
        formError = null;
      });
    } else {
      setState(() {
        notice = null;
        formError =
            'Link tidak dikenali. Buka Google Maps → klik kanan titik lokasi → Copy lat/lng, lalu paste di sini.';
      });
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => geoBusy = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Gagal mengambil lokasi — izinkan akses lokasi.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Layanan lokasi (GPS) sedang mati.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10)),
      );
      setState(() {
        lat.text = pos.latitude.toStringAsFixed(7);
        lng.text = pos.longitude.toStringAsFixed(7);
        notice = 'Koordinat diambil dari lokasi perangkat ini.';
        formError = null;
      });
    } catch (e) {
      setState(() {
        notice = null;
        formError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => geoBusy = false);
    }
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty) {
      setState(() => formError = 'Nama cabang wajib diisi');
      return;
    }
    setState(() { busy = true; formError = null; });
    try {
      final payload = {
        'name': name.text.trim(),
        'address': address.text.trim().isEmpty ? null : address.text.trim(),
        'lat': num.tryParse(lat.text),
        'lng': num.tryParse(lng.text),
        'radius_m': num.tryParse(radius.text) ?? 100,
      };
      if (isEdit) {
        await api.patch('/branches/${widget.initial!['id']}', payload);
      } else {
        await api.post('/branches', payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          formError = e.toString().replaceFirst('Exception: ', '');
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEdit ? 'Edit Cabang: ${name.text}' : 'Tambah Cabang Baru',
              style: AppText.display(size: 17)),
          if (formError != null) ...[
            const SizedBox(height: 10),
            Text(formError!,
                style: AppText.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.chili)),
          ],
          if (notice != null) ...[
            const SizedBox(height: 10),
            Text(notice!,
                style: AppText.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.greenOk)),
          ],
          const SizedBox(height: 14),
          TextField(
              controller: name,
              decoration: const InputDecoration(
                  labelText: 'Nama Cabang *',
                  hintText: 'mis. Cabang Cibaduyut')),
          const SizedBox(height: 12),
          TextField(
              controller: address,
              decoration: const InputDecoration(
                  labelText: 'Alamat (opsional)',
                  hintText: 'mis. Jl. Raya No. 12')),
          const SizedBox(height: 12),
          TextField(
              controller: linkCtrl,
              decoration: InputDecoration(
                  labelText: 'Link Google Maps',
                  hintText: "Paste link Google Maps atau 'lat, lng'",
                  suffixIcon: TextButton(
                    onPressed: _useMapsLink,
                    child: Text('Ambil',
                        style: AppText.body(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppColors.char)),
                  ))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black12),
                foregroundColor: AppColors.char,
                minimumSize: const Size.fromHeight(44)),
            onPressed: geoBusy ? null : _useMyLocation,
            icon: geoBusy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 16),
            label: Text(geoBusy ? 'Mengambil...' : 'Lokasi saya',
                style: AppText.body(size: 12, weight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(
            'Klik kanan titik di Google Maps → angka pertama = lintang (lat), kedua = bujur (lng)',
            style: AppText.body(size: 10, color: Colors.black38),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                  controller: lat,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(
                      labelText: 'Lintang (lat) *',
                      hintText: '-6.9218278')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                  controller: lng,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(
                      labelText: 'Bujur (lng) *',
                      hintText: '107.6071831')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                  controller: radius,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Radius (meter)')),
            ),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            if (isEdit)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black12),
                      minimumSize: const Size.fromHeight(48)),
                  child: const Text('Batal'),
                ),
              ),
            if (isEdit) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.chili,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: busy ? null : _submit,
                child: Text(
                    busy
                        ? 'Menyimpan...'
                        : isEdit
                            ? 'Simpan Perubahan'
                            : 'Tambah Cabang',
                    style: AppText.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
