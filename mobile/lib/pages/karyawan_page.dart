import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Karyawan — menyalin web/src/pages/admin/Karyawan.jsx:
/// akun login (4 role) + reset password + aktif/nonaktif, data karyawan
/// dengan link akun & cabang (lokasi absen), assign cabang inline, hapus.
class KaryawanPage extends StatefulWidget {
  final AppUser user;
  const KaryawanPage({super.key, required this.user});

  @override
  State<KaryawanPage> createState() => _KaryawanPageState();
}

class _KaryawanPageState extends State<KaryawanPage> {
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> branches = [];
  bool loading = true;
  String? error;
  String? success;

  static const roleLabels = {
    'owner': 'Super Admin',
    'admin': 'Admin',
    'kasir': 'Karyawan Kasir',
    'karyawan': 'Karyawan',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait(
          [api.get('/users'), api.get('/employees'), api.get('/branches')]);
      if (mounted) {
        setState(() {
          users = (results[0] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          employees = (results[1] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          branches = (results[2] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .where((b) => b['is_active'] == 1 || b['is_active'] == true)
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

  /// Akun login baru — role lengkap seperti web Karyawan.jsx:116-121.
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
                decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    hintText: 'cth. Siti Nurhaliza')),
            const SizedBox(height: 10),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email (login)',
                    hintText: 'nama@juraganseblak.id')),
            const SizedBox(height: 10),
            TextField(
                controller: pass,
                decoration: const InputDecoration(
                    labelText: 'Password Awal',
                    hintText: 'Minimal 6 karakter')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(
                    value: 'kasir', child: Text('Karyawan Kasir')),
                DropdownMenuItem(
                    value: 'karyawan', child: Text('Karyawan (Absensi saja)')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'owner', child: Text('Super Admin')),
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

  /// Modal Reset Password — padanan web Karyawan.jsx:273-294.
  Future<void> _resetPassword(Map<String, dynamic> u) async {
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Reset Password', style: AppText.display(size: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${u['email']}',
              style: AppText.body(size: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
              controller: pass,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Password Baru',
                  hintText: 'Minimal 6 karakter')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.patch('/users/${u['id']}', {'password': pass.text});
      setState(() => success = 'Password ${u['email']} berhasil direset.');
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Karyawan baru — dengan link akun & cabang (web Karyawan.jsx:176-220).
  Future<void> _addEmployee() async {
    final name = TextEditingController();
    final position = TextEditingController();
    final phone = TextEditingController();
    final rate = TextEditingController();
    String? userId;
    String? branchId;
    final linkedUserIds = employees
        .map((e) => '${e['user_id'] ?? ''}')
        .where((s) => s.isNotEmpty && s != 'null')
        .toSet();
    final freeUsers = users
        .where((u) =>
            (u['is_active'] == 1 || u['is_active'] == true) &&
            u['role'] != 'owner' &&
            !linkedUserIds.contains('${u['id']}'))
        .toList();
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
                    const InputDecoration(labelText: 'Nama')),
            const SizedBox(height: 10),
            TextField(
                controller: position,
                decoration: const InputDecoration(
                    labelText: 'Posisi',
                    hintText: 'Kasir / Koki / Pelayan')),
            const SizedBox(height: 10),
            TextField(
                controller: rate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Tarif Harian (Rp)',
                    hintText: '70000')),
            const SizedBox(height: 10),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'No. HP', hintText: 'opsional')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: userId,
              decoration: const InputDecoration(
                  labelText: 'Akun Login'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('— tanpa akun —')),
                for (final u in freeUsers)
                  DropdownMenuItem(
                      value: '${u['id']}',
                      child: Text(
                          '${u['name']} (${u['email']})${u['role'] == 'admin' ? ' — Admin' : ''}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setD(() => userId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: branchId,
              decoration: const InputDecoration(
                  labelText: 'Cabang (Lokasi Absen)'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('— belum ditugaskan —')),
                for (final b in branches)
                  DropdownMenuItem(
                      value: '${b['id']}',
                      child: Text(
                          '${b['name']} (radius ${b['radius_m']} m)',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setD(() => branchId = v),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.char, elevation: 0),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Tambah Karyawan'),
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
        'branch_id': branchId != null ? (int.tryParse(branchId!) ?? 0) : null,
      });
      setState(() => success = 'Karyawan ${name.text.trim()} berhasil ditambahkan.');
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Assign / ubah cabang absen langsung dari daftar (web Karyawan.jsx:80-87).
  Future<void> _assignBranch(Map<String, dynamic> emp, String? branchId) async {
    try {
      await api.patch('/employees/${emp['id']}', {
        'branch_id': branchId != null ? (int.tryParse(branchId) ?? 0) : null,
      });
      final branchName = branches
          .where((b) => '${b['id']}' == '$branchId')
          .map((b) => '${b['name']}')
          .firstOrNull;
      setState(() =>
          success = '${emp['name']} ditugaskan ke ${branchName ?? 'tanpa cabang'}.');
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
        await _load();
      }
    }
  }

  Future<void> _removeEmployee(Map<String, dynamic> emp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text('Hapus data karyawan ${emp['name']}?',
            style: AppText.body(size: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.del('/employees/${emp['id']}');
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
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      (u['is_active'] == 1 || u['is_active'] == true)
                          ? StatusChip.ok('Aktif')
                          : StatusChip('Nonaktif',
                              fg: Colors.black45,
                              bg: Colors.black.withValues(alpha: 0.05)),
                      if (u['role'] != 'owner') ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Reset Password',
                          icon: const Icon(Icons.key_outlined, size: 20),
                          onPressed: () => _resetPassword(u),
                        ),
                        Switch(
                          value:
                              u['is_active'] == 1 || u['is_active'] == true,
                          activeThumbColor: AppColors.chili,
                          onChanged: (_) => _toggleUser(u),
                        ),
                      ],
                    ]),
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
                  'Data untuk absensi & payroll. Hubungkan ke akun login supaya karyawan bisa clock in/out sendiri.',
                  style: AppText.body(size: 12, color: Colors.black54),
                ),
                for (final e in employees)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.badge_outlined,
                              color: AppColors.char),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${e['name']} — ${e['role'] ?? '—'}',
                                    style: AppText.body(
                                        size: 13, weight: FontWeight.w700)),
                                Text(
                                  '${num.tryParse('${e['daily_rate']}') != null && num.tryParse('${e['daily_rate']}')! > 0 ? '${formatRp(num.tryParse('${e['daily_rate']}')!)}/hari' : '—'}'
                                  '${(num.tryParse('${e['kasbon_open']}') ?? 0) > 0 ? ' · kasbon ${formatRp(num.tryParse('${e['kasbon_open']}') ?? 0)}' : ''}'
                                  ' · akun: ${e['account_email'] ?? 'belum terhubung'}',
                                  style: AppText.body(
                                      size: 11, color: Colors.black45),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _removeEmployee(e),
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6)),
                            child: Text('Hapus',
                                style: AppText.body(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: AppColors.chili)),
                          ),
                        ]),
                        // Dropdown cabang inline (web Karyawan.jsx:249-260)
                        DropdownButtonFormField<String>(
                          initialValue:
                              e['branch_id'] == null || '${e['branch_id']}' == 'null'
                                  ? null
                                  : '${e['branch_id']}',
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Cabang (Lokasi Absen)',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8)),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('— belum ditugaskan —')),
                            for (final b in branches)
                              DropdownMenuItem(
                                  value: '${b['id']}',
                                  child: Text('${b['name']}',
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => _assignBranch(e, v),
                        ),
                      ],
                    ),
                  ),
                if (employees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Belum ada karyawan.',
                        style:
                            AppText.body(size: 12, color: Colors.black26)),
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
