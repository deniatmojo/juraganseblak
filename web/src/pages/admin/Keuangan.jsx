import { useCallback, useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { api } from '../../api'

const dateRanges = [
  { key: 'today', label: 'Hari Ini' },
  { key: 'week', label: 'Minggu Ini' },
  { key: 'month', label: 'Bulan Ini' },
]

const catLabels = {
  penjualan: 'Penjualan',
  void: 'Void Pesanan',
  belanja: 'Belanja Bahan',
  gaji: 'Gaji',
  operasional: 'Operasional',
  utilitas: 'Utilitas',
  lain: 'Lain-lain',
}

const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

function rangeFor(key) {
  const now = new Date()
  const to = now.toISOString().slice(0, 10)
  const from = new Date(now)
  if (key === 'today') { /* from = today */ }
  else if (key === 'week') from.setDate(from.getDate() - 6)
  else if (key === 'month') from.setDate(from.getDate() - 29)
  return { from: from.toISOString().slice(0, 10), to }
}

export default function Keuangan() {
  const { user } = useOutletContext()
  const isOwner = user?.role === 'owner'

  const [activeRange, setActiveRange] = useState('today')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [transactions, setTransactions] = useState([])
  const [orders, setOrders] = useState([])
  const [error, setError] = useState('')
  const [manualForm, setManualForm] = useState(null) // { type, category, amount, note }
  const [voidTarget, setVoidTarget] = useState(null) // order yang mau di-void

  const load = useCallback((from, to) => {
    const q = `from=${from}&to=${to}`
    Promise.all([api.get(`/transactions?${q}`), api.get(`/orders?${q}`)])
      .then(([tx, od]) => {
        setTransactions(tx)
        setOrders(od)
      })
      .catch((e) => setError(e.message))
  }, [])

  useEffect(() => {
    const { from, to } = rangeFor('today')
    setDateFrom(from)
    setDateTo(to)
    load(from, to)
  }, [load])

  const applyRange = (key) => {
    setActiveRange(key)
    const { from, to } = rangeFor(key)
    setDateFrom(from)
    setDateTo(to)
    load(from, to)
  }

  const applyCustom = () => {
    if (!dateFrom || !dateTo) return setError('Isi kedua tanggal dulu.')
    setActiveRange('custom')
    load(dateFrom, dateTo)
  }

  const pemasukan = transactions.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0)
  const pengeluaran = transactions.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0)
  const laba = pemasukan - pengeluaran

  const saveManual = async () => {
    try {
      await api.post('/transactions', {
        type: manualForm.type,
        category: manualForm.category,
        amount: Number(manualForm.amount),
        note: manualForm.note || null,
      })
      setManualForm(null)
      load(dateFrom, dateTo)
    } catch (e) { setError(e.message) }
  }

  const applyVoid = async () => {
    try {
      await api.post(`/orders/${voidTarget.id}/void`, { reason: voidTarget.reason })
      setVoidTarget(null)
      load(dateFrom, dateTo)
    } catch (e) { setError(e.message) }
  }

  const exportCsv = () => {
    const rows = [
      ['Tanggal', 'Keterangan', 'Kategori', 'Tipe', 'Jumlah'],
      ...transactions.map((t) => [
        new Date(t.created_at).toLocaleString('id-ID'),
        (t.note || t.category).replace(/;/g, ','),
        catLabels[t.category] || t.category,
        t.type === 'income' ? 'Pemasukan' : 'Pengeluaran',
        t.amount,
      ]),
      ['', '', '', 'Laba Bersih', laba],
    ]
    const csv = rows.map((r) => r.join(';')).join('\r\n')
    const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `laporan-keuangan-${dateFrom}-sd-${dateTo}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      {/* DATE FILTER */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-5 flex flex-wrap items-end gap-4">
        <div className="flex gap-2">
          {dateRanges.map((r) => (
            <button
              key={r.key}
              onClick={() => applyRange(r.key)}
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
          <button onClick={applyCustom} className="bg-chili hover:bg-chili-dark text-white font-bold px-6 py-2.5 rounded-xl text-sm transition-colors">Terapkan</button>
          <button onClick={exportCsv} className="border border-black/15 text-char font-bold px-6 py-2.5 rounded-xl text-sm hover:bg-cream transition-colors">Export CSV</button>
          {isOwner && (
            <button onClick={() => setManualForm({ type: 'expense', category: 'operasional', amount: '', note: '' })} className="bg-char hover:bg-char-soft text-white font-bold px-6 py-2.5 rounded-xl text-sm transition-colors">+ Catat Transaksi</button>
          )}
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
          <span className="text-xs text-char/50">{dateFrom} — {dateTo}</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[720px]">
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
              {transactions.length === 0 && (
                <tr><td colSpan={5} className="px-6 py-8 text-center text-char/40">Belum ada transaksi pada periode ini.</td></tr>
              )}
              {transactions.map((t) => (
                <tr key={t.id} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4 text-char/60 whitespace-nowrap">{new Date(t.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}</td>
                  <td className="px-6 py-4 font-semibold">{t.note || catLabels[t.category] || t.category}</td>
                  <td className="px-6 py-4 text-char/60">{catLabels[t.category] || t.category}</td>
                  <td className="px-6 py-4">
                    {t.type === 'income' ? (
                      <span className="text-xs font-bold text-green-700 bg-green-50 px-2.5 py-1 rounded-full">Pemasukan</span>
                    ) : (
                      <span className="text-xs font-bold text-chili bg-red-50 px-2.5 py-1 rounded-full">Pengeluaran</span>
                    )}
                  </td>
                  <td className={`px-6 py-4 text-right font-semibold ${t.type === 'income' ? 'text-green-700' : 'text-chili'}`}>
                    {t.type === 'income' ? '+' : '−'} {formatRp(t.amount)}
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

      {/* ORDERS TABLE */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-6 py-5 border-b border-black/5">
          <h2 className="font-bold">Pesanan pada Periode Ini</h2>
          <span className="text-xs text-char/50">{orders.length} pesanan</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[760px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">No. Pesanan</th>
                <th className="px-6 py-3 font-bold">Waktu</th>
                <th className="px-6 py-3 font-bold">Kasir</th>
                <th className="px-6 py-3 font-bold">Metode</th>
                <th className="px-6 py-3 font-bold">Total</th>
                <th className="px-6 py-3 font-bold">Status</th>
                {isOwner && <th className="px-6 py-3 font-bold text-right">Aksi</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {orders.length === 0 && (
                <tr><td colSpan={isOwner ? 7 : 6} className="px-6 py-8 text-center text-char/40">Belum ada pesanan pada periode ini.</td></tr>
              )}
              {orders.map((o) => (
                <tr key={o.id} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4 font-semibold">{o.order_no}</td>
                  <td className="px-6 py-4 text-char/60 whitespace-nowrap">{new Date(o.created_at).toLocaleString('id-ID', { dateStyle: 'short', timeStyle: 'short' })}</td>
                  <td className="px-6 py-4 text-char/60">{o.cashier_name || '-'}</td>
                  <td className="px-6 py-4 text-char/60 uppercase text-xs font-bold">{o.pay_method}</td>
                  <td className="px-6 py-4 font-semibold">{formatRp(o.total)}</td>
                  <td className="px-6 py-4">
                    {o.status === 'paid' && <span className="text-xs font-bold text-green-700 bg-green-50 px-2.5 py-1 rounded-full">Lunas</span>}
                    {o.status === 'pending' && <span className="text-xs font-bold text-ember bg-ember/10 px-2.5 py-1 rounded-full">Pending</span>}
                    {o.status === 'canceled' && (
                      <span className="text-xs font-bold text-chili bg-red-50 px-2.5 py-1 rounded-full" title={o.void_reason || ''}>Void</span>
                    )}
                  </td>
                  {isOwner && (
                    <td className="px-6 py-4 text-right">
                      {o.status === 'paid' && (
                        <button onClick={() => setVoidTarget({ ...o, reason: '' })} className="text-xs font-bold text-chili hover:underline">Void</button>
                      )}
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL CATAT TRANSAKSI */}
      {manualForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setManualForm(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-6">Catat Transaksi</h2>
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-bold mb-1.5">Tipe</label>
                  <select value={manualForm.type} onChange={(e) => setManualForm({ ...manualForm, type: e.target.value })} className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm">
                    <option value="expense">Pengeluaran</option>
                    <option value="income">Pemasukan</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-bold mb-1.5">Kategori</label>
                  <select value={manualForm.category} onChange={(e) => setManualForm({ ...manualForm, category: e.target.value })} className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm">
                    {['belanja', 'gaji', 'operasional', 'utilitas', 'lain'].map((c) => <option key={c} value={c}>{catLabels[c]}</option>)}
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1.5">Jumlah (Rp)</label>
                <input type="number" min="0" value={manualForm.amount} onChange={(e) => setManualForm({ ...manualForm, amount: e.target.value })} className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm" />
              </div>
              <div>
                <label className="block text-sm font-bold mb-1.5">Keterangan</label>
                <input type="text" value={manualForm.note} onChange={(e) => setManualForm({ ...manualForm, note: e.target.value })} className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm" placeholder="mis. Belanja cabai pasar pagi" />
              </div>
            </div>
            <div className="flex gap-3 mt-7">
              <button onClick={() => setManualForm(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={saveManual} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Simpan</button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL VOID */}
      {voidTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setVoidTarget(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">Void Pesanan</h2>
            <p className="text-char/50 text-sm mb-6">{voidTarget.order_no} — {formatRp(voidTarget.total)}. Penjualan akan dibatalkan dan dicatat sebagai pengeluaran kategori void. Stok tidak dikembalikan otomatis.</p>
            <label className="block text-sm font-bold mb-1.5">Alasan Void</label>
            <input
              type="text"
              value={voidTarget.reason}
              onChange={(e) => setVoidTarget({ ...voidTarget, reason: e.target.value })}
              placeholder="mis. Salah input pesanan"
              className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-6 focus:outline-none focus:ring-2 focus:ring-chili/30"
            />
            <div className="flex gap-3">
              <button onClick={() => setVoidTarget(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={applyVoid} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Void Pesanan</button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
