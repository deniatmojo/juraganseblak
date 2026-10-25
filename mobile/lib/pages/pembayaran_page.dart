import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pengaturan Pembayaran (owner/admin) — menyalin web/src/pages/admin/Pembayaran.jsx:
/// QRIS statis (upload gambar + nama merchant) dan konfigurasi payment gateway
/// (mode sandbox/production, 4 field, info webhook).
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
  String uploadingKey = ''; // kunci setting QRIS yang sedang diunggah
  List<Map<String, dynamic>> branches = [];
  String? msg;
  String? error;

  // Biaya layanan & pajak (persen) + pembulatan total — disimpan sebagai
  // pecahan (5% -> 0.05) dan langkah pembulatan (Rp). Padanan kartu "Biaya
  // Layanan & Pembulatan" di web Pembayaran.jsx.
  final serviceCtrl = TextEditingController();
  final taxCtrl = TextEditingController();

  static String _pctText(dynamic rate) {
    final n = num.tryParse('$rate');
    if (n == null) return '';
    return (n * 100).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String _fracText(String pct) {
    final n = num.tryParse(pct.replaceAll(',', '.'));
    return n == null ? '' : '${n / 100}';
  }

  @override
  void dispose() {
    serviceCtrl.dispose();
    taxCtrl.dispose();
    super.dispose();
  }

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

  String _imgUrl(dynamic path) {
    final s = '$path';
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    return ApiClient.baseUrl.replaceAll(RegExp(r'/api$'), '') + s;
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      try {
        final rows = await api.get('/branch-options') as List;
        branches = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
      final s = await api.get('/settings');
      if (mounted) {
        setState(() => form = Map<String, dynamic>.from(s as Map));
        serviceCtrl.text = _pctText(form['service_rate']);
        taxCtrl.text = _pctText(form['tax_rate']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Upload gambar QRIS statis — padanan uploadQris() web (POST /api/upload
  /// multipart 'photo', hasil {url} diset ke qris_static_image).
  Future<void> _uploadQris(String key) async {
    try {
      final img = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 90, maxWidth: 1200);
      if (img == null) return;
      setState(() { uploadingKey = key; error = null; });
      final bytes = await File(img.path).readAsBytes();
      final ext = img.path.toLowerCase().endsWith('.png')
          ? 'png'
          : img.path.toLowerCase().endsWith('.webp')
              ? 'webp'
              : 'jpg';
      final data = await api.upload('/upload',
          field: 'photo',
          filename: 'qris.$ext',
          bytes: bytes,
          contentType: 'image/$ext');
      if (mounted) {
        setState(() => form[key] = '${data['url']}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => uploadingKey = '');
    }
  }

  Future<void> _save() async {
    setState(() { saving = true; msg = null; error = null; });
    try {
      // Nilai ter-mask ('********') dari server tidak dikirim ulang supaya
      // tidak menimpa secret yang tersimpan (padanan catatan settings.js).
      final body = <String, dynamic>{
        'service_rate': _fracText(serviceCtrl.text),
        'tax_rate': _fracText(taxCtrl.text),
        'rounding_step': (num.tryParse('${form['rounding_step']}') ?? 0) > 0
            ? '1000'
            : '0',
      };
      body.removeWhere((k, v) => v == '');
      for (final k in form.keys.where(
          (k) => RegExp(r'^qris_static_(image|merchant)_b\d+$').hasMatch(k))) {
        body[k] = '${form[k] ?? ''}'.trim();
      }
      for (final k in [
        'qris_static_image',
        'qris_static_merchant',
        'payment_gateway',
        'gateway_mode',
        'gateway_merchant_id',
        'gateway_api_key',
        'gateway_private_key',
        'gateway_callback_url',
      ]) {
        final v = '${form[k] ?? ''}'.trim();
        if (secretKeys.contains(k) && v == '********') continue;
        body[k] = v;
      }
      await api.patch('/settings', body);
      if (mounted) {
        setState(() => msg = 'Pengaturan pembayaran tersimpan.');
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

  Widget _qrisBlock(String title, String imgKey, String? merKey) {
    final img = _imgUrl(form[imgKey]);
    final busy = uploadingKey == imgKey;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppText.body(size: 13, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12)),
            child: img.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(img,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined)))
                : Center(
                    child: Text('Belum ada gambar QRIS',
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 10, color: Colors.black38))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.char,
                    side: const BorderSide(color: Colors.black12),
                    minimumSize: const Size.fromHeight(44)),
                onPressed: uploadingKey.isNotEmpty ? null : () => _uploadQris(imgKey),
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_outlined, size: 16),
                label: Text(busy ? 'Mengunggah...' : 'Upload Gambar QRIS',
                    style: AppText.body(size: 12, weight: FontWeight.w700)),
              ),
              if (merKey != null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(merKey),
                  initialValue: '${form[merKey] ?? ''}',
                  onChanged: (v) => form[merKey] = v,
                  decoration: const InputDecoration(
                      labelText: 'Nama Merchant (opsional)',
                      helperText: 'Tampil di modal QR kasir'),
                ),
              ],
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _feeCard() {
    const sample = 20000;
    final svc = sample * (num.tryParse(_fracText(serviceCtrl.text)) ?? 0);
    final tax = sample * (num.tryParse(_fracText(taxCtrl.text)) ?? 0);
    final sService = svc.round();
    final sTax = tax.round();
    final raw = sample + sService + sTax;
    final step = (num.tryParse('${form['rounding_step']}') ?? 0).toInt();
    final total = step > 0 ? (raw / step).round() * step : raw;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Biaya Layanan & Pembulatan', style: AppText.display(size: 18)),
          const SizedBox(height: 6),
          Text(
            'Biaya layanan (service charge) dan pajak dihitung sebagai persen dari total pembelian (subtotal), berlaku di POS maupun pesanan online.',
            style: AppText.body(size: 12, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: serviceCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Biaya Layanan (%)', hintText: 'mis. 5'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: taxCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Pajak (%)', hintText: 'mis. 10'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.chili,
            value: step > 0,
            onChanged: (v) =>
                setState(() => form['rounding_step'] = v ? '1000' : '0'),
            title: Text('Bulatkan total per Rp1.000 (500 ke atas naik, di bawah 500 turun)',
                style: AppText.body(size: 13, weight: FontWeight.w700)),
            subtitle: Text(
                'Contoh: total Rp4.200 menjadi Rp5.000. Selisihnya tampil sebagai baris "Pembulatan" di struk dan tercatat sebagai pendapatan.',
                style: AppText.body(size: 11, color: Colors.black45)),
          ),
          const SizedBox(height: 6),
          Text(
            'Simulasi pembelian ${formatRp(sample)}: layanan ${formatRp(sService)} + pajak ${formatRp(sTax)}${total > raw ? ' + pembulatan ${formatRp(total - raw)}' : ''} = ${formatRp(total)}',
            style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ember),
          ),
        ],
      ),
    );
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
          _feeCard(),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QRIS Statis per Cabang', style: AppText.display(size: 18)),
                const SizedBox(height: 6),
                Text(
                  'Tiap cabang punya QRIS statis sendiri. Kasir menampilkan QRIS cabang shift yang dibuka; pelanggan online melihat QRIS cabang pesanannya. Konfirmasi manual setelah pembayaran diterima.',
                  style: AppText.body(size: 12, color: Colors.black54),
                ),
                for (final b in branches) ...[
                  const SizedBox(height: 14),
                  _qrisBlock('${b['name']}', 'qris_static_image_b${b['id']}',
                      'qris_static_merchant_b${b['id']}'),
                ],
                if ('${form['qris_static_image'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _qrisBlock('QRIS Umum (cadangan, untuk cabang tanpa QRIS sendiri)',
                      'qris_static_image', null),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Gateway (QRIS Dinamis)',
                    style: AppText.display(size: 18)),
                const SizedBox(height: 6),
                Text(
                  'Opsional. Aktif hanya bila gateway dipilih dan API keys terisi — POS otomatis menampilkan QR dinamis per transaksi dan melunaskan pesanan lewat webhook. Gunakan provider yang terdaftar sebagai PJSP berizin Bank Indonesia.',
                  style: AppText.body(size: 12, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: gateway,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: [
                    for (final e in gateways.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => form['payment_gateway'] = v),
                ),
                if (gateway != 'none') ...[
                  const SizedBox(height: 14),
                  // Mode sandbox/production (web Pembayaran.jsx:137-145)
                  DropdownButtonFormField<String>(
                    initialValue: '${form['gateway_mode'] ?? 'sandbox'}',
                    decoration: const InputDecoration(labelText: 'Mode'),
                    items: const [
                      DropdownMenuItem(
                          value: 'sandbox', child: Text('Sandbox (uji coba)')),
                      DropdownMenuItem(
                          value: 'production',
                          child: Text('Production (live)')),
                    ],
                    onChanged: (v) =>
                        setState(() => form['gateway_mode'] = v),
                  ),
                  const SizedBox(height: 14),
                  _field('gateway_merchant_id', 'Merchant ID / Merchant Code'),
                  _field('gateway_api_key', 'API Key / Server Key',
                      secret: form['has_gateway_api_key'] == true),
                  _field('gateway_private_key', 'Private Key (Tripay & Duitku)',
                      secret: form['has_gateway_private_key'] == true),
                  _field('gateway_callback_url',
                      'URL Publik Server (mis. https://juragan-seblak.airadynamics.com)'),
                  // Info webhook (web Pembayaran.jsx:159-163)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.cream.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'Daftarkan webhook ke provider dengan URL:\n${'${form['gateway_callback_url'] ?? ''}'.isEmpty ? 'https://domain-anda' : form['gateway_callback_url']}/api/payments/webhook/$gateway\n\nEndpoint ini publik dan tervalidasi signature dari provider.',
                      style: AppText.body(size: 11, color: Colors.black54),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                primaryButton(
                  saving ? 'Menyimpan...' : 'Simpan Pengaturan',
                  onPressed: saving || uploadingKey.isNotEmpty ? null : _save,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'API key tersimpan di database dan hanya tampil penuh untuk Super Admin.',
                    style: AppText.body(size: 10, color: Colors.black38),
                  ),
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
