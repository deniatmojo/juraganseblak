import { useCallback, useEffect, useState } from 'react'
import { api } from '../../../api'
import RangeFilter, { rangePreset } from '../../../components/RangeFilter'
import { fmtRp, reportPdf } from '../../../financePdf'

export default function LabaRugi() {
  const [preset, setPreset] = useState('month')
  const [from, setFrom] = useState(rangePreset('month').from)
  const [to, setTo] = useState(rangePreset('month').to)
  const [data, setData] = useState(null)
  const [error, setError] = useState('')

  const applyPreset = (k) => {
    setPreset(k)
    const r = rangePreset(k)
    if (r) { setFrom(r.from); setTo(r.to) }
  }

  const load = useCallback(() => {
    api.get(`/finance/income-statement?from=${from}&to=${to}`)
      .then(setData)
      .catch((e) => setError(e.message))
  }, [from, to])
  useEffect(load, [load])

  const download = () => {
    const d = data
    reportPdf({
      title: 'Laporan Laba Rugi',
      from, to,
      filename: `Laba-Rugi_${from}_${to}.pdf`,
      blocks: [
        { heading: 'PENDAPATAN', rows: d.revenues.map((r) => ({ label: r.label, value: r.amount, sub: true })) },
        { rows: [{ label: 'Total Pendapatan', value: d.revenue_total, strong: true }] },
        { heading: 'HARGA POKOK PENJUALAN (HPP)', rows: [{ label: `HPP dari ${d.n_orders} pesanan`, value: d.hpp, sub: true, negative: true }] },
        { rows: [{ label: 'Laba Kotor', value: d.gross_profit, strong: true }] },
        { heading: 'BEBAN OPERASIONAL', rows: d.expenses.map((r) => ({ label: r.label, value: r.amount, sub: true, negative: true })) },
        { rows: [{ label: 'Total Beban', value: d.expense_total, strong: true, negative: true }] },
        { rows: [{ label: d.net_profit >= 0 ? 'LABA BERSIH' : 'RUGI BERSIH', value: d.net_profit, strong: true, negative: d.net_profit < 0 }] },
      ],
    })
  }

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm px-6 py-5 flex flex-wrap items-center justify-between gap-3">
        <RangeFilter preset={preset} onPreset={applyPreset} from={from} to={to} onFrom={setFrom} onTo={setTo} />
        <button onClick={download} disabled={!data} className="bg-chili hover:bg-chili-dark disabled:opacity-40 text-white font-bold px-5 py-2.5 rounded-full text-sm flex items-center gap-2">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
          Unduh PDF
        </button>
      </div>

      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      {data && (
        <div className="grid lg:grid-cols-2 gap-6">
          <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
            <h3 className="px-6 py-4 font-bold border-b border-black/5">Laporan Laba Rugi</h3>
            <div className="p-6 space-y-2 text-sm">
              <p className="text-xs font-bold text-char/40 uppercase mb-2">Pendapatan</p>
              {data.revenues.map((r) => (
                <div key={r.label} className="flex justify-between text-char/70"><span className="pl-2">{r.label}</span><span>{fmtRp(r.amount)}</span></div>
              ))}
              <div className="flex justify-between font-bold pt-2 border-t border-black/10"><span>Total Pendapatan</span><span>{fmtRp(data.revenue_total)}</span></div>

              <p className="text-xs font-bold text-char/40 uppercase mt-6 mb-2">Harga Pokok Penjualan</p>
              <div className="flex justify-between text-char/70"><span className="pl-2">HPP dari {data.n_orders} pesanan</span><span>− {fmtRp(data.hpp)}</span></div>
              <div className="flex justify-between font-bold pt-2 border-t border-black/10"><span>Laba Kotor</span><span className="text-char">{fmtRp(data.gross_profit)}</span></div>

              <p className="text-xs font-bold text-char/40 uppercase mt-6 mb-2">Beban Operasional</p>
              {data.expenses.length === 0 && <p className="text-char/40 text-xs pl-2">Tidak ada beban pada periode ini.</p>}
              {data.expenses.map((r) => (
                <div key={r.label} className="flex justify-between text-char/70"><span className="pl-2">{r.label}</span><span>− {fmtRp(r.amount)}</span></div>
              ))}
              <div className="flex justify-between font-bold pt-2 border-t border-black/10"><span>Total Beban</span><span className="text-chili">− {fmtRp(data.expense_total)}</span></div>
            </div>
          </div>

          <div className="space-y-5">
            <div className={`rounded-2xl p-7 shadow-sm ${data.net_profit >= 0 ? 'bg-char text-cream' : 'bg-chili text-white'}`}>
              <p className="text-xs font-bold uppercase opacity-60 mb-2">{data.net_profit >= 0 ? 'Laba Bersih' : 'Rugi Bersih'}</p>
              <p className="font-display text-4xl">{data.net_profit < 0 && '−'}{fmtRp(Math.abs(data.net_profit))}</p>
              <p className="text-xs opacity-50 mt-3">Pendapatan {fmtRp(data.revenue_total)} − HPP {fmtRp(data.hpp)} − Beban {fmtRp(data.expense_total)}</p>
            </div>
            <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-6 space-y-4">
              <div className="flex items-center gap-3">
                <span className="w-10 h-10 rounded-xl bg-ember/10 grid place-items-center"><svg className="w-5 h-5 text-ember" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg></span>
                <div><p className="text-xs text-char/50">Margin Laba Bersih</p><p className="font-display text-2xl">{data.revenue_total > 0 ? Math.round((data.net_profit / data.revenue_total) * 100) : 0}%</p></div>
              </div>
              <div className="flex items-center gap-3">
                <span className="w-10 h-10 rounded-xl bg-green-50 grid place-items-center"><svg className="w-5 h-5 text-green-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" /></svg></span>
                <div><p className="text-xs text-char/50">Margin Laba Kotor</p><p className="font-display text-2xl">{data.revenue_total > 0 ? Math.round((data.gross_profit / data.revenue_total) * 100) : 0}%</p></div>
              </div>
              <p className="text-xs text-char/40 leading-relaxed">HPP dihitung otomatis dari resep/HPP tiap menu yang terjual pada periode ini (pesanan void tidak dihitung). Pendapatan &amp; beban dari transaksi kas tercatat.</p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
