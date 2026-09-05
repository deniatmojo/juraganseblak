import { useEffect, useState } from 'react'
import { NavLink, Link, Outlet, useNavigate, useLocation } from 'react-router-dom'
import { getCurrentUser, logout, isAllowed } from '../auth'

const headerMeta = {
  '/erp': { title: 'Dashboard', subtitle: 'Ringkasan operasional Bara.Pedas hari ini' },
  '/erp/pos': { title: 'Kasir / POS', subtitle: 'Meja 07 · Dine-in' },
  '/erp/absensi': { title: 'Absensi', subtitle: 'Kehadiran karyawan hari ini' },
  '/erp/stock': { title: 'Stok Bahan Baku', subtitle: 'Pantau ketersediaan bahan dapur' },
  '/erp/keuangan': { title: 'Laporan Keuangan', subtitle: 'Pemasukan & pengeluaran outlet' },
  '/erp/karyawan': { title: 'Karyawan', subtitle: 'Kelola akun login karyawan' },
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
    ownerOnly: true,
    icon: 'M3 10h18M3 6h18M4 6v12a1 1 0 001 1h14a1 1 0 001-1V6M9 14h6',
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
]

export default function AdminLayout() {
  const navigate = useNavigate()
  const location = useLocation()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [now, setNow] = useState(new Date())
  const [user, setUser] = useState(getCurrentUser)

  const visibleNav = navItems.filter((item) => !item.ownerOnly || user?.role === 'owner')
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

  const clock = now.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  const date = now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })

  const logoutSession = () => {
    logout()
    navigate('/login')
  }

  return (
    <div className="min-h-screen flex bg-cream text-char antialiased">
      {/* SIDEBAR */}
      <aside className={`fixed lg:static inset-y-0 left-0 z-40 w-64 bg-char text-cream flex flex-col transition-transform duration-300 ${sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}`}>
        <div className="h-20 flex items-center px-6 border-b border-char-line shrink-0">
          <Link to="/erp" className="font-display text-2xl tracking-wide">
            BARA<span className="text-chili">.</span>PEDAS
          </Link>
        </div>

        <div className="px-6 py-5 border-b border-char-line flex items-center gap-3 shrink-0">
          <div className="w-11 h-11 rounded-full bg-chili/20 grid place-items-center ring-2 ring-chili font-bold text-chili">
            {(user?.name ?? '?').charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0">
            <p className="font-bold text-sm truncate">{user?.name ?? 'Pengguna'}</p>
            <p className="text-xs text-cream/50">{user?.role === 'owner' ? 'Super Admin' : 'Karyawan'}</p>
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
            <button aria-label="Notifikasi" className="relative p-2 rounded-full hover:bg-cream transition-colors">
              <svg className="w-6 h-6 text-char/70" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15 17h5l-1.4-1.4A2 2 0 0118 14.2V11a6 6 0 10-12 0v3.2c0 .5-.2 1-.6 1.4L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
              <span className="absolute top-1.5 right-1.5 w-2.5 h-2.5 bg-chili rounded-full ring-2 ring-white"></span>
            </button>
            <div className="w-10 h-10 rounded-full bg-chili/15 grid place-items-center font-bold text-chili">
              {(user?.name ?? '?').charAt(0).toUpperCase()}
            </div>
          </div>
        </header>

        <Outlet context={{ user }} />
      </div>
    </div>
  )
}
