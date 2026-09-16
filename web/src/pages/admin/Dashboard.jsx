import { useEffect, useRef, useState } from 'react'
import Chart from 'chart.js/auto'
import { Link } from 'react-router-dom'
import { api } from '../../api'

const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

const cardStyle = [
  {
    label: 'Total Pendapatan Hari Ini',
    badgeCls: 'text-xs font-bold text-char/50 bg-cream px-2 py-1 rounded-full',
    iconCls: 'bg-chili/10',
    iconColor: 'text-chili',
    icon: 'M12 8c-1.66 0-3 .9-3 2s1.34 2 3 2 3 .9 3 2-1.34 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V6m0 10v2m9-8a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  {
    label: 'Total Pesanan Hari Ini',
    badgeCls: 'text-xs font-bold text-char/50 bg-cream px-2 py-1 rounded-full',
    iconCls: 'bg-ember/10',
    iconColor: 'text-ember',
    icon: 'M9 2a1 1 0 00-1 1v1H6a2 2 0 00-2 2v13a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-2V3a1 1 0 00-1-1H9zM8 11h8M8 15h5',
  },
  {
    label: 'Item Menu Aktif',
    badgeCls: 'text-xs font-bold text-char/50 bg-cream px-2 py-1 rounded-full',
    iconCls: 'bg-red-50',
    iconColor: 'text-chili',
    icon: 'M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z',
  },
  {
    label: 'Transaksi Bulan Ini',
    badgeCls: 'text-xs font-bold text-char/50 bg-cream px-2 py-1 rounded-full',
    iconCls: 'bg-char/5',
    iconColor: 'text-char',
    icon: 'M17 20h5v-2a4 4 0 00-3-3.87M9 20H4v-2a4 4 0 013-3.87m5-2.13a4 4 0 100-8 4 4 0 000 8zm6 0a4 4 0 10-1.13-7.84',
  },
]

export default function AdminDashboard() {
  const canvasRef = useRef(null)
  const chartRef = useRef(null)
  const [stats, setStats] = useState(null)
  const [transactions, setTransactions] = useState([])
  const [weekly, setWeekly] = useState([])
  const [error, setError] = useState('')

  useEffect(() => {
    let mounted = true
    Promise.all([
      api.get('/orders'),               // riwayat (default terbaru, maks 500)
      api.get('/products'),             // jumlah menu aktif
    ])
      .then(([orders, products]) => {
        if (!mounted) return
        const today = new Date().toISOString().slice(0, 10)
        const paid = orders.filter((o) => o.status === 'paid')
        const todays = paid.filter((o) => o.created_at?.slice(0, 10) === today)
        const monthPrefix = today.slice(0, 7)

        setStats({
          incomeToday: todays.reduce((s, o) => s + o.total, 0),
          ordersToday: todays.length,
          activeMenu: products.length,
          monthCount: paid.filter((o) => o.created_at?.startsWith(monthPrefix)).length,
        })

        setTransactions(
          paid.slice(0, 5).map((o) => ({
            id: o.order_no,
            customer: o.customer_name || 'Umum',
            type: o.channel === 'online' ? 'Online' : 'Dine-in',
            total: formatRp(o.total),
            status: o.status === 'paid' ? 'Lunas' : o.status === 'pending' ? 'Pending' : 'Batal',
            statusCls: o.status === 'paid' ? 'text-green-700 bg-green-50' : 'text-ember bg-ember/10',
          }))
        )

        // Omzet 7 hari terakhir
        const days = []
        for (let i = 6; i >= 0; i--) {
          const d = new Date()
          d.setDate(d.getDate() - i)
          const key = d.toISOString().slice(0, 10)
          days.push({
            label: d.toLocaleDateString('id-ID', { weekday: 'short' }),
            total: paid.filter((o) => o.created_at?.slice(0, 10) === key).reduce((s, o) => s + o.total, 0),
          })
        }
        setWeekly(days)
      })
      .catch((e) => mounted && setError(`Gagal memuat data: ${e.message}`))
    return () => { mounted = false }
  }, [])

  const summaryValues = stats
    ? [formatRp(stats.incomeToday), `${stats.ordersToday} Pesanan`, `${stats.activeMenu} Item`, `${stats.monthCount} Transaksi`]
    : ['…', '…', '…', '…']

  useEffect(() => {
    if (!weekly.length || !canvasRef.current) return
    const ctx = canvasRef.current.getContext('2d')
    const gradient = ctx.createLinearGradient(0, 0, 0, 280)
    gradient.addColorStop(0, 'rgba(200,30,30,0.25)')
    gradient.addColorStop(1, 'rgba(200,30,30,0)')

    chartRef.current = new Chart(ctx, {
      type: 'line',
      data: {
        labels: weekly.map((d) => d.label),
        datasets: [
          {
            label: 'Pendapatan',
            data: weekly.map((d) => d.total),
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
  }, [weekly])

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      {/* SUMMARY CARDS */}
      <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-5">
        {cardStyle.map((card, i) => (
          <div key={card.label} className="bg-white rounded-2xl p-6 border border-black/5 shadow-sm">
            <div className="flex items-center justify-between mb-4">
              <span className={`w-11 h-11 rounded-xl ${card.iconCls} grid place-items-center`}>
                <svg className={`w-5 h-5 ${card.iconColor}`} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d={card.icon} />
                </svg>
              </span>
              <span className={card.badgeCls}>Live</span>
            </div>
            <p className="text-2xl font-display tracking-wide">{summaryValues[i]}</p>
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
            <p className="text-ember font-bold text-xs mb-2">Info</p>
            <h2 className="font-display text-xl uppercase leading-tight mb-5">Data Langsung</h2>
            <ul className="space-y-4 text-sm">
              <li className="flex items-center justify-between">
                <span>Grafik &amp; kartu di samping diambil dari transaksi nyata di database.</span>
              </li>
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
              {transactions.length === 0 && (
                <tr><td colSpan={5} className="px-6 py-8 text-center text-char/40">Belum ada transaksi.</td></tr>
              )}
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
