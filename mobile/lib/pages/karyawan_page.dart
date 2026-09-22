import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class KaryawanPage extends StatefulWidget {
  final AppUser user;
  const KaryawanPage({super.key, required this.user});

  @override
  State<KaryawanPage> createState() => _KaryawanPageState();
}

class _KaryawanPageState extends State<KaryawanPage> {
  final List<Employee> employees = List.of(MockData.employees);
  String? error;
  String? success;

  static const roleLabels = {
    'owner': 'Super Admin',
    'admin': 'Admin',
    'kasir': 'Karyawan',
  };

  void _addAccount() {
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    String role = 'kasir';
    showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text('Akun Login Baru', style: AppText.display(size: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration:
                    const InputDecoration(labelText: 'Nama Lengkap')),
            const SizedBox(height: 10),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email (login)')),
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
                onPressed: () => Navigator.pop(d), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.chili, elevation: 0),
              onPressed: () {
                if (name.text.trim().isEmpty ||
                    email.text.trim().isEmpty ||
                    pass.text.length < 6) {
                  setD(() {});
                  return;
                }
                setState(() {
                  employees.add(Employee(
                    employees.length + 1,
                    name.text.trim(),
                    roleLabels[role]!,
                    role,
                    '-',
                    0,
                  ));
                  success = 'Akun ${name.text.trim()} berhasil dibuat.';
                  error = null;
                });
                Navigator.pop(d);
              },
              child: const Text('Buat Akun'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (error != null)
          _banner(error!, AppColors.chili, AppColors.redBg),
        if (success != null)
          _banner(success!, AppColors.greenOk, AppColors.greenBg),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Akun Login', style: AppText.display(size: 18)),
              const SizedBox(height: 6),
              Text(
                'Kasir hanya bisa mengakses menu POS & Absensi. (Tahap 1: tersimpan lokal; Tahap 2: tersimpan di server dengan password ter-hash.)',
                style: AppText.body(size: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              primaryButton('Buat Akun Login', onPressed: _addAccount),
              const SizedBox(height: 8),
              for (final e in employees)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.chili.withValues(alpha: 0.12),
                    child: Text(e.name[0],
                        style: AppText.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.chili)),
                  ),
                  title: Text(e.name,
                      style: AppText.body(
                          size: 13, weight: FontWeight.w700)),
                  subtitle: Text(
                      '${roleLabels[e.role] ?? e.role} · ${e.active ? 'Aktif' : 'Nonaktif'}',
                      style:
                          AppText.body(size: 11, color: Colors.black45)),
                  trailing: Switch(
                    value: e.active,
                    activeThumbColor: AppColors.chili,
                    onChanged: (v) =>
                        setState(() { e.active = v; success = null; error = null; }),
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
              Text('Data Karyawan', style: AppText.display(size: 18)),
              const SizedBox(height: 6),
              Text(
                'Jadwal kerja & tarif harian dipakai oleh modul Absensi dan Gaji.',
                style: AppText.body(size: 12, color: Colors.black54),
              ),
              for (final e in employees.where((x) => x.role != 'owner'))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined,
                      color: AppColors.char),
                  title: Text('${e.name} — ${e.position}',
                      style: AppText.body(
                          size: 13, weight: FontWeight.w700)),
                  subtitle: Text(
                    'Shift ${e.shiftStart} · ${e.workHours} jam · ${formatRp(e.dailyRate)}/hari',
                    style: AppText.body(size: 11, color: Colors.black45),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _banner(String msg, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(msg,
            style:
                AppText.body(size: 12, weight: FontWeight.w700, color: fg)),
      );
}
