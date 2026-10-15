# Catatan Teknis — Cetak Struk via Printer Bluetooth (Flutter, Android)

Dokumen ini merangkum masalah cetak Bluetooth yang dialami saat membangun aplikasi
Juragan Seblak (Oktober 2026), penyebab sebenarnya, dan solusinya. Disimpan sebagai
pengetahuan untuk aplikasi lain yang memakai printer termal Bluetooth.

- Printer uji: **RPP02N** (termal 58 mm, ESC/POS, Bluetooth Classic/SPP)
- HP uji: Infinix NOTE 50 Pro (Android 12+)
- Paket Flutter: `print_bluetooth_thermal ^1.2.4`, `esc_pos_utils_plus ^2.0.4`,
  `permission_handler ^11`
- File terkait: `mobile/lib/services/thermal_printer.dart`

---

## 1. Ringkasan satu paragraf

Printer sebenarnya sehat. Gejala "printer terhubung tapi tidak mencetak / tidak
merespons" disebabkan **bug di kode aplikasi**: data dikirim ke plugin sebagai
`Uint8List`, padahal plugin hanya menerima `List<int>`. Plugin lalu langsung
mengembalikan `false` tanpa mengirim satu byte pun ke printer. Beberapa dugaan awal
(printer murah, ukuran data, perintah QR/potong kertas) **keliru** dan membuang waktu.

---

## 2. Kronologi gejala

| Tahap | Gejala yang terlihat | Penyebab nyata |
|---|---|---|
| 1 | Daftar printer berisi speaker/headset, printer "tidak terdeteksi" | Lembar pilihan tidak bisa di-scroll; printer (RPP02N) ada di bawah dan terpotong. Daftar = semua perangkat yang pernah dipasangkan, bukan hasil scan. |
| 2 | Cetak resep dapur: `Invalid argument(s) (string): Contains invalid characters` | Teks statis memakai tanda "—" (em dash). `esc_pos_utils_plus` menolak karakter non-ASCII pada `gen.text()`. |
| 3 | Cetak tes: lampu printer merah menjadi biru + bunyi klik (artinya tersambung), tetapi aplikasi menampilkan "Printer tidak merespons" | `writeBytes` mengembalikan `false` karena tipe data salah (lihat bagian 3). |
| 4 | Setelah ditambah chunking, retry, mode aman: tetap gagal "potongan 1/9" | Semua percobaan tetap mengirim `Uint8List`, jadi semuanya ditolak plugin yang sama. |
| 5 | Menu **Diagnosa** (mengirim `List<int>` biasa) berhasil mencetak teks, huruf besar, QR, potong kertas | Bukti bahwa printer & koneksi sehat; hanya jalur kirim aplikasi yang salah. |

---

## 3. Akar masalah utama: `Uint8List` vs `List<int>`

Kode native plugin (`PrintBluetoothThermalPlugin.kt`):

```kotlin
val lista = call.arguments as? List<Int>
val stream = outputStream
if (lista == null || stream == null) {
    result.success(false)   // <- langsung false, tidak ada yang dikirim
    return
}
```

Platform channel Flutter mengirim `Uint8List` sebagai **ByteArray** di sisi Kotlin,
bukan `List`. Cast `as? List<Int>` menghasilkan `null`, sehingga plugin mengembalikan
`false` tanpa error apa pun. Dari sisi Dart hanya terlihat `writeBytes(...) == false`,
yang mudah disangka "printer menolak".

Kenapa Diagnosa berhasil: `gen.reset()`, `gen.text()`, `gen.qrcode()`, dan
`'teks'.codeUnits` semuanya bertipe `List<int>`. Sedangkan `BytesBuilder().toBytes()`
(yang dipakai membangun struk) bertipe `Uint8List`.

### Perbaikan

```dart
// SALAH: Uint8List dikirim apa adanya
await PrintBluetoothThermal.writeBytes(bytes);

// BENAR: ubah ke List<int> biasa
await PrintBluetoothThermal.writeBytes(List<int>.from(bytes));
```

Kirim sekali jalan. Plugin sendiri memecah per 16 KB dan **menambahkan satu baris kosong
('\n') di awal setiap panggilan**, sehingga memotong data kecil-kecil justru:
menambah baris kosong, dan bisa membelah perintah ESC/POS di tengah.

---

## 4. Masalah-masalah lain yang ditemukan sepanjang jalan

### 4.1 Karakter non-ASCII
Printer termal default memakai codepage CP437. Em dash, kutip melengkung, bullet "·",
dan emoji menjadi sampah atau, di `esc_pos_utils_plus`, melempar exception.
- Bersihkan **semua** string dinamis (nama menu, catatan, nama toko) dengan fungsi
  `_clean()`.
- Periksa juga **string statis di template** (inilah yang lolos dan menyebabkan error
  resep dapur).
- Tips cek cepat: cari karakter di luar `\x20-\x7E` pada semua teks yang masuk
  `gen.text()` / `PosColumn`.

### 4.2 Izin Bluetooth Android 12+
- Perlu `BLUETOOTH_CONNECT` dan `BLUETOOTH_SCAN` (runtime). Di Android 11 ke bawah izin
  ini tidak ada dan dilaporkan "denied" padahal tidak diperlukan.
