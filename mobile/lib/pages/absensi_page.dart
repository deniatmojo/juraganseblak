import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AbsensiPage extends StatefulWidget {
  final AppUser user;
  const AbsensiPage({super.key, required this.user});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  final List<AttendanceRow> rows = List.of(MockData.attendance);
  String now() {
    final t = TimeOfDay.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _clock(bool isIn) {
    setState(() {
      final me = rows.where((r) => r.employeeId == widget.user.id).firstOrNull;
      if (me != null) {
        if (isIn) {
          me.clockIn = now();
          me.status = me.clockIn!.compareTo('09:00') > 0 ? 'terlambat' : 'hadir';
        } else {
          me.clockOut = now();
        }
      }
    });
  }

  void _setStatus(AttendanceRow r, String initial) {
    final note = TextEditingController();
    String status = initial;
    showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text('Status: ${r.name}',
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
              decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () {
              setState(() {
                r.status = status;
                r.note = note.text.trim().isEmpty ? null : note.text.trim();
              });
              Navigator.pop(d);
            },
            child: const Text('Simpan'),
          ),
        ],
        ),
      ),
    );
  }

  String _label(String s) => {
        'hadir': 'Hadir',
        'terlambat': 'Terlambat',
        'izin': 'Izin',
        'sakit': 'Sakit',
        'alpa': 'Tanpa Ket.',
      }[s]!;

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
        return StatusChip('Belum', fg: Colors.black45, bg: Colors.black.withValues(alpha: 0.05));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hadir =
        rows.where((r) => r.status == 'hadir' || r.status == 'terlambat').length;
    final izin =
        rows.where((r) => r.status == 'izin' || r.status == 'sakit').length;
    final alpa =
        rows.where((r) => r.status == 'alpa' || r.status.isEmpty).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Kartu absen pribadi (clock in/out)
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Absen Saya',
                  style: AppText.body(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Masuk ${rows.firstWhere((r) => r.employeeId == widget.user.id,
                        orElse: () => rows.first).clockIn ?? '—'} · '
                'Keluar ${rows.firstWhere((r) => r.employeeId == widget.user.id,
                        orElse: () => rows.first).clockOut ?? '—'}',
                style: AppText.body(size: 12, color: Colors.black45),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login, size: 18),
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
                    child: Text(r.name[0],
                        style: AppText.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.chili)),
                  ),
                  title: Text(r.name,
                      style: AppText.body(
                          size: 13, weight: FontWeight.w700)),
                  subtitle: Text(
                    'Masuk ${r.clockIn ?? '—'} · Keluar ${r.clockOut ?? '—'}'
                    '${r.note != null ? ' · ${r.note}' : ''}',
                    style: AppText.body(size: 11, color: Colors.black45),
                  ),
                  trailing: widget.user.isOwner
                      ? TextButton(
                          onPressed: () => _setStatus(r, 'izin'),
                          child: Text('Ubah',
                              style: AppText.body(
                                  size: 11,
                                  weight: FontWeight.w700)),
                        )
                      : _chip(r.status),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
