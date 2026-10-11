import CabangManager from './CabangManager'

// Halaman Cabang (owner): tambah/ubah cabang & titik lokasi absen. Cabang yang
// dibuat di sini otomatis dipakai stok, shift kasir, meja QR, dan laporan.
export default function Cabang() {
  return (
    <main className="flex-1 p-5 md:p-8">
      <CabangManager />
    </main>
  )
}