- Jangan memblokir cetak hanya karena `bluetoothEnabled`/izin melaporkan false di
  beberapa ROM. Coba sambung dulu; bila gagal, baru tampilkan pesan yang menyebut izin.

### 4.3 Daftar printer penuh perangkat lain
`pairedBluetooths` mengembalikan semua perangkat yang pernah dipasangkan (speaker,
headset, jam tangan, mobil). Solusi UI:
- daftar bisa di-scroll (`isScrollControlled` + `Flexible(ListView)`),
- urutkan: printer tersimpan, lalu nama mirip printer (`rpp`, `mtp`, `pt-`, `printer`,
  `pos`, `zj-`, `xp-`, `tm-` ...), lalu sisanya,
- tambahkan kolom cari bila perangkat banyak.

### 4.4 Koneksi basi dan satu-satunya klien
Printer Bluetooth klasik biasanya hanya menerima **satu koneksi**. Aplikasi printer
lain yang masih tersambung akan memblokir. Setelah `writeBytes` gagal, plugin
memutus koneksi sendiri; sambung ulang (`disconnect` -> jeda ~300 ms -> `connect` ->
jeda ~500 ms) sebelum mencoba lagi.

### 4.5 Template hemat perintah untuk printer murah (cadangan)
Disediakan tiga tingkat; yang berhasil diingat di `SharedPreferences`:
1. **full** — huruf besar/tebal, QR, potong kertas
2. **safe** — tanpa QR dan potong kertas (sebagian printer 58 mm tanpa pemotong)
3. **plain** — hanya `ESC @` + teks ASCII 32 kolom

Setelah akar masalah (bagian 3) diperbaiki, tingkat **full** berjalan normal di
RPP02N; tingkat cadangan dibiarkan sebagai jaring pengaman.

---

## 5. Alat bantu yang terbukti berguna: menu Diagnosa

Satu layar yang menjalankan langkah demi langkah dan menampilkan OK/GAGAL:
izin -> status Bluetooth -> sambung -> reset -> teks polos -> huruf tebal/besar ->
dorong kertas -> QR -> potong kertas. Menu ini yang akhirnya menunjukkan bahwa printer
sehat dan membuka petunjuk bahwa bedanya ada pada **tipe data**.

Pelajaran: **bangun menu diagnosa/cetak-tes sejak awal**, dan buat cetak-tes memakai
jalur kode yang SAMA dengan cetak struk sungguhan.

---

## 6. Checklist untuk aplikasi baru yang mencetak ke printer Bluetooth

- [ ] Selalu kirim `List<int>.from(bytes)` ke `writeBytes` (bukan `Uint8List`).
- [ ] Kirim sekali jalan; jangan dipotong kecil-kecil (plugin menambah `\n` per panggilan).
- [ ] Semua teks (dinamis **dan statis**) dibersihkan ke ASCII.
- [ ] Minta izin `BLUETOOTH_CONNECT` + `BLUETOOTH_SCAN` (Android 12+), tapi jangan
      memblokir bila status izin/bluetooth ambigu; coba sambung dulu.
- [ ] Daftar perangkat: scroll, urutkan printer di atas, ada pencarian.
- [ ] Simpan MAC printer terakhir; sambung otomatis; sambung ulang bila gagal.
- [ ] Sediakan menu Printer: pilih/ganti, cetak tes, diagnosa, lupakan printer.
- [ ] Siapkan template cadangan (tanpa QR/potong kertas/teks polos).
- [ ] Uji di HP dan printer fisik; emulator tidak bisa menguji Bluetooth.
- [ ] Tampilkan pesan error yang spesifik (izin / tidak tersambung / data ditolak),
      jangan satu pesan umum.

---

## 7. Catatan lingkungan build (Windows) — bukan masalah printer, tapi menghabiskan waktu

Gejala: `flutter build apk` gagal dengan
`java.io.IOException: Unable to establish loopback connection`.

Penyebab: di mesin ini Java (JDK 21) tidak bisa membuat soket **AF_UNIX** di folder
temp pengguna (`...\DESIGN~1\...`); `connect` ditolak ("Invalid argument"). Gradle
membutuhkannya lewat `Selector.open()`.

Solusi (tanpa mengubah file proyek): arahkan direktori soket ke path pendek.

```powershell
New-Item -ItemType Directory -Force D:\jtmp
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=D:\jtmp"
flutter build apk --release
```

(Opsi `-Djava.io.tmpdir=` saja tidak cukup; yang berpengaruh adalah
`jdk.net.unixdomain.tmpdir`.)

---

## 8. Pelajaran umum

1. **Jangan menebak penyebab dari gejala.** "Printer murah tidak kuat" terdengar masuk
   akal tetapi salah; bukti (Diagnosa OK) yang membantahnya.
2. Bila sebuah panggilan plugin mengembalikan `false` tanpa pesan, **baca kode native
   plugin**-nya (`~/.pub-cache/hosted/pub.dev/<paket>/android/...`) — di sini jawabannya
   hanya satu baris.
3. Perhatikan tipe data lintas platform channel: `Uint8List` -> `ByteArray`,
   `List<int>` -> `List<Int>`; plugin yang melakukan cast longgar (`as?`) menelan
   kesalahan secara diam-diam.
4. Tambahkan alat diagnosa ke aplikasi; lebih murah daripada bolak-balik membangun APK.
