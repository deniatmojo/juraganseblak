import { useState } from 'react'
import { Link } from 'react-router-dom'

const ChiliIcon = ({ className = 'w-4 h-4' }) => (
  <svg className={`${className} text-chili chili-icon`} viewBox="0 0 24 24" fill="currentColor">
    <path d="M14.5 3c-1.4 1-1.7 2.6-.9 4.1-2 .1-4 1-5.4 2.7C5.8 12.4 5 15.6 6 18.4c.9 2.5 3.1 3.9 5.4 3.6 3.3-.4 6.6-3.2 7.7-6.9 1-3.4.1-7.4-2.4-9.7-.6.9-1.6 1.4-2.7 1.3.5-1.3.4-2.6-.3-3.7-.4.4-.8.7-1.2.9-.5.3-1 .1-1.2-.4-.1-.3 0-.6.2-.9z" />
  </svg>
)

const navLinks = [
  { href: '#home', label: 'Home' },
  { href: '#buffet', label: 'Buffet' },
  { href: '#menu', label: 'Paket' },
  { href: '#testimoni', label: 'Testimoni' },
  { href: '#lokasi', label: 'Lokasi' },
]

const buffetItems = [
  {
    img: '/images/buffet-meat.jpg',
    alt: 'Daging Premium',
    title: 'Premium Meat',
    desc: 'US Beef Belly, Saikoro, & Ayam Marinasi.',
  },
  {
    img: '/images/buffet-seafood.jpg',
    alt: 'Seafood Segar',
    title: 'Seafood Bar',
    desc: 'Udang, Cumi, Kerang Hijau, & Ikan Dori.',
  },
  {
    img: '/images/buffet-topping.jpg',
    alt: 'Topping & Dimsum',
    title: 'Topping & Dimsum',
    desc: 'Aneka Bakso, Sosis, Sayuran & Jamur Segar.',
  },
  {
    img: '/images/buffet-sambal.jpg',
    alt: 'Sambal Station',
    title: 'Surga Sambal',
    desc: '15+ Varian Sambal. Racik pedasmu sendiri!',
  },
]

const menuCards = [
  {
    img: '/images/menu-geprek.jpg',
    alt: 'Ayam geprek sambal bawang',
    title: 'Ayam Geprek Sambal Bawang',
    desc: 'Ayam krispi digeprek dengan sambal bawang segar.',
    paket: 'Paket Reguler',
    level: 2,
  },
  {
    img: '/images/menu-mie.jpg',
    alt: 'Mie pedas level extreme',
    title: 'Mie Setan Level Extreme',
    desc: 'Mie kenyal dengan racikan cabai rawit asli yang menantang.',
    paket: 'Paket Reguler',
    level: 3,
  },
  {
    img: '/images/menu-iga.jpg',
    alt: 'Sup pedas iga bakar',
    title: 'Sup Iga Bakar Cabe Rawit',
    desc: 'Iga sapi empuk dibakar lalu disiram kuah kaldu pedas segar.',
    paket: 'Paket Premium',
    level: 2,
  },
]

const testimonials = [
  {
    quote: '"Pilihan di area buffet-nya gila sih banyak banget! Seafood sama dagingnya fresh, sausnya juga juara."',
    name: 'Dinda Ayu',
    role: 'Pelanggan Tetap',
    img: 'https://randomuser.me/api/portraits/women/44.jpg',
  },
  {
    quote: '"Mie Setan Level Extreme itu jujur bikin nangis, tapi malah nagih. Pelayanannya juga ramah dan cepat."',
    name: 'Bagas Pratama',
    role: 'Food Vlogger',
    img: 'https://randomuser.me/api/portraits/men/32.jpg',
  },
  {
    quote: '"Cocok buat acara keluarga, anak-anak bisa pilih level pedas yang ringan, orang dewasa bisa tantang diri sendiri."',
    name: 'Sinta Wulandari',
    role: 'Ibu Rumah Tangga',
    img: 'https://randomuser.me/api/portraits/women/68.jpg',
  },
]

const wallOfFame = [
  { img: '/images/fame-1.jpg', name: 'Reza R.', role: 'Aktor Film', offset: false },
  { img: '/images/fame-2.jpg', name: 'Anya G.', role: 'Selebgram & Aktris', offset: true },
  { img: '/images/fame-3.jpg', name: 'Boy W.', role: 'Presenter & Vlogger', offset: false },
  { img: '/images/fame-4.jpg', name: 'Isyana S.', role: 'Penyanyi & Musisi', offset: true },
]

