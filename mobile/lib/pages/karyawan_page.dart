import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Karyawan — GET /users + /employees; buat akun POST /users,
/// aktif/nonaktif PATCH /users/:id, tambah karyawan POST /employees.
class KaryawanPage extends StatefulWidget {
  final AppUser user;
  const KaryawanPage({super.key, required this.user});

  @override
  State<KaryawanPage> createState() => _KaryawanPageState();
}

class _KaryawanPageState extends State<KaryawanPage> {
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> employees = [];
  bool loading = true;
  String? error;
  String? success;

  static const roleLabels = {
    'owner': 'Super Admin',
    'admin': 'Admin',
    'kasir': 'Karyawan',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final results =
          await Future.wait([api.get('/users'), api.get('/employees')]);
      if (mounted) {
        setState(() {
          users = (results[0] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          employees = (results[1] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
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

  Future<void> _addAccount() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    String role = 'kasir';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text('Akun Login Baru', style: AppText.display(size: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Nama Lengkap')),
            const SizedBox(height: 10),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'Email (login)')),
            const SizedBox(height: 10),
            TextField(
                controller: pass,
                decoration: const InputDecoration(
                    labelText: 'Password Awal (min 6 karakter)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final r in ['admin', 'kasir'])
                  DropdownMenuItem(value: r, child: Text(roleLabels[r]!)),
              ],
              onChanged: (v) => setD(() => role = v ?? role),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.chili, elevation: 0),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Buat Akun'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await api.post('/users', {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'password': pass.text,
        'role': role,
      });
      setState(() => success = 'Akun ${name.text.trim()} berhasil dibuat.');
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _toggleUser(Map<String, dynamic> u) async {
    final active = u['is_active'] == 1 || u['is_active'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${active ? 'Nonaktifkan' : 'Aktifkan'} akun?',
            style: AppText.display(size: 16)),
        content: Text('Akun: ${u['email']}',
            style: AppText.body(size: 12, color: Colors.black54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.patch('/users/${u['id']}', {'is_active': active ? 0 : 1});
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _addEmployee() async {
    final name = TextEditingController();
    final position = TextEditingController();
    final phone = TextEditingController();
    final rate = TextEditingController();
    String? userId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title:
              Text('Karyawan Baru', style: AppText.display(size: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Nama Karyawan')),
            const SizedBox(height: 10),
            TextField(
                controller: position,
                decoration: const InputDecoration(
                    labelText: 'Posisi (cth. Kasir)')),
            const SizedBox(height: 10),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP')),
            const SizedBox(height: 10),
            TextField(
                controller: rate,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Tarif Harian (Rp)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: userId,
              decoration: const InputDecoration(
                  labelText: 'Link ke Akun Login (opsional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— tanpa akun —')),
                for (final u in users)
                  DropdownMenuItem(
                      value: '${u['id']}', child: Text('${u['name']} (${u['email']})')),
              ],
              onChanged: (v) => setD(() => userId = v),
            ),
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
      await api.post('/employees', {
        'name': name.text.trim(),
        'role': position.text.trim(),
        'phone': phone.text.trim(),
        'daily_rate': num.tryParse(rate.text) ?? 0,
        'user_id': userId != null ? (int.tryParse(userId!) ?? 0) : null,
      });
      setState(() => success = 'Karyawan ${name.text.trim()} ditambahkan.');
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          if (error != null) _banner(error!, AppColors.chili, AppColors.redBg),
          if (success != null)
            _banner(success!, AppColors.greenOk, AppColors.greenBg),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Akun Login', style: AppText.display(size: 18)),
                const SizedBox(height: 6),
                Text(
                  'Akun disimpan di server (password di-hash). Kasir hanya bisa mengakses menu POS & Absensi.',
                  style: AppText.body(size: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                primaryButton('Buat Akun Login', onPressed: _addAccount),
                const SizedBox(height: 8),
                for (final u in users)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.chili.withValues(alpha: 0.12),
                      child: Text('${u['name']}'.isNotEmpty
                          ? '${u['name']}'.substring(0, 1)
                          : '?',
                          style: AppText.body(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.chili)),
                    ),
                    title: Text('${u['name']}',
                        style: AppText.body(
                            size: 13, weight: FontWeight.w700)),
                    subtitle: Text(
                        '${roleLabels['${u['role']}'] ?? '${u['role']}'} · ${u['email']}',
                        style:
                            AppText.body(size: 11, color: Colors.black45)),
                    trailing: u['role'] == 'owner'
                        ? StatusChip.ok('Aktif')
                        : Switch(
                            value: u['is_active'] == 1 ||
                                u['is_active'] == true,
                            activeThumbColor: AppColors.chili,
                            onChanged: (_) => _toggleUser(u),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Data Karyawan', style: AppText.display(size: 18)),
                    TextButton.icon(
                      onPressed: _addEmployee,
                      icon: const Icon(Icons.person_add_alt, size: 16),
                      label: Text('Tambah',
                          style: AppText.body(
                              size: 12, weight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Jadwal kerja & tarif harian dipakai oleh modul Absensi dan Gaji.',
                  style: AppText.body(size: 12, color: Colors.black54),
                ),
                for (final e in employees)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined,
                        color: AppColors.char),
                    title: Text('${e['name']} — ${e['role'] ?? ''}',
                        style: AppText.body(
                            size: 13, weight: FontWeight.w700)),
                    subtitle: Text(
                      'Shift ${e['shift_start'] ?? '—'} · ${e['work_hours']} jam · ${formatRp(num.tryParse('${e['daily_rate']}') ?? 0)}/hari'
                      '${(num.tryParse('${e['kasbon_open']}') ?? 0) > 0 ? ' · kasbon ${formatRp(num.tryParse('${e['kasbon_open']}') ?? 0)}' : ''}',
                      style: AppText.body(size: 11, color: Colors.black45),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String msg, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
              child: Text(msg,
                  style: AppText.body(
                      size: 12, weight: FontWeight.w700, color: fg))),
          InkWell(
            onTap: () => setState(() {
              error = null;
              success = null;
            }),
            child: Icon(Icons.close, size: 16, color: fg),
          ),
        ]),
      );
}
