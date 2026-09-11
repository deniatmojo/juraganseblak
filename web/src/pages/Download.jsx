import { Link } from 'react-router-dom'

const steps = [
  {
    title: 'Unduh APK',
    desc: 'Klik tombol "Unduh Aplikasi" di atas. File APK akan tersimpan di folder Download HP kamu.',
  },
  {
    title: 'Izinkan Instalasi',
    desc: 'Saat diminta, izinkan "Install from unknown sources" untuk browser kamu (hanya sekali saja).',
  },
  {
    title: 'Install & Login',
    desc: 'Buka file APK, tekan Install, lalu login dengan akun ERP seperti biasa di aplikasi.',
  },
]

export default function Download() {
  return (
    <div className="min-h-screen bg-cream text-char antialiased">
      <header className="bg-char border-b border-char-line">
        <nav className="max-w-7xl mx-auto px-5 md:px-8 h-16 md:h-20 flex items-center justify-between">
          <a href="/" className="font-display text-2xl md:text-3xl text-cream tracking-wide">
            BARA<span className="text-chili">.</span>PEDAS
          </a>
          <Link
            to="/"
            className="border border-cream/40 hover:border-ember hover:text-ember text-cream text-sm font-bold px-5 py-2.5 rounded-full transition-colors"
          >
            &larr; Kembali ke Home
          </Link>
        </nav>
      </header>

      <main className="max-w-3xl mx-auto px-5 md:px-8 py-14 md:py-20 text-center">
        <span className="inline-block bg-chili/10 text-chili text-xs font-bold tracking-widest uppercase px-4 py-1.5 rounded-full">
          Aplikasi Android
        </span>
        <h1 className="font-display text-4xl md:text-5xl mt-5 mb-4">
          Juragan Seblak di Sakumu
        </h1>
        <p className="text-char/70 text-lg mb-8">
          Kasir, absensi, stok, dan keuangan — semua dalam satu aplikasi Android.
          Tampilan dan fitur persis sama dengan versi web.
        </p>

        <a
          href="/apk/juragan-seblak.apk"
          download
          className="inline-flex items-center gap-3 bg-chili hover:bg-chili-dark text-white text-lg font-bold px-10 py-4 rounded-full transition-colors shadow-lg shadow-chili/30"
        >
          <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
            <path strokeLinecap="round" strokeLinejoin="round" d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M7 10l5 5 5-5M12 15V3" />
          </svg>
          Unduh Aplikasi (APK)
        </a>
        <p className="text-sm text-char/50 mt-4">Versi 1.0 &middot; Android 7.0+ &middot; ± ukuran file kecil</p>

        <div className="mt-14 grid gap-5 text-left">
          {steps.map((s, i) => (
            <div key={s.title} className="flex gap-4 bg-white/70 border border-char-line/50 rounded-2xl p-5">
              <span className="shrink-0 w-9 h-9 grid place-items-center bg-chili text-white font-display rounded-full">
                {i + 1}
              </span>
              <div>
                <h3 className="font-display text-lg mb-1">{s.title}</h3>
                <p className="text-char/70 text-sm">{s.desc}</p>
              </div>
            </div>
          ))}
        </div>

        <p className="mt-10 text-sm text-char/60">
          Lebih suka lewat browser? Aplikasi web tetap tersedia di{' '}
          <Link to="/login" className="text-chili font-bold hover:underline">halaman login</Link>.
        </p>
      </main>
    </div>
  )
}
