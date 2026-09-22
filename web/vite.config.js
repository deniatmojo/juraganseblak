import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  // base absolut: wajib untuk deep-link SPA (/erp/absensi dll) — base relatif
  // membuat asset dimuat dari path salah saat reload di sub-route. (Capacitor
  // sudah tidak dipakai; aplikasi Android sekarang Flutter di mobile/.)
  base: '/',
  plugins: [react()],
  server: {
    // Proxy API & foto upload ke backend Express lokal saat dev
    proxy: {
      '/api': 'http://localhost:3001',
      '/uploads': 'http://localhost:3001',
    },
  },
})
