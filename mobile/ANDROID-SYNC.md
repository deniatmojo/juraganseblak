# Status sinkronisasi aplikasi Android

File ini DIPERBARUI otomatis tiap kali prompt "Update Android APK nya" dijalankan
(lihat docs/PROMPT-UPDATE-ANDROID.md). Jangan dihapus — dipakai sebagai titik awal
untuk mengetahui perubahan web/server apa yang belum masuk ke aplikasi.

## Titik sinkron terakhir
- Commit terakhir yang SUDAH tercermin di APK : `aebdf1e`
- Versi APK terakhir                          : 0.3.0+22 (versionCode 22)
- Tanggal                                     : 2026-10-29

PERINGATAN rilis: kunci HP default MATI (flag `DEVICE_LOCK=on` di server/.env). Setelah semua HP karyawan memakai APK baru, tambahkan `DEVICE_LOCK=on` lalu `pm2 restart`. Bila dinyalakan sebelum itu, absen karyawan/gudang/leader dari APK
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
| 0.3.0+22 | Jam masuk stepper, pembulatan Rp1.000, QRIS per cabang, topping 3 kategori + terlaris, Level Pedas, ubah role, anti titip absen (X-Device-Id), nama pemesan wajib + cetak ulang CETAKAN KE-N |
