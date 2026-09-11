import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  // base relatif agar build bisa dijalankan dari WebView Capacitor (file://)
  base: './',
  plugins: [react()],
})
