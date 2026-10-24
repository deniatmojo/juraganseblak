# Prompt untuk chat baru — revisi bug Juragan Seblak

Salin seluruh blok di bawah ke chat baru (pilih folder project
`D:\Aira Dynamics Zone\Juragan Seblak`), lalu isi bagian **DAFTAR BUG** di akhir.

---

```text
Kamu melanjutkan perbaikan bug pada project "Juragan Seblak" (ERP + POS + pesan online
restoran seblak prasmanan multi-cabang), milik Aira Dynamics. Bahasa kerja: Indonesia.

## 0. Wajib dilakukan lebih dulu
1. Baca AGENTS.md dan docs/CATATAN-PRINTER-BLUETOOTH.md di root project.
2. Graphify: jalankan `graphify query "<pertanyaan>"` SEBELUM membaca banyak file mentah;
   setelah mengubah kode jalankan `graphify update .` dan sebutkan di laporan akhir.
3. Aturan MySQL: lokal hanya boleh mengelola port 3306 (D:/mysql-data, D:/mysql-conf/my.ini).
   Port 3307 / D:/mysql-data-mulia milik project lain — JANGAN disentuh. Perintah yang
   berpotensi menghapus data wajib ditanyakan dulu.

## 1. Peta project
- server/   Node.js 22 + Express 5 + mysql2 (ESM). Entry src/index.js (guard role per prefix
            /api/*). Route di src/routes/, helper cabang di src/branch.js, hitung tagihan
            di src/pricing.js. Port 3001 (lokal) / 3002 (produksi).
- web/      React + Vite + Tailwind (ERP admin /erp/*, halaman publik /, /order, /track,
            /login, /download). web/dist DI-COMMIT (dipakai deploy). API client web/src/api.js
            menyuntik branch_id otomatis.
- mobile/   Flutter (Android). lib/pages/*, lib/services/thermal_printer.dart (cetak
            Bluetooth), lib/services/qr_sheet.dart (QR meja A5), lib/branch_service.dart.
- database/ schema.sql + migrate-01 s/d migrate-10 (urut, idempoten, dijalankan manual).
- tools/, docs/, graphify-out/ (knowledge graph).

## 2. Konsep bisnis yang HARUS dipahami
- Multi-cabang: stok per cabang (stock_branch_items, katalog bahan bersama), transaksi/
  pesanan/shift/kas per cabang (kolom branch_id). Owner (& admin/gudang tak terkunci) memilih
  cabang di header; kasir mengikuti cabang SHIFT yang ia buka. Shift dibuka/ditutup PER CABANG.
- Cabang tanpa shift terbuka = TUTUP: POS dan pesanan online ditolak.
- Role: owner (semua), admin (tanpa Gaji/Karyawan/Keuangan), kasir (POS, Pesanan Online,
  Absensi), karyawan (Absensi), gudang (Absensi + Stock), leader (Absensi semua karyawan +
  Karyawan terbatas: jadwal, rotasi cabang; TANPA tarif/kasbon/akun). Pesanan/shift hanya
  owner/admin/kasir. Cek matriks akses lewat web/src/auth.js, server/src/index.js,
  mobile/lib/pages/erp_shell.dart.
- Tagihan: subtotal + pajak + biaya layanan (persen, settings), lalu pembulatan ke atas
  per Rp1.000 bila aktif (orders.rounding_amount). Di tampilan pelanggan/struk pembulatan
  DIGABUNG ke baris Service; di sistem tetap terpisah.
- Pesanan online: QR meja / delivery / pickup, bayar QRIS statis + ACC manual, lacak lewat
  kode pelacakan 8 karakter atau nomor JS-... (nomor saja = tampilan ringkas tanpa data pribadi).
- Struk Bluetooth Android: hanya LUNAS + blok "Aira Dynamics" di bawah (tanpa QR/nomor/footer).

## 3. Server & deploy produksi (hati-hati: ini produksi sungguhan)
- URL: https://juragan-seblak.airadynamics.com ; SSH alias `gema-prod` (user ubuntu, aaPanel/nginx).
- Repo server: /home/ubuntu/apps/juragan-seblak ; backend PM2 `juragan-seblak-api` ;
  DB MariaDB `juragan_seblak` (kredensial di server/.env di server — jangan dicetak/di-commit);
  docroot /www/wwwroot/juragan-seblak.airadynamics.com ; backup di /home/ubuntu/backups.
- Alur rilis: (1) uji lokal, (2) commit + push ke GitHub main, (3) BACKUP DB dulu bila ada
  migrasi/ubah data, (4) di server: git pull, jalankan migrasi SQL bila ada, salin web/dist ke
  docroot (`sudo cp -r web/dist/. docroot`, chown www:www), `pm2 restart juragan-seblak-api`,
  (5) verifikasi (health, endpoint terkait). PATH node di server: /home/ubuntu/node/bin.
- JANGAN mengubah/menghapus data produksi (pesanan, akun, stok, transaksi) tanpa izin eksplisit
  dan backup. Perubahan data produksi harus dikonfirmasi ke saya dulu. Jangan mengubah password
  akun siapa pun.
- Pengaman otomatis kadang menolak perintah yang menyentuh akun/akses di produksi. Bila
  ditolak, JANGAN cari jalan memutar — berhenti dan jelaskan apa yang dibutuhkan.

## 4. Lingkungan lokal (Windows)
- MySQL lokal: bila mati, nyalakan hanya instance 3306:
  `"C:/Program Files/MySQL/MySQL Server 8.4/bin/mysqld.exe" --defaults-file=D:/mysql-conf/my.ini --console`
  (jalankan di background). Data lokal = data uji; kembalikan seperti semula setelah menguji.
- Backend lokal: `node server/src/index.js` (port 3001). Web dev: preview `web-dev`
  (.claude/launch.json) port 5173 dengan proxy ke 3001.
- Uji dengan token JWT buatan sendiri dari JWT_SECRET lokal atau akun uji `zz-...@uji.test`
  (hapus setelahnya). Tulis skrip uji di scratchpad, bukan di repo.
- Build web: `cd web && npm run build` (dist harus ikut di-commit).
- Build APK (Windows): wajib `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=D:\jtmp`
  (folder D:\jtmp harus ada), lalu `flutter build apk --release` dari folder mobile
  (PowerShell; flutter di D:\flutter\bin, JAVA_HOME=D:\android-build\jdk-21.0.12.1+1,
  ANDROID_HOME=D:\android-build\sdk). Naikkan `version:` di mobile/pubspec.yaml, salin APK ke
  web/public/apk/juragan-seblak.apk, naikkan `?v=` + teks versi di web/src/pages/Download.jsx.
- Analisis Flutter: `flutter analyze` (info/saran gaya boleh; error tidak boleh).

## 5. Jebakan yang sudah pernah terjadi (jangan diulang)
- Plugin print_bluetooth_thermal hanya menerima List<int>; Uint8List diam-diam ditolak.
  Selalu `List<int>.from(bytes)`. Semua teks cetak (dinamis & statis) harus ASCII.
- Perubahan di web yang menyangkut data per cabang: pastikan endpoint memakai resolveBranch()
  / branchCond() di server dan jalur "Semua cabang" tidak dipakai untuk menulis data.
- Halaman admin harus punya padding sendiri (<main className="flex-1 min-w-0 p-5 md:p-8 ...">);
  halaman di dalam rute bersarang (Keuangan) mewarisinya dari layout.
- Kesalahan kecil yang berulang: nilai ENUM role di DB harus ikut diubah bila role baru ditambah
  (routes/users.js menjalankan ALTER otomatis saat start).
- Jangan menaruh kredensial/password/hash di repo. Password awal akun dibagikan lewat chat,
  bukan disimpan.
- Aplikasi Android lama tidak mengenal fitur baru; tiap rilis APK perlu info "pasang ulang".

## 6. Cara kerja yang saya harapkan
1. Reproduksi tiap bug dulu (lokal), temukan AKAR masalah dengan bukti (jangan menebak).
2. Perbaiki seminimal mungkin; pertahankan gaya kode sekitar; tambahkan komentar singkat
   hanya bila alasannya tidak jelas dari kode.
3. Uji: skrip/curl untuk API, browser untuk tampilan web (desktop & lebar HP), analyze/build
   untuk mobile. Bersihkan data uji.
4. Setelah semua bug selesai dan lulus uji: update graph, commit (pesan jelas, akhiri dengan
   baris Co-Authored-By sesuai instruksi sesi), push, lalu deploy ke server sesuai alur di
   atas BILA saya setuju. Tanyakan dulu sebelum deploy jika perubahan menyentuh data/akun/
   pembayaran.
5. Laporan akhir (bahasa Indonesia, ringkas): per bug → penyebab, perbaikan, cara uji,
   status deploy. Katakan terus terang bila sesuatu belum diuji (mis. perangkat fisik/printer).
   Sertakan versi APK bila ada rilis baru.

## 7. DAFTAR BUG (isi sebelum mengirim)
Format per bug: [Halaman/fitur] Langkah singkat → hasil sekarang → hasil yang diharapkan
(+ lampirkan tangkapan layar / pesan error bila ada). Platform: web / Android / keduanya.

1. ...
2. ...
3. ...

Prioritas: (urutan di atas = urutan pengerjaan) / (tandai yang mendesak dengan [URGENT])
```
