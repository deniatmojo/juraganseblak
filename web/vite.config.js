import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  // base relatif agar build bisa dijalankan dari WebView Capacitor (file://)
  base: './',
  plugins: [react()],
  server: {
    // Proxy API & foto upload ke backend Express lokal saat dev
    proxy: {
      '/api': 'http://localhost:3001',
      '/uploads': 'http://localhost:3001',
    },
  },
})
