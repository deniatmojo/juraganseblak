import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pengaturan Pembayaran (owner/admin) — padanan Pembayaran.jsx web:
/// QRIS statis (merchant + gambar) dan konfigurasi payment gateway.
/// Upload gambar QRIS tetap di web; di sini fokus konfigurasi & status.
class PembayaranPage extends StatefulWidget {
  final AppUser user;
  const PembayaranPage({super.key, required this.user});

  @override
  State<PembayaranPage> createState() => _PembayaranPageState();
}

class _PembayaranPageState extends State<PembayaranPage> {
  Map<String, dynamic> form = {};
  bool loading = true;
  bool saving = false;
  String? msg;
  String? error;

  static const gateways = {
    'none': 'Belum pakai gateway (QRIS statis saja)',
    'tripay': 'Tripay — QRIS dinamis',
    'duitku': 'Duitku — QRIS dinamis',
    'midtrans': 'Midtrans (GoPay/QRIS) — QRIS dinamis',
  };

  static const secretKeys = ['gateway_api_key', 'gateway_private_key'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final s = await api.get('/settings');
      if (mounted) {
        setState(() => form = Map<String, dynamic>.from(s as Map));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() { saving = true; msg = null; error = null; });
    try {
      // Nilai ter-mask ('********') dari server tidak dikirim ulang supaya
      // tidak menimpa secret yang tersimpan (padanan catatan settings.js).
      final body = <String, dynamic>{};
      for (final k in [
        'payment_gateway',
        'gateway_merchant_id',
        'gateway_api_key',
        'gateway_private_key',
        'gateway_callback_url',
        'qris_static_merchant',
      ]) {
        final v = '${form[k] ?? ''}'.trim();
        if (secretKeys.contains(k) && v == '********') continue;
        body[k] = v;
      }
      await api.patch('/settings', body);
      if (mounted) {
        setState(() => msg = 'Konfigurasi pembayaran tersimpan.');
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    }
    final gateway = '${form['payment_gateway'] ?? 'none'}';

    return RefreshIndicator(
      color: AppColors.chili,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (error != null) _banner(error!, AppColors.chili, AppColors.redBg),
          if (msg != null) _banner(msg!, AppColors.greenOk, AppColors.greenBg),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QRIS Statis', style: AppText.display(size: 18)),
                const SizedBox(height: 6),
                Text(
                  'Gambar QRIS dari bank/e-wallet diunggah lewat versi web. '
                  'Di sini atur nama pemilik rekening yang tampil di struk kasir.',
                  style: AppText.body(size: 12, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: TextEditingController(
                      text: '${form['qris_static_merchant'] ?? ''}'),
                  onChanged: (v) => form['qris_static_merchant'] = v,
                  decoration: const InputDecoration(
                      labelText: 'Nama pemilik QRIS (a.n)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Gateway', style: AppText.display(size: 18)),
                const SizedBox(height: 6),
                Text(
                  'Gateway aktif membuat POS mengirim QRIS dinamis ke HP pelanggan; '
                  'pesanan lunas otomatis lewat webhook.',
                  style: AppText.body(size: 12, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: gateway,
                  decoration: const InputDecoration(labelText: 'Gateway'),
                  items: [
                    for (final e in gateways.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => form['payment_gateway'] = v),
                ),
                const SizedBox(height: 14),
                _field('gateway_merchant_id', 'Merchant ID / Merchant Code'),
                _field('gateway_api_key', 'API Key / Server Key',
                    secret: form['has_gateway_api_key'] == true),
                _field('gateway_private_key', 'Private Key (Tripay & Duitku)',
                    secret: form['has_gateway_private_key'] == true),
                _field('gateway_callback_url',
                    'URL Publik Server (mis. https://template-one.airadynamics.com)'),
                const SizedBox(height: 18),
                primaryButton(
                  saving ? 'Menyimpan...' : 'Simpan Konfigurasi',
                  onPressed: saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String key, String label, {bool secret = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: TextEditingController(text: '${form[key] ?? ''}'),
          onChanged: (v) => form[key] = v,
          obscureText: secret && '${form[key] ?? ''}'.isNotEmpty,
          decoration: InputDecoration(
            labelText: label,
            helperText: secret && '${form[key] ?? ''}'.isNotEmpty
                ? 'Sudah terisi — kosongkan/klik simpan tanpa mengubah untuk mempertahankan'
                : null,
          ),
        ),
      );

  Widget _banner(String m, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(m,
            style:
                AppText.body(size: 12, weight: FontWeight.w700, color: fg)),
      );
}
