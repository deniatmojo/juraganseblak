import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Absensi — data langsung dari GET /attendance?date=, clock via
/// POST /attendance/clock-in|clock-out, ubah status owner via PATCH.
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
      final data = await api.get('/attendance?date=$_today');
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

  Map<String, dynamic>? get _myRow {
    final uid = widget.user.id;
    return rows.where((r) => r['user_id'] == uid).firstOrNull;
  }

  // Ambil posisi GPS perangkat (absen hanya sah dalam radius titik cabang).
  // Melempar Exception berisi pesan ramah user bila izin/servis lokasi mati.
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
      await _load();
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
          title: Text('Status: ${r['name']}',
              style: AppText.body(size: 15, weight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
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
      await api.patch('/attendance/status', {
        'employee_id': r['employee_id'],
        'work_date': _today,
        'status': status,
        'note': note.text.trim().isEmpty ? null : note.text.trim(),
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
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
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 2.1,
            children: [
              StatCard(
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.greenOk,
                  iconBg: AppColors.greenBg,
                  value: '$hadir',
                  label: 'Hadir'),
              StatCard(
                  icon: Icons.schedule,
                  iconColor: AppColors.ember,
                  iconBg: AppColors.ember.withValues(alpha: 0.1),
                  value: '$izin',
                  label: 'Izin / Sakit'),
              StatCard(
                  icon: Icons.cancel_outlined,
                  iconColor: AppColors.chili,
                  iconBg: AppColors.redBg,
                  value: '$alpa',
                  label: 'Tanpa Keterangan'),
            ],
          ),
          const SizedBox(height: 20),
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
                      'Masuk ${_fmtTime(r['clock_in'])} · Keluar ${_fmtTime(r['clock_out'])}'
                      '${r['note'] != null && r['note'] != '' ? ' · ${r['note']}' : ''}',
                      style:
                          AppText.body(size: 11, color: Colors.black45),
                    ),
                    trailing: widget.user.isOwner
                        ? TextButton(
                            onPressed: () => _statusDialog(r),
                            child: Text('Ubah',
                                style: AppText.body(
                                    size: 11, weight: FontWeight.w700)),
                          )
                        : _chip(r['status'] as String?),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
