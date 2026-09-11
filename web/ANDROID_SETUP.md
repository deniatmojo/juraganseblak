# Setup Aplikasi Android (Capacitor)

Aplikasi Android dibangun dari build web React yang sama (`web/dist`), jadi tampilan
di Android **100% identik** dengan tampilan web mode ponsel. Tidak ada server yang
dibutuhkan — seluruh logika masih client-side (localStorage) seperti di web.

## Status

- Capacitor sudah ter-init: `capacitor.config.json` (appId `id.barapedas.juraganseblak`)
- Platform Android sudah dibuat di `web/android/`
- `vite.config.js` memakai `base: './'` agar aset bisa dimuat dari WebView

## Alur kerja harian

```bash
cd web
npm run cap:sync   # build web + copy ke android (jalankan setiap ada perubahan web)
npm run cap:open   # buka project di Android Studio (build & run dari sana)
```

## Prasyarat (sekali saja, belum terpasang di mesin ini)

1. **Android Studio** — https://developer.android.com/studio
   (sudah menyertakan JDK + Android SDK)
2. Set `JAVA_HOME` / `ANDROID_HOME` biasanya otomatis diatur oleh Android Studio.

## Build APK / AAB

- Lewat Android Studio: `Build > Build Bundle(s)/APK(s)`
- Lewat CLI (setelah SDK siap):
  ```bash
  cd web/android
  ./gradlew assembleDebug    # APK debug untuk tes
  ./gradlew bundleRelease    # AAB untuk Play Store
  ```

## Ganti ikon aplikasi

Taruh `assets/icon.png` (1024x1024, tanpa sudut membulat) + `assets/splash.png`
di folder `web/`, lalu jalankan:

```bash
cd web
npx @capacitor/assets generate --android
```

## Catatan penting

- **localStorage**: data login/akun tersimpan per-perangkat. Menghapus aplikasi
  = menghapus data. Kalau nanti pindah ke backend API (sesuai TODO di `src/auth.js`),
  app tinggal `cap:sync` ulang tanpa perubahan native.
- **Update konten**: setiap perubahan web harus `npm run cap:sync` lalu build APK baru
  (tidak bisa update OTA kecuali ditambah plugin semacam Capgo nanti).
- Folder `web/android/` **di-commit** ke git (praktik resmi Capacitor).
