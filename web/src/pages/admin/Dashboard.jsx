import { useEffect, useRef } from 'react'
import Chart from 'chart.js/auto'
import { Link } from 'react-router-dom'

const summaryCards = [
  {
    value: 'Rp 4.850.000',
    label: 'Total Pendapatan Hari Ini',
    badge: '+12.4%',
    badgeCls: 'text-xs font-bold text-green-600 bg-green-50 px-2 py-1 rounded-full',
    iconCls: 'bg-chili/10',
    iconColor: 'text-chili',
    icon: 'M12 8c-1.66 0-3 .9-3 2s1.34 2 3 2 3 .9 3 2-1.34 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V6m0 10v2m9-8a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  {
    value: '86 Pesanan',
    label: 'Total Pesanan Hari Ini',
    badge: '+8',
    badgeCls: 'text-xs font-bold text-green-600 bg-green-50 px-2 py-1 rounded-full',
    iconCls: 'bg-ember/10',
    iconColor: 'text-ember',
    icon: 'M9 2a1 1 0 00-1 1v1H6a2 2 0 00-2 2v13a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-2V3a1 1 0 00-1-1H9zM8 11h8M8 15h5',
  },
  {
    value: '5 Item',
    label: 'Stok Kritis',
    badge: 'Perlu Restock',
    badgeCls: 'text-xs font-bold text-chili bg-red-50 px-2 py-1 rounded-full',
    iconCls: 'bg-red-50',
    iconColor: 'text-chili',
    icon: 'M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z',
  },
  {
    value: '15 Karyawan',
    label: 'Karyawan Hadir',
    badge: 'dari 18',
    badgeCls: 'text-xs font-bold text-char/50 bg-cream px-2 py-1 rounded-full',
    iconCls: 'bg-char/5',
    iconColor: 'text-char',
    icon: 'M17 20h5v-2a4 4 0 00-3-3.87M9 20H4v-2a4 4 0 013-3.87m5-2.13a4 4 0 100-8 4 4 0 000 8zm6 0a4 4 0 10-1.13-7.84',
  },
]

const topMenus = [
  { name: 'Mie Setan Extreme', count: '142x' },
  { name: 'Ayam Geprek S. Bawang', count: '118x' },
  { name: 'Sate Bakar Matah', count: '97x' },
  { name: 'Seblak Kerupuk Basah', count: '84x' },
]

const transactions = [
  { id: '#BP-10231', customer: 'Dinda Ayu', type: 'Dine-in', total: 'Rp 285.000', status: 'Lunas', statusCls: 'text-green-700 bg-green-50' },
  { id: '#BP-10230', customer: 'Bagas Pratama', type: 'Delivery', total: 'Rp 150.000', status: 'Lunas', statusCls: 'text-green-700 bg-green-50' },
  { id: '#BP-10229', customer: 'Sinta Wulandari', type: 'Dine-in', total: 'Rp 380.000', status: 'Lunas', statusCls: 'text-green-700 bg-green-50' },
  { id: '#BP-10228', customer: 'Rizky Ramadhan', type: 'Delivery', total: 'Rp 95.000', status: 'Pending', statusCls: 'text-ember bg-ember/10' },
  { id: '#BP-10227', customer: 'Fajar Nugroho', type: 'Dine-in', total: 'Rp 190.000', status: 'Lunas', statusCls: 'text-green-700 bg-green-50' },
]

