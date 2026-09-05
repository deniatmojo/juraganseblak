import { useState } from 'react'

const dateRanges = [
  { key: 'today', label: 'Hari Ini' },
  { key: 'week', label: 'Minggu Ini' },
  { key: 'month', label: 'Bulan Ini' },
]

const transactions = [
  { tgl: '5 Sep', desc: 'Penjualan Dine-in & Delivery', cat: 'Penjualan', masuk: true, amount: 4850000 },
  { tgl: '5 Sep', desc: 'Belanja Bahan Baku (Cabai, Ayam)', cat: 'Operasional', masuk: false, amount: 1200000 },
  { tgl: '4 Sep', desc: 'Gaji Harian Karyawan Lepas', cat: 'Gaji', masuk: false, amount: 450000 },
  { tgl: '4 Sep', desc: 'Tagihan Listrik & Gas', cat: 'Utilitas', masuk: false, amount: 270000 },
  { tgl: '3 Sep', desc: 'Penjualan Dine-in & Delivery', cat: 'Penjualan', masuk: true, amount: 4120000 },
]

const formatRp = (num) => 'Rp ' + num.toLocaleString('id-ID')

export default function Keuangan() {
  const [activeRange, setActiveRange] = useState('today')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')

  const pemasukan = transactions.filter((t) => t.masuk).reduce((s, t) => s + t.amount, 0)
  const pengeluaran = transactions.filter((t) => !t.masuk).reduce((s, t) => s + t.amount, 0)
  const laba = pemasukan - pengeluaran

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {/* DATE FILTER */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-5 flex flex-wrap items-end gap-4">
        <div className="flex gap-2">
          {dateRanges.map((r) => (
            <button
              key={r.key}
              onClick={() => setActiveRange(r.key)}
              className={`filter-tab px-4 py-2.5 rounded-full text-xs font-bold bg-cream ${activeRange === r.key ? 'active' : 'text-char/60'}`}
            >
              {r.label}
            </button>
          ))}
        </div>

        <div className="flex items-end gap-3 ml-auto flex-wrap">
          <div>
            <label htmlFor="dateFrom" className="block text-xs font-bold text-char/50 mb-1.5">Dari Tanggal</label>
            <input type="date" id="dateFrom" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} className="border border-black/15 rounded-xl px-3.5 py-2.5 text-sm" />
          </div>
          <div>
            <label htmlFor="dateTo" className="block text-xs font-bold text-char/50 mb-1.5">Sampai Tanggal</label>
            <input type="date" id="dateTo" value={dateTo} onChange={(e) => setDateTo(e.target.value)} className="border border-black/15 rounded-xl px-3.5 py-2.5 text-sm" />
          </div>
          <button
            onClick={() => console.log('Terapkan filter tanggal:', dateFrom, '-', dateTo)}
            className="bg-chili hover:bg-chili-dark text-white font-bold px-6 py-2.5 rounded-xl text-sm transition-colors"
          >
            Terapkan
          </button>
        </div>
      </div>

      {/* SUMMARY CARDS */}
      <div className="grid sm:grid-cols-3 gap-5">
        <div className="bg-white rounded-2xl p-6 border border-black/5 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <span className="w-11 h-11 rounded-xl bg-green-50 grid place-items-center">
              <svg className="w-5 h-5 text-green-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M7 11l5-5m0 0l5 5m-5-5v12" /></svg>
            </span>
          </div>
          <p className="text-2xl font-display tracking-wide">{formatRp(pemasukan)}</p>
          <p className="text-xs text-char/50 mt-1">Total Pemasukan</p>
        </div>

        <div className="bg-white rounded-2xl p-6 border border-black/5 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <span className="w-11 h-11 rounded-xl bg-red-50 grid place-items-center">
              <svg className="w-5 h-5 text-chili" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M17 13l-5 5m0 0l-5-5m5 5V6" /></svg>
            </span>
          </div>
          <p className="text-2xl font-display tracking-wide">{formatRp(pengeluaran)}</p>
          <p className="text-xs text-char/50 mt-1">Total Pengeluaran</p>
        </div>

        <div className="bg-char text-cream rounded-2xl p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="w-11 h-11 rounded-xl bg-white/10 grid place-items-center">
              <svg className="w-5 h-5 text-ember" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M9 8h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h6.5L18 7.5V19a2 2 0 01-2 2z" /></svg>
            </span>
            <span className="text-xs font-bold text-green-400 bg-white/10 px-2 py-1 rounded-full">Laba</span>
          </div>
          <p className="text-2xl font-display tracking-wide text-ember">{formatRp(laba)}</p>
          <p className="text-xs text-cream/50 mt-1">Laba / Rugi Bersih</p>
        </div>
      </div>

      {/* TRANSACTIONS TABLE */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-6 py-5 border-b border-black/5">
          <h2 className="font-bold">Rincian Pemasukan &amp; Pengeluaran</h2>
          <span className="text-xs text-char/50">5 Sep 2026</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[680px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Tanggal</th>
                <th className="px-6 py-3 font-bold">Keterangan</th>
                <th className="px-6 py-3 font-bold">Kategori</th>
                <th className="px-6 py-3 font-bold">Tipe</th>
                <th className="px-6 py-3 font-bold text-right">Jumlah</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {transactions.map((t) => (
                <tr key={t.desc + t.tgl} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4 text-char/60">{t.tgl}</td>
                  <td className="px-6 py-4 font-semibold">{t.desc}</td>
                  <td className="px-6 py-4 text-char/60">{t.cat}</td>
                  <td className="px-6 py-4">
                    {t.masuk ? (
                      <span className="text-xs font-bold text-green-700 bg-green-50 px-2.5 py-1 rounded-full">Pemasukan</span>
                    ) : (
                      <span className="text-xs font-bold text-chili bg-red-50 px-2.5 py-1 rounded-full">Pengeluaran</span>
                    )}
                  </td>
                  <td className={`px-6 py-4 text-right font-semibold ${t.masuk ? 'text-green-700' : 'text-chili'}`}>
                    {t.masuk ? '+' : '−'} {formatRp(t.amount)}
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="border-t border-black/10">
                <td colSpan="4" className="px-6 py-4 font-bold text-right">Total Laba / Rugi Bersih</td>
                <td className="px-6 py-4 text-right font-display text-lg text-ember">{formatRp(laba)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
    </main>
  )
}