export default function Landing() {
  const [menuOpen, setMenuOpen] = useState(false)

  return (
    <div className="bg-cream text-char antialiased">
      {/* NAVBAR */}
      <header className="fixed top-0 inset-x-0 z-50 bg-char/95 backdrop-blur border-b border-char-line">
        <nav className="max-w-7xl mx-auto px-5 md:px-8 h-16 md:h-20 flex items-center justify-between">
          <a href="#home" className="font-display text-2xl md:text-3xl text-cream tracking-wide">
            BARA<span className="text-chili">.</span>PEDAS
          </a>

          <ul className="hidden md:flex items-center gap-9 text-sm font-semibold text-cream/80">
            {navLinks.map((link) => (
              <li key={link.href}>
                <a href={link.href} className="hover:text-ember transition-colors">{link.label}</a>
              </li>
            ))}
          </ul>

          <div className="flex items-center gap-3">
            <Link
              to="/login"
              className="hidden md:inline-block border border-cream/40 hover:border-ember hover:text-ember text-cream text-sm font-bold px-5 py-2.5 rounded-full transition-colors"
            >
              Login ERP
            </Link>
            <Link
              to="/order"
              className="hidden md:inline-block bg-chili hover:bg-chili-dark text-white text-sm font-bold px-5 py-2.5 rounded-full transition-colors"
            >
              Order Now
            </Link>
            <button
              onClick={() => setMenuOpen(!menuOpen)}
              aria-label="Buka menu navigasi"
              aria-expanded={menuOpen}
              className="md:hidden text-cream p-2"
            >
              {menuOpen ? (
                <svg className="h-7 w-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              ) : (
                <svg className="h-7 w-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              )}
            </button>
          </div>
        </nav>

        {/* Mobile menu */}
        <div className={`md:hidden overflow-hidden bg-char border-t border-char-line transition-all duration-300 ${menuOpen ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0'}`}>
          <ul className="flex flex-col px-5 py-4 gap-4 text-cream/90 font-semibold">
            {navLinks.map((link) => (
              <li key={link.href}>
                <a href={link.href} onClick={() => setMenuOpen(false)} className="block py-1">{link.label}</a>
              </li>
            ))}
            <li>
              <Link to="/order" className="block text-center bg-chili text-white font-bold px-5 py-3 rounded-full mt-2">Order Now</Link>
            </li>
            <li>
              <Link to="/login" className="block text-center border border-cream/40 text-cream font-bold px-5 py-3 rounded-full">Login ERP</Link>
            </li>
          </ul>
        </div>
      </header>

      {/* HERO */}
      <section id="home" className="relative min-h-[92vh] flex items-end pt-24 pb-16 md:pb-24">
        <div className="absolute inset-0 z-0 bg-char">
          <img
            src="/images/hero.jpg"
            alt="Hidangan pedas dengan cabai segar"
            loading="eager"
            onError={(e) => { e.currentTarget.style.display = 'none' }}
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-char via-char/80 to-char/30"></div>
          <div className="absolute inset-0 bg-gradient-to-r from-char/70 via-transparent to-transparent"></div>
        </div>

        <div className="relative z-10 max-w-7xl mx-auto px-5 md:px-8 w-full">
          <div className="max-w-2xl">
            <span className="inline-flex items-center gap-2 text-ember font-bold text-sm mb-5">
              <ChiliIcon className="w-5 h-5" />
              Level Pedas 1–10, Kamu yang Pilih
            </span>

            <h1 className="font-display text-5xl sm:text-6xl lg:text-7xl leading-[0.95] text-white uppercase">
              Makan Sepuasnya,<br />
              <span className="drip-underline text-ember">Pedasnya</span> Tanpa Batas
            </h1>

            <p className="mt-6 text-cream/80 text-base md:text-lg max-w-lg">
              Bara.Pedas menyajikan konsep All You Can Eat dengan racikan sambal rumahan,
              aneka lauk bakar, dan mie pedas legendaris. Satu harga, sepuasnya, sampai keringetan.
            </p>

            <div className="mt-9 flex flex-wrap gap-4">
              <Link to="/order" className="bg-chili hover:bg-chili-dark text-white font-bold px-7 py-3.5 rounded-full transition-colors text-sm md:text-base">
                Order Now
              </Link>
              <a href="#lokasi" className="border border-cream/40 hover:border-ember hover:text-ember text-cream font-bold px-7 py-3.5 rounded-full transition-colors text-sm md:text-base">
                Reservasi Dine-in
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* FREE FLOW BUFFET STATION */}
      <section id="buffet" className="py-20 md:py-28 bg-white border-b border-black/5">
        <div className="max-w-7xl mx-auto px-5 md:px-8">
          <div className="max-w-2xl mb-12 md:mb-16">
            <p className="text-ember font-bold text-sm mb-2">Free Flow Station</p>
            <h2 className="font-display text-4xl md:text-5xl uppercase leading-tight">Ambil Sesukamu, Rakit Piringmu</h2>
            <p className="mt-4 text-char/80 text-lg">
              Esensi sejati dari All You Can Eat! Ratusan pilihan bahan segar menantimu di area prasmanan kami.
              Ambil daging, seafood, sayuran, dan racik bumbu pedas andalanmu sendiri tanpa batas.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {buffetItems.map((item) => (
              <div key={item.title} className="group relative overflow-hidden rounded-2xl aspect-[4/5] bg-char">
                <img src={item.img} alt={item.alt} className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110 opacity-90" />
                <div className="absolute inset-0 bg-gradient-to-t from-char via-char/40 to-transparent"></div>
                <div className="absolute bottom-0 left-0 p-6">
                  <h3 className="text-white font-display text-2xl mb-1 tracking-wide">{item.title}</h3>
                  <p className="text-cream/80 text-sm">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* MENU / PAKET */}
      <section id="menu" className="py-20 md:py-28 bg-cream">
        <div className="max-w-7xl mx-auto px-5 md:px-8">
          <div className="max-w-xl mb-12 md:mb-16">
            <p className="text-chili font-bold text-sm mb-2">Paket &amp; Menu Unggulan</p>
            <h2 className="font-display text-4xl md:text-5xl uppercase leading-tight">Pilih Paket Panasmu</h2>
            <p className="mt-4 text-char/70">
              Selain bebas ambil di buffet, kami juga menyediakan menu signature langsung dari dapur
              yang bisa kamu pesan sepuasnya sesuai paket yang dipilih.
            </p>
          </div>

          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-7">
            {menuCards.map((card) => (
              <article key={card.title} className="menu-card bg-white rounded-2xl overflow-hidden border border-black/5 shadow-sm">
                <img src={card.img} alt={card.alt} className="w-full h-52 object-cover" />
                <div className="p-6">
                  <div className="flex items-center gap-1 mb-3">
                    {Array.from({ length: card.level }).map((_, i) => (
                      <ChiliIcon key={i} />
                    ))}
                  </div>
                  <h3 className="font-bold text-lg">{card.title}</h3>
                  <p className="text-char/60 text-sm mt-1.5">{card.desc}</p>
                  <p className="mt-4 font-display text-2xl text-chili">{card.paket}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* TESTIMONI */}
      <section id="testimoni" className="py-20 md:py-28 bg-char text-cream relative overflow-hidden">
        <div className="max-w-7xl mx-auto px-5 md:px-8">
          <div className="max-w-xl mb-12">
            <p className="text-ember font-bold text-sm mb-2">Kata Mereka</p>
            <h2 className="font-display text-4xl md:text-5xl uppercase leading-tight">Yang Sudah Coba, Ketagihan</h2>
          </div>

          <div className="mb-14 rounded-2xl overflow-hidden border border-char-line shadow-2xl relative bg-black max-w-4xl mx-auto">
            <video
              controls
              className="w-full aspect-video object-cover"
              poster="/images/poster-video.jpg"
            >
              <source src="https://www.w3schools.com/html/mov_bbb.mp4" type="video/mp4" />
              Browser Anda tidak mendukung tag video.
            </video>
            <div className="absolute top-4 left-4 bg-chili text-white text-xs font-bold px-4 py-2 rounded-full z-10 shadow-md tracking-wide uppercase">
              📹 Review Food Vlogger
            </div>
          </div>

          <div className="grid md:grid-cols-3 gap-7">
            {testimonials.map((t) => (
              <blockquote key={t.name} className="bg-char-soft border border-char-line rounded-2xl p-7">
                <p className="text-cream/80 leading-relaxed">{t.quote}</p>
                <footer className="mt-6 flex items-center gap-3">
                  <img src={t.img} alt={`Foto profil ${t.name}`} className="w-11 h-11 rounded-full object-cover" />
                  <div>
                    <p className="font-bold text-sm">{t.name}</p>
                    <p className="text-xs text-cream/50">{t.role}</p>
                  </div>
                </footer>
              </blockquote>
            ))}
          </div>
        </div>
      </section>

      {/* WALL OF FAME */}
      <section id="wall-of-fame" className="py-20 md:py-28 bg-white border-b border-black/5">
        <div className="max-w-7xl mx-auto px-5 md:px-8">
          <div className="max-w-2xl mb-12 md:mb-16 mx-auto text-center">
            <p className="text-ember font-bold text-sm mb-2">Wall of Fame</p>
            <h2 className="font-display text-4xl md:text-5xl uppercase leading-tight">Artis Aja Langganan</h2>
            <p className="mt-4 text-char/70">
              Dari selebriti papan atas hingga food vlogger terhits, semuanya pernah berkeringat
              menikmati hidangan pedas andalan kami.
            </p>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-6">
            {wallOfFame.map((artis) => (
              <div key={artis.name} className={`group relative overflow-hidden rounded-2xl aspect-[3/4] bg-char shadow-sm ${artis.offset ? 'md:translate-y-6' : ''}`}>
                <img src={artis.img} alt={`Dokumentasi ${artis.name}`} className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110" />
                <div className="absolute inset-0 bg-gradient-to-t from-char/90 via-char/20 to-transparent"></div>
                <div className="absolute bottom-0 left-0 w-full p-5 text-center translate-y-2 group-hover:translate-y-0 transition-transform">
                  <p className="text-white font-bold text-lg">{artis.name}</p>
                  <p className="text-ember text-xs font-semibold">{artis.role}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* LOKASI */}
      <section id="lokasi" className="py-20 md:py-28 bg-cream">
        <div className="max-w-7xl mx-auto px-5 md:px-8 grid lg:grid-cols-2 gap-10 items-stretch">
          <div>
            <p className="text-chili font-bold text-sm mb-2">Lokasi &amp; Kontak</p>
            <h2 className="font-display text-4xl md:text-5xl uppercase leading-tight mb-6">Datang, Duduk, Berkeringat</h2>

            <div className="space-y-5 text-char/80">
              <div className="flex gap-4">
                <svg className="w-6 h-6 text-chili shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M17.657 16.657L13.414 20.9a2 2 0 01-2.828 0l-4.243-4.243a8 8 0 1111.314 0z" /><circle cx="12" cy="11" r="3" /></svg>
                <p>Jl. Raya Darmo No. 12, Wonokromo, Surabaya, Jawa Timur 60241</p>
              </div>
              <div className="flex gap-4">
                <svg className="w-6 h-6 text-chili shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                <p>Setiap hari, 11.00 – 22.00 WIB</p>
              </div>
              <div className="flex gap-4">
                <svg className="w-6 h-6 text-chili shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" /></svg>
                <p>0812-3456-7890 (WhatsApp / Telepon)</p>
              </div>
              <div className="flex gap-4">
                <svg className="w-6 h-6 text-chili shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>
                <p>halo@barapedas.id</p>
              </div>
            </div>

            <Link to="/order" className="inline-block mt-8 bg-chili hover:bg-chili-dark text-white font-bold px-7 py-3.5 rounded-full transition-colors">
              Reservasi Meja Sekarang
            </Link>
          </div>

          <div className="rounded-2xl overflow-hidden border border-black/10 min-h-[320px] shadow-sm">
            <iframe
              src="https://www.google.com/maps?q=Jl.+Raya+Darmo,+Surabaya&output=embed"
              className="w-full h-full min-h-[320px]"
              style={{ border: 0 }}
              allowFullScreen=""
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
              title="Lokasi Bara.Pedas di Google Maps"
            ></iframe>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="bg-char text-cream/70 border-t border-char-line py-10">
        <div className="max-w-7xl mx-auto px-5 md:px-8 flex flex-col md:flex-row items-center justify-between gap-6">
          <p className="font-display text-xl text-cream tracking-wide">BARA<span className="text-chili">.</span>PEDAS</p>
          <p className="text-sm text-center">&copy; 2026 Bara.Pedas. Seluruh hak cipta dilindungi.</p>
          <div className="flex items-center gap-5">
            <a href="#" aria-label="Instagram" className="hover:text-ember transition-colors">
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.2c3.2 0 3.58.01 4.85.07 1.17.05 1.97.24 2.43.4a4.9 4.9 0 011.77 1.15 4.9 4.9 0 011.15 1.77c.16.46.35 1.26.4 2.43.06 1.27.07 1.65.07 4.85s-.01 3.58-.07 4.85c-.05 1.17-.24 1.97-.4 2.43a4.9 4.9 0 01-1.15 1.77 4.9 4.9 0 01-1.77 1.15c-.46.16-1.26.35-2.43.4-1.27.06-1.65.07-4.85.07s-3.58-.01-4.85-.07c-1.17-.05-1.97-.24-2.43-.4a4.9 4.9 0 01-1.77-1.15 4.9 4.9 0 01-1.15-1.77c-.16-.46-.35-1.26-.4-2.43C2.21 15.58 2.2 15.2 2.2 12s.01-3.58.07-4.85c.05-1.17.24-1.97.4-2.43a4.9 4.9 0 011.15-1.77A4.9 4.9 0 015.6 2.8c.46-.16 1.26-.35 2.43-.4C9.3 2.34 9.68 2.33 12 2.33m0 4.65a5.02 5.02 0 100 10.04 5.02 5.02 0 000-10.04zm0 8.28a3.26 3.26 0 110-6.52 3.26 3.26 0 010 6.52zm5.4-8.48a1.17 1.17 0 110-2.34 1.17 1.17 0 010 2.34z" /></svg>
            </a>
            <a href="#" aria-label="TikTok" className="hover:text-ember transition-colors">
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M16.6 5.82c-.9-.78-1.48-1.9-1.6-3.15h-3.1v13.2a2.7 2.7 0 11-2.7-2.7c.24 0 .48.02.7.08V10.1a5.9 5.9 0 00-.7-.04A5.86 5.86 0 002.5 15.9a5.86 5.86 0 0011.7 0V9.4a7.9 7.9 0 004.4 1.33V7.6a4.85 4.85 0 01-2-1.78z" /></svg>
            </a>
            <a href="#" aria-label="Facebook" className="hover:text-ember transition-colors">
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M13.5 21v-7.5h2.5l.5-3h-3V8.5c0-.9.3-1.5 1.6-1.5H16.6V4.3C16.3 4.2 15.3 4 14.2 4c-2.4 0-4 1.5-4 4.1v2.4H7.7v3h2.5V21h3.3z" /></svg>
            </a>
          </div>
        </div>
      </footer>

      {/* FLOATING WHATSAPP */}
      <a
        href="https://wa.me/6281234567890"
        target="_blank"
        rel="noopener"
        aria-label="Chat via WhatsApp"
        className="fixed bottom-6 right-6 z-50 grid place-items-center w-14 h-14 rounded-full bg-[#25D366] shadow-xl hover:scale-105 transition-transform"
      >
        <span className="wa-pulse absolute inset-0 rounded-full"></span>
        <svg className="relative w-7 h-7 text-white" viewBox="0 0 24 24" fill="currentColor"><path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.29-1.39a9.9 9.9 0 004.75 1.21h.01c5.46 0 9.9-4.45 9.9-9.91C21.96 6.45 17.5 2 12.04 2zm5.8 14.02c-.24.68-1.4 1.3-1.94 1.38-.5.08-1.13.11-1.82-.11-.42-.13-.96-.31-1.66-.6-2.92-1.26-4.83-4.2-4.98-4.4-.15-.2-1.19-1.58-1.19-3.02 0-1.44.75-2.14 1.02-2.44.27-.29.6-.36.8-.36.2 0 .4 0 .58.01.19.01.44-.07.68.53.25.6.85 2.08.92 2.23.07.15.12.33.02.53-.1.2-.15.32-.3.5-.15.18-.31.4-.44.53-.15.15-.3.31-.13.6.17.3.77 1.28 1.65 2.07 1.14 1.02 2.1 1.34 2.4 1.49.3.15.47.13.65-.08.18-.2.75-.87.95-1.17.2-.3.4-.25.66-.15.27.1 1.7.8 1.99.95.29.15.48.22.55.34.07.13.07.72-.17 1.4z" /></svg>
      </a>
    </div>
  )
}
