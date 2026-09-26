import { NavLink, Outlet, useOutletContext } from 'react-router-dom'

const tabs = [
  { to: '/erp/keuangan', label: 'Ringkasan', end: true },
  { to: '/erp/keuangan/laba-rugi', label: 'Laba Rugi' },
  { to: '/erp/keuangan/arus-kas', label: 'Arus Kas' },
  { to: '/erp/keuangan/buku-besar', label: 'Buku Besar' },
  { to: '/erp/keuangan/jurnal', label: 'Jurnal Umum' },
]

// Layout modul Keuangan: tab sub-modul + relay context user ke anak.
export default function KeuanganLayout() {
  const ctx = useOutletContext()
  return (
    <>
      <div className="flex flex-wrap gap-2 -mt-2 mb-1">
        {tabs.map((t) => (
          <NavLink
            key={t.to}
            to={t.to}
            end={t.end}
            className={({ isActive }) =>
              `px-4 py-2.5 rounded-full text-sm font-bold transition-colors ${isActive ? 'bg-chili text-white shadow-sm' : 'bg-white text-char/60 hover:text-char border border-black/5'}`
            }
          >
            {t.label}
          </NavLink>
        ))}
      </div>
      <Outlet context={ctx} />
    </>
  )
}
