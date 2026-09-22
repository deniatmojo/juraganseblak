import { useEffect, useRef, useState } from 'react'
import { NavLink, Link, Outlet, useNavigate, useLocation } from 'react-router-dom'
import { getCurrentUser, logout, isAllowed } from '../auth'
import { api } from '../api'

const headerMeta = {
  '/erp': { title: 'Dashboard', subtitle: 'Ringkasan operasional Juragan Seblak hari ini' },
  '/erp/pos': { title: 'Kasir / POS', subtitle: 'Meja 07 · Dine-in' },
  '/erp/menu': { title: 'Manajemen Menu', subtitle: 'Kelola menu, harga, HPP & kategori' },
  '/erp/absensi': { title: 'Absensi', subtitle: 'Kehadiran karyawan hari ini' },
  '/erp/stock': { title: 'Stok Bahan Baku', subtitle: 'Pantau ketersediaan bahan dapur' },
  '/erp/keuangan': { title: 'Laporan Keuangan', subtitle: 'Pemasukan & pengeluaran outlet' },
  '/erp/karyawan': { title: 'Karyawan', subtitle: 'Kelola akun login & data karyawan' },
  '/erp/gaji': { title: 'Gaji & Payroll', subtitle: 'Rekap gaji, kasbon, dan pembayaran' },
}

const navItems = [
  {
    to: '/erp',
    label: 'Dashboard',
    end: true,
    ownerOnly: true,
    icon: 'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6',
  },
  {
    to: '/erp/pos',
    label: 'Kasir / POS',
    icon: 'M3 10h18M3 6h18M4 6v12a1 1 0 001 1h14a1 1 0 001-1V6M9 14h6',
  },
  {
    to: '/erp/menu',
    label: 'Menu',
    ownerOnly: true,
    icon: 'M4 6h16M4 6v12a2 2 0 002 2h12a2 2 0 002-2V6M4 6l2-4h12l2 4M9 11h6',
  },
  {
    to: '/erp/absensi',
    label: 'Absensi',
    icon: 'M9 12l2 2 4-4m5-2a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  {
    to: '/erp/stock',
    label: 'Stock',
    ownerOnly: true,
    icon: 'M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4',
  },
  {
    to: '/erp/keuangan',
    label: 'Keuangan',
    ownerOnly: true,
    icon: 'M17 9V7a4 4 0 00-8 0v2m-2 0h12a2 2 0 012 2v7a2 2 0 01-2 2H7a2 2 0 01-2-2v-7a2 2 0 012-2z',
  },
  {
    to: '/erp/karyawan',
    label: 'Karyawan',
    ownerOnly: true,
    icon: 'M18 9v3m0 0v3m0-3h3m-3 0h-3m-4-4a4 4 0 11-8 0 4 4 0 018 0zM4 21v-1a5 5 0 015-5h2a5 5 0 015 5v1',
  },
  {
    to: '/erp/gaji',
    label: 'Gaji',
    ownerOnly: true,
    icon: 'M12 8c-1.66 0-3 .9-3 2s1.34 2 3 2 3 .9 3 2-1.34 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V6m0 10v2m9-8a9 9 0 11-18 0 9 9 0 0118 0z',
  },
]

