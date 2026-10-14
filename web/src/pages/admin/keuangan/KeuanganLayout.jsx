import { NavLink, Outlet, useOutletContext } from 'react-router-dom'

const tabs = [
  { to: '/erp/keuangan', label: 'Ringkasan', end: true },
  { to: '/erp/keuangan/laba-rugi', label: 'Laba Rugi' },
  { to: '/erp/keuangan/arus-kas', label: 'Arus Kas' },
  { to: '/erp/keuangan/buku-besar', label: 'Buku Besar' },
  { to: '/erp/keuangan/jurnal', label: 'Jurnal Umum' },
]

// Layout modul Keuangan: tab sub-modul + relay context user ke anak.
// Menyediakan padding halaman sendiri (sama dengan halaman admin lain) —
// sebelumnya tab menempel ke sidebar & header karena berada di luar <main>.
export default function KeuanganLayout() {
  const ctx = useOutletContext()
  return (
    <main className="flex-1 min-w-0 p-5 md:p-8 space-y-6">
      <div className="flex gap-2 overflow-x-auto pb-1 -mx-1 px-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {tabs.map((t) => (
          <NavLink
            key={t.to}
            to={t.to}
            end={t.end}
            className={({ isActive }) =>
              `shrink-0 px-4 py-2.5 rounded-full text-sm font-bold transition-colors ${isActive ? 'bg-chili text-white shadow-sm' : 'bg-white text-char/60 hover:text-char border border-black/5'}`
            }
          >
            {t.label}
          </NavLink>
        ))}
      </div>
      <Outlet context={ctx} />
    </main>
  )
}
