# Status sinkronisasi aplikasi Android

File ini DIPERBARUI otomatis tiap kali prompt "Update Android APK nya" dijalankan
(lihat docs/PROMPT-UPDATE-ANDROID.md). Jangan dihapus — dipakai sebagai titik awal
untuk mengetahui perubahan web/server apa yang belum masuk ke aplikasi.

## Titik sinkron terakhir
- Commit terakhir yang SUDAH tercermin di APK : `2a2f404`
- Versi APK terakhir                          : 0.2.7+21 (versionCode 21)
- Tanggal                                     : 2026-10-25

## Perubahan source Android SUDAH ditulis tapi BELUM dirilis (menunggu APK berikutnya)
Kode sudah ada di repo (commit sesudah `2a2f404`), TETAPI APK belum dibuild. Saat APK berikutnya
dibuild: naikkan versi (> 0.2.7+21), isi tabel riwayat, dan ubah "Titik sinkron terakhir".
Server/web yang sudah (atau akan) live untuk fitur ini TIDAK berlaku di APK lama.

| Commit | Fitur | File Android |
|--------|-------|--------------|
| `10d2c89` | Pemilih jam masuk stepper (+/- jam & menit), langsung tersimpan | pages/absensi_page.dart |
| `f388559` | Pembulatan ke kelipatan Rp1.000 terdekat (>=500 naik, <500 turun; selisih bisa negatif) | pages/pos_page.dart, pages/pembayaran_page.dart |
| `8d3161d` | QRIS statis per cabang (kunci `qris_static_image_b<id>`), POS pakai QRIS cabang shift | pages/pembayaran_page.dart, pages/pos_page.dart |
| `1c01050`, `7688f9e` | Topping 3 kategori (`topping-*`), grup tertutup (ketuk buka), urutan terlaris (`sold`) | pages/pos_page.dart |
| `eade281` | Ubah role akun (ikon Ubah role) | pages/karyawan_page.dart |
| `ffa7305` | Anti titip absen: kirim `X-Device-Id` (ANDROID_ID, paket `android_id`) & `X-Device-Name`; tombol Reset HP | main.dart, api_client.dart, pages/karyawan_page.dart, pubspec.yaml |
| `4774c07` | Atas nama pemesan wajib di POS; cetak struk tercatat (`POST /orders/:id/print`), cetak ulang bertanda CETAKAN KE-N | pages/pos_page.dart, services/thermal_printer.dart |
| (commit berikut) | Level Pedas Lv1-5 per porsi (produk kategori `topping-level`, dipilih terpisah dari topping, maks 1/porsi); harga kuah baru 1.500/2.000/2.500 (data: migrate-13) | pages/pos_page.dart (_PorsiBuilderSheet) |

PERINGATAN rilis: begitu server dengan `ffa7305` di-restart, absen karyawan/gudang/leader dari APK
LAMA ditolak (tidak mengirim X-Device-Id). Deploy server & rilis APK harus berbarengan.
Perubahan server lain yang butuh APK baru: pesanan dengan `customer_name` (wajib hanya di klien),
`print_count`, `sold` & `category_label` di GET /products.

## Peta paritas (halaman web -> halaman Flutter)
| Web (web/src/...)                         | Android (mobile/lib/...)                  |
|-------------------------------------------|-------------------------------------------|
| pages/admin/Dashboard.jsx                 | pages/dashboard_page.dart                 |
| pages/admin/Pos.jsx                       | pages/pos_page.dart (+ services/thermal_printer.dart untuk cetak Bluetooth) |
| pages/admin/PesananOnline.jsx (+ QrPrintSheet.jsx) | pages/pesanan_online_page.dart (+ services/qr_sheet.dart) |
| pages/admin/Menu.jsx                      | pages/menu_page.dart                      |
| pages/admin/Absensi.jsx (+ CabangManager.jsx) | pages/absensi_page.dart              |
| pages/admin/Cabang.jsx                    | pages/cabang_page.dart                    |
| pages/admin/Stock.jsx                     | pages/stock_page.dart                     |
| pages/admin/Pembayaran.jsx                | pages/pembayaran_page.dart                |
| pages/admin/Keuangan.jsx + keuangan/*     | pages/keuangan_page.dart (+ services/pdf_reports.dart) |
| pages/admin/Karyawan.jsx                  | pages/karyawan_page.dart                  |
| pages/admin/Gaji.jsx                      | pages/gaji_page.dart                      |
| components/AdminLayout.jsx (nav, role, header cabang, ganti password) | pages/erp_shell.dart |
| auth.js (isAllowed, ROLE_HOME), branch.js, api.js | auth_service.dart, branch_service.dart, api_client.dart |
| pages/Login.jsx                           | pages/login_screen.dart                   |

## Sengaja TIDAK ada di aplikasi (halaman publik web)
Landing (`/`), `/order` (pesan online pelanggan), `/track` (lacak pesanan), `/download`.
Perubahan di halaman-halaman ini TIDAK perlu diport ke Android.

## Kontrak server yang dipakai aplikasi
Aplikasi hanya memanggil `https://juragan-seblak.airadynamics.com/api/*`. Bila endpoint,
field respons, atau aturan role di server berubah, aplikasi harus disesuaikan walau tampilan
web tidak berubah.

## Riwayat rilis Android
| Versi | Isi ringkas |
|-------|-------------|
| 0.2.0+14 | URL server baru, multi-cabang, shift per cabang, biaya layanan/pembulatan, QR meja A5, cetak Bluetooth |
| 0.2.1+15 | Daftar printer Bluetooth bisa di-scroll & diurutkan |
| 0.2.2+16 | Perbaikan cetak resep dapur (ASCII), pengiriman bertahap |
| 0.2.3+17 | Cetak 3 tingkat cadangan + menu Diagnosa printer |
| 0.2.4+18 | Akar masalah cetak: List<int> bukan Uint8List |
| 0.2.5+19 | Struk: LUNAS + blok Aira Dynamics, pembulatan digabung Service, tanggal terisi |
| 0.2.6+20 | Hapus login demo, Ganti Password, tagline "Solusi sistem bisnis anda", tab Keuangan |
| 0.2.7+21 | Role Admin Gudang & Tim Leader |
