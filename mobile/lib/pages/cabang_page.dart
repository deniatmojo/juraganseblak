import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../theme.dart';
import 'absensi_page.dart';

/// Halaman Cabang (Super Admin) — padanan web/src/pages/admin/Cabang.jsx:
/// tambah/ubah cabang & titik lokasi absen. Cabang yang dibuat di sini
/// otomatis dipakai stok, shift kasir, meja QR, dan laporan.
class CabangPage extends StatefulWidget {
  final AppUser user;
  const CabangPage({super.key, required this.user});

  @override
  State<CabangPage> createState() => _CabangPageState();
}

class _CabangPageState extends State<CabangPage> {
  String? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.redBg, borderRadius: BorderRadius.circular(12)),
            child: Text(error!,
                style: AppText.body(
                    size: 12, weight: FontWeight.w700, color: AppColors.chili)),
          ),
        CabangManagerSection(onError: (m) => setState(() => error = m)),
      ],
    );
  }
}