export default function AdminDashboard() {
  const canvasRef = useRef(null)
  const chartRef = useRef(null)

  useEffect(() => {
    const ctx = canvasRef.current.getContext('2d')
    const gradient = ctx.createLinearGradient(0, 0, 0, 280)
    gradient.addColorStop(0, 'rgba(200,30,30,0.25)')
    gradient.addColorStop(1, 'rgba(200,30,30,0)')

    chartRef.current = new Chart(ctx, {
      type: 'line',
      data: {
        labels: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
        datasets: [
          {
            label: 'Pendapatan',
            data: [3200000, 2800000, 3600000, 4100000, 4700000, 5600000, 4850000],
            borderColor: '#C81E1E',
            backgroundColor: gradient,
            borderWidth: 3,
            pointBackgroundColor: '#F97316',
            pointBorderColor: '#fff',
            pointBorderWidth: 2,
            pointRadius: 5,
            pointHoverRadius: 7,
            tension: 0.4,
            fill: true,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#16110F',
            padding: 12,
            cornerRadius: 10,
            callbacks: {
              label: (item) => 'Rp ' + item.parsed.y.toLocaleString('id-ID'),
            },
          },
        },
        scales: {
          y: {
            grid: { color: '#F1EAE1' },
            ticks: {
              callback: (val) => 'Rp ' + (val / 1000000).toFixed(1) + 'jt',
              font: { family: "'Plus Jakarta Sans'" },
            },
          },
          x: {
            grid: { display: false },
            ticks: { font: { family: "'Plus Jakarta Sans'" } },
          },
        },
      },
    })

    return () => chartRef.current?.destroy()
  }, [])

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {/* SUMMARY CARDS */}
      <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-5">
        {summaryCards.map((card) => (
          <div key={card.label} className="bg-white rounded-2xl p-6 border border-black/5 shadow-sm">
            <div className="flex items-center justify-between mb-4">
              <span className={`w-11 h-11 rounded-xl ${card.iconCls} grid place-items-center`}>
                <svg className={`w-5 h-5 ${card.iconColor}`} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d={card.icon} />
                </svg>
              </span>
              <span className={card.badgeCls}>{card.badge}</span>
            </div>
            <p className="text-2xl font-display tracking-wide">{card.value}</p>
            <p className="text-xs text-char/50 mt-1">{card.label}</p>
          </div>
        ))}
      </div>

      {/* CHART + SIDE PANEL */}
      <div className="grid lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-white rounded-2xl p-6 border border-black/5 shadow-sm">
          <div className="flex items-center justify-between mb-5">
            <div>
              <h2 className="font-bold">Tren Penjualan Mingguan</h2>
              <p className="text-xs text-char/50 mt-0.5">7 hari terakhir</p>
            </div>
            <span className="text-xs font-bold text-white bg-char px-3 py-1.5 rounded-full">Rp</span>
          </div>
          <div className="h-72">
            <canvas ref={canvasRef}></canvas>
          </div>
        </div>

        <div className="bg-char text-cream rounded-2xl p-6 flex flex-col justify-between">
          <div>
            <p className="text-ember font-bold text-xs mb-2">Menu Terlaris</p>
            <h2 className="font-display text-xl uppercase leading-tight mb-5">Minggu Ini</h2>
            <ul className="space-y-4 text-sm">
              {topMenus.map((m) => (
                <li key={m.name} className="flex items-center justify-between">
                  <span>{m.name}</span>
                  <span className="font-bold text-ember">{m.count}</span>
                </li>
              ))}
            </ul>
          </div>
          <Link to="/erp/pos" className="mt-6 block text-center bg-chili hover:bg-chili-dark transition-colors text-white font-bold text-sm py-3 rounded-full">
            Buka Kasir
          </Link>
        </div>
      </div>

      {/* RECENT TRANSACTIONS */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-6 py-5 border-b border-black/5">
          <h2 className="font-bold">Transaksi Terakhir</h2>
          <Link to="/erp/keuangan" className="text-xs font-bold text-chili hover:underline">Lihat semua</Link>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[640px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">ID Transaksi</th>
                <th className="px-6 py-3 font-bold">Pelanggan</th>
                <th className="px-6 py-3 font-bold">Tipe</th>
                <th className="px-6 py-3 font-bold">Total</th>
                <th className="px-6 py-3 font-bold">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {transactions.map((t) => (
                <tr key={t.id} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4 font-semibold">{t.id}</td>
                  <td className="px-6 py-4">{t.customer}</td>
                  <td className="px-6 py-4 text-char/60">{t.type}</td>
                  <td className="px-6 py-4 font-semibold">{t.total}</td>
                  <td className="px-6 py-4">
                    <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${t.statusCls}`}>{t.status}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </main>
  )
}