export default function AdminLayout() {
  const navigate = useNavigate()
  const location = useLocation()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [now, setNow] = useState(new Date())
  const [user, setUser] = useState(getCurrentUser)
  const [lowStock, setLowStock] = useState([])
  const [notifOpen, setNotifOpen] = useState(false)
  const notifRef = useRef(null)

  const visibleNav = navItems.filter((item) => !item.ownerOnly || user?.role === 'owner')
  const roleLabel = { owner: 'Super Admin', admin: 'Admin', kasir: 'Karyawan Kasir', karyawan: 'Karyawan' }
  const meta = headerMeta[location.pathname] ?? { title: 'Dashboard', subtitle: '' }

  useEffect(() => {
    const current = getCurrentUser()
    if (!current) {
      navigate('/login')
    } else if (!isAllowed(current.role, location.pathname)) {
      // Karyawan hanya boleh di Absensi; selain itu khusus super admin.
      navigate('/erp/absensi', { replace: true })
    } else {
      setUser(current)
    }
  }, [navigate, location.pathname])

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  // Notifikasi stok kritis — refresh tiap 60 detik
  useEffect(() => {
    let mounted = true
    const load = () => {
      api.get('/stock')
        .then((items) => mounted && setLowStock(items.filter((i) => i.is_low)))
        .catch(() => {})
    }
    load()
    const timer = setInterval(load, 60000)
    return () => { mounted = false; clearInterval(timer) }
  }, [])

  // Tutup dropdown notif saat klik di luar
  useEffect(() => {
    const onClick = (e) => {
      if (notifRef.current && !notifRef.current.contains(e.target)) setNotifOpen(false)
    }
    document.addEventListener('mousedown', onClick)
    return () => document.removeEventListener('mousedown', onClick)
  }, [])

  const clock = now.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  const date = now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })

  const logoutSession = () => {
    logout()
    navigate('/login')
  }

  return (
    <div className="min-h-screen flex bg-cream text-char antialiased">
      {/* SIDEBAR */}
      <aside className={`fixed lg:sticky lg:top-0 lg:h-screen inset-y-0 left-0 z-40 w-64 bg-char text-cream flex flex-col transition-transform duration-300 ${sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}`}>
        <div className="h-20 flex items-center px-6 border-b border-char-line shrink-0">
          <Link to="/erp" className="font-display text-2xl tracking-wide">
            JURAGAN<span className="text-chili">.</span>SEBLAK
          </Link>
        </div>

        <div className="px-6 py-5 border-b border-char-line flex items-center gap-3 shrink-0">
          <div className="w-11 h-11 rounded-full bg-chili/20 grid place-items-center ring-2 ring-chili font-bold text-chili">
            {(user?.name ?? '?').charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0">
            <p className="font-bold text-sm truncate">{user?.name ?? 'Pengguna'}</p>
            <p className="text-xs text-cream/50">{roleLabel[user?.role] ?? 'Pengguna'}</p>
          </div>
        </div>

        <nav className="flex-1 overflow-y-auto px-3 py-5 space-y-1.5">
        {visibleNav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `nav-link flex items-center gap-3 px-3.5 py-3 rounded-xl font-semibold text-sm ${isActive ? 'active' : 'text-cream/70'}`
              }
            >
              <svg className="w-5 h-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path strokeLinecap="round" strokeLinejoin="round" d={item.icon} />
              </svg>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 border-t border-char-line shrink-0">
          <button onClick={logoutSession} className="w-full flex items-center gap-3 px-3.5 py-3 rounded-xl font-semibold text-sm text-cream/60 hover:text-white hover:bg-char-soft transition-colors">
            <svg className="w-5 h-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path strokeLinecap="round" strokeLinejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
            Keluar
          </button>
        </div>
      </aside>

      {/* Overlay mobile */}
      <div
        onClick={() => setSidebarOpen(false)}
        className={`fixed inset-0 bg-black/50 z-30 lg:hidden transition-opacity duration-300 ${sidebarOpen ? 'opacity-100' : 'opacity-0 pointer-events-none'}`}
      ></div>

      {/* MAIN */}
      <div className="flex-1 min-w-0 flex flex-col">
        <header className="h-20 bg-white border-b border-black/5 flex items-center justify-between px-5 md:px-8 sticky top-0 z-20 shrink-0">
          <div className="flex items-center gap-4">
            <button onClick={() => setSidebarOpen(true)} aria-label="Buka menu" className="lg:hidden p-2 -ml-2 text-char">
              <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <div>
              <h1 className="font-display text-2xl md:text-3xl uppercase leading-none">{meta.title}</h1>
              <p className="text-xs text-char/50 mt-1 hidden sm:block">{meta.subtitle}</p>
            </div>
          </div>

          <div className="flex items-center gap-3 md:gap-5">
            <div className="hidden sm:flex flex-col items-end leading-none">
              <span className="font-bold text-sm tabular-nums">{clock}</span>
              <span className="text-xs text-char/50 mt-0.5">{date}</span>
            </div>
            <div className="relative" ref={notifRef}>
              <button
                aria-label="Notifikasi stok"
                onClick={() => setNotifOpen((v) => !v)}
                className="relative p-2 rounded-full hover:bg-cream transition-colors"
              >
                <svg className="w-6 h-6 text-char/70" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 17h5l-1.4-1.4A2 2 0 0118 14.2V11a6 6 0 10-12 0v3.2c0 .5-.2 1-.6 1.4L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                {lowStock.length > 0 && (
                  <span className="absolute top-0.5 right-0.5 min-w-[18px] h-[18px] px-1 bg-chili text-white text-[10px] font-bold rounded-full ring-2 ring-white grid place-items-center">
                    {lowStock.length}
                  </span>
                )}
              </button>
              {notifOpen && (
                <div className="absolute right-0 top-12 w-72 bg-white rounded-2xl border border-black/10 shadow-xl overflow-hidden z-30">
                  <div className="px-5 py-3.5 border-b border-black/5 flex items-center justify-between">
                    <p className="font-bold text-sm">Stok Kritis</p>
                    <span className="text-xs font-bold text-chili bg-red-50 px-2 py-0.5 rounded-full">{lowStock.length} bahan</span>
                  </div>
                  <div className="max-h-64 overflow-y-auto">
                    {lowStock.length === 0 && <p className="px-5 py-6 text-sm text-char/40 text-center">Semua stok aman 👍</p>}
                    {lowStock.map((s) => (
                      <div key={s.id} className="px-5 py-3 border-b border-black/5 last:border-0 flex items-center justify-between gap-3">
                        <div className="min-w-0">
                          <p className="font-semibold text-sm truncate">{s.name}</p>
                          <p className="text-xs text-char/50">min {s.min_qty} {s.unit}</p>
                        </div>
                        <span className="text-xs font-bold text-chili bg-red-50 px-2 py-1 rounded-full shrink-0">{s.qty} {s.unit}</span>
                      </div>
                    ))}
                  </div>
                  {user?.role === 'owner' && (
                    <Link to="/erp/stock" onClick={() => setNotifOpen(false)} className="block text-center text-xs font-bold text-white bg-char hover:bg-char-soft py-3">
                      Kelola Stok
                    </Link>
                  )}
                </div>
              )}
            </div>
            <div className="w-10 h-10 rounded-full bg-chili/15 grid place-items-center font-bold text-chili shrink-0">
              {(user?.name ?? '?').charAt(0).toUpperCase()}
            </div>
          </div>
        </header>

        <Outlet context={{ user }} />
      </div>
    </div>
  )
}
