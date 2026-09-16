import { useCallback, useEffect, useState } from 'react'
import { api } from '../../api'

const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

export default function Gaji() {
  const monthStart = new Date()
  monthStart.setDate(1)
  const [dateFrom, setDateFrom] = useState(monthStart.toISOString().slice(0, 10))
  const [dateTo, setDateTo] = useState(new Date().toISOString().slice(0, 10))
  const [rows, setRows] = useState([])
  const [error, setError] = useState('')
  const [kasbonForm, setKasbonForm] = useState(null) // { id, name, amount, note }
  const [payTarget, setPayTarget] = useState(null)   // row yang mau dibayar

  const load = useCallback(() => {
    api.get(`/payroll?from=${dateFrom}&to=${dateTo}`)
      .then(setRows)
      .catch((e) => setError(e.message))
  }, [dateFrom, dateTo])
  useEffect(load, [load])

  const totalGaji = rows.reduce((s, r) => s + r.gaji, 0)
  const totalKasbon = rows.reduce((s, r) => s + r.kasbon_open, 0)
  const totalBayar = rows.reduce((s, r) => s + r.total, 0)

  const saveKasbon = async () => {
    try {
      await api.post(`/employees/${kasbonForm.id}/kasbon`, { amount: Number(kasbonForm.amount), note: kasbonForm.note || null })
      setKasbonForm(null)
      load()
    } catch (e) { setError(e.message) }
  }

  const doPay = async () => {
    try {
      const res = await api.post('/payroll/pay', { employee_id: payTarget.id, from: dateFrom, to: dateTo })
      setPayTarget(null)
      load()
      window.alert(`Gaji ${res.employee} dibayar: ${formatRp(res.total)} (${res.days} hari${res.kasbon > 0 ? `, dikurangi kasbon ${formatRp(res.kasbon)}` : ''}). Tercatat di Keuangan.`)
    } catch (e) { setError(e.message) }
  }

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      {/* PERIODE + RINGKASAN */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-5 flex flex-wrap items-end gap-4">
        <div>
          <label className="block text-xs font-bold text-char/50 mb-1.5">Dari</label>
          <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} className="border border-black/15 rounded-xl px-3.5 py-2.5 text-sm" />
        </div>
        <div>
          <label className="block text-xs font-bold text-char/50 mb-1.5">Sampai</label>
          <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} className="border border-black/15 rounded-xl px-3.5 py-2.5 text-sm" />
        </div>
        <div className="flex gap-6 ml-auto flex-wrap">
          <div><p className="text-xs text-char/50">Total Gaji</p><p className="font-display text-xl">{formatRp(totalGaji)}</p></div>
          <div><p className="text-xs text-char/50">Kasbon</p><p className="font-display text-xl text-chili">− {formatRp(totalKasbon)}</p></div>
          <div><p className="text-xs text-char/50">Dibayar</p><p className="font-display text-xl text-ember">{formatRp(totalBayar)}</p></div>
        </div>
      </div>

      {/* TABEL PAYROLL */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-6 py-5 border-b border-black/5">
          <h2 className="font-bold">Rekap Gaji Karyawan</h2>
          <span className="text-xs text-char/50">{dateFrom} — {dateTo}</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[860px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Karyawan</th>
                <th className="px-6 py-3 font-bold">Posisi</th>
                <th className="px-6 py-3 font-bold">Hadir</th>
                <th className="px-6 py-3 font-bold">Terlambat</th>
                <th className="px-6 py-3 font-bold">Izin/Sakit</th>
                <th className="px-6 py-3 font-bold">Tarif</th>
                <th className="px-6 py-3 font-bold">Gaji</th>
                <th className="px-6 py-3 font-bold">Kasbon</th>
                <th className="px-6 py-3 font-bold">Dibayar</th>
                <th className="px-6 py-3 font-bold text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {rows.length === 0 && (
                <tr><td colSpan={10} className="px-6 py-8 text-center text-char/40">Belum ada data.</td></tr>
              )}
              {rows.map((r) => (
                <tr key={r.id} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4 font-semibold">{r.name}</td>
                  <td className="px-6 py-4 text-char/60">{r.posisi || '—'}</td>
                  <td className="px-6 py-4 font-semibold">{r.days_present}</td>
                  <td className="px-6 py-4 text-char/60">{r.days_late}</td>
                  <td className="px-6 py-4 text-char/60">{r.days_off}</td>
                  <td className="px-6 py-4 text-char/60">{r.daily_rate ? formatRp(r.daily_rate) : '—'}</td>
                  <td className="px-6 py-4 font-semibold">{formatRp(r.gaji)}</td>
                  <td className={`px-6 py-4 ${r.kasbon_open > 0 ? 'font-bold text-chili' : 'text-char/40'}`}>
                    {r.kasbon_open > 0 ? formatRp(r.kasbon_open) : '—'}
                  </td>
                  <td className={`px-6 py-4 font-display ${r.total > 0 ? 'text-ember' : 'text-char/40'}`}>{formatRp(r.total)}</td>
                  <td className="px-6 py-4 text-right space-x-3 whitespace-nowrap">
                    <button onClick={() => setKasbonForm({ id: r.id, name: r.name, amount: '', note: '' })} className="text-xs font-bold text-char/70 hover:text-char underline">+ Kasbon</button>
                    {r.days_present > 0 && (
                      <button onClick={() => setPayTarget(r)} className="text-xs font-bold text-white bg-char hover:bg-char-soft px-4 py-2 rounded-full">Bayar</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL KASBON */}
      {kasbonForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setKasbonForm(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">Catat Kasbon</h2>
            <p className="text-char/50 text-sm mb-6">{kasbonForm.name} — dipotong dari gaji berikutnya.</p>
            <label className="block text-sm font-bold mb-1.5">Jumlah (Rp)</label>
            <input type="number" min="0" value={kasbonForm.amount} onChange={(e) => setKasbonForm({ ...kasbonForm, amount: e.target.value })} className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-4" />
            <label className="block text-sm font-bold mb-1.5">Keterangan</label>
            <input type="text" value={kasbonForm.note} onChange={(e) => setKasbonForm({ ...kasbonForm, note: e.target.value })} className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-6" placeholder="opsional" />
            <div className="flex gap-3">
              <button onClick={() => setKasbonForm(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={saveKasbon} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Simpan</button>
            </div>
          </div>
        </div>
      )}

      {/* KONFIRMASI BAYAR */}
      {payTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setPayTarget(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">Bayar Gaji</h2>
            <p className="text-char/50 text-sm mb-6">{payTarget.name} — periode {dateFrom} s/d {dateTo}</p>
            <div className="space-y-2 text-sm mb-6">
              <div className="flex justify-between text-char/60"><span>{payTarget.days_present} hari × {formatRp(payTarget.daily_rate)}</span><span className="font-bold text-char">{formatRp(payTarget.gaji)}</span></div>
              <div className="flex justify-between text-char/60"><span>Kasbon belum lunas</span><span className={payTarget.kasbon_open > 0 ? 'font-bold text-chili' : ''}>− {formatRp(payTarget.kasbon_open)}</span></div>
              <div className="flex justify-between font-bold pt-2 border-t border-black/10"><span>Dibayar</span><span className="text-ember">{formatRp(payTarget.total)}</span></div>
            </div>
            <p className="text-xs text-char/40 mb-5">Pembayaran tercatat sebagai pengeluaran kategori "gaji" di Keuangan, dan semua kasbon karyawan ini dilunasi.</p>
            <div className="flex gap-3">
              <button onClick={() => setPayTarget(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={doPay} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Bayar &amp; Catat</button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
