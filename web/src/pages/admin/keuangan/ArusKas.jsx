import { useCallback, useEffect, useState } from 'react'
import { api } from '../../../api'
import RangeFilter, { rangePreset } from '../../../components/RangeFilter'
import { fmtRp, reportPdf } from '../../../financePdf'

const GROUP_META = {
  operating: { title: 'Arus Kas Operasional', desc: 'Penjualan & pembayaran harian (bahan, gaji, utilitas)' },
  investing: { title: 'Arus Kas Investasi', desc: 'Pembelian/perolehan aset & peralatan' },
  financing: { title: 'Arus Kas Pendanaan', desc: 'Modal owner & pengambilan prive' },
}

export default function ArusKas() {
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
    api.get(`/finance/cash-flow?from=${from}&to=${to}`)
      .then(setData)
      .catch((e) => setError(e.message))
  }, [from, to])
  useEffect(load, [load])

  const download = () => {
    const d = data
    const blocks = []
    for (const key of ['operating', 'investing', 'financing']) {
      const g = d[key]
      blocks.push({
        heading: GROUP_META[key].title.toUpperCase(),
        rows: [
          ...g.details.filter((x) => x.kind === 'in').map((x) => ({ label: x.label, value: x.amount, sub: true })),
          ...g.details.filter((x) => x.kind === 'out').map((x) => ({ label: x.label, value: x.amount, sub: true, negative: true })),
          { label: `Net ${GROUP_META[key].title}`, value: g.net, strong: true },
        ],
        rule: true,
      })
    }
    blocks.push(
      { rows: [{ label: 'Kenaikan / Penurunan Kas', value: d.net_change, strong: true }] },
      { rows: [
        { label: 'Saldo Kas Awal', value: d.opening_balance },
        { label: 'Saldo Kas Akhir', value: d.closing_balance, strong: true },
      ], rule: true },
    )
    reportPdf({ title: 'Laporan Arus Kas', from, to, filename: `Arus-Kas_${from}_${to}.pdf`, blocks })
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
        <>
          <div className="grid sm:grid-cols-3 gap-5">
            <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-6">
              <p className="text-xs text-char/50">Saldo Kas Awal</p>
              <p className="font-display text-2xl mt-1">{fmtRp(data.opening_balance)}</p>
            </div>
            <div className={`rounded-2xl p-6 shadow-sm ${data.net_change >= 0 ? 'bg-green-50' : 'bg-red-50'}`}>
              <p className="text-xs text-char/50">{data.net_change >= 0 ? 'Kenaikan Kas' : 'Penurunan Kas'}</p>
              <p className={`font-display text-2xl mt-1 ${data.net_change >= 0 ? 'text-green-700' : 'text-chili'}`}>{data.net_change < 0 && '−'}{fmtRp(Math.abs(data.net_change))}</p>
            </div>
            <div className="bg-char text-cream rounded-2xl p-6 shadow-sm">
              <p className="text-xs opacity-60">Saldo Kas Akhir</p>
              <p className="font-display text-2xl mt-1">{fmtRp(data.closing_balance)}</p>
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
            <h3 className="px-6 py-4 font-bold border-b border-black/5">Rincian Arus Kas</h3>
            <div className="divide-y divide-black/5">
              {['operating', 'investing', 'financing'].map((key) => {
                const g = data[key]
                return (
                  <div key={key}>
                    <div className="px-6 py-4 flex flex-wrap items-center justify-between gap-2 bg-cream/40">
                      <div>
                        <p className="font-bold text-sm">{GROUP_META[key].title}</p>
                        <p className="text-xs text-char/40">{GROUP_META[key].desc}</p>
                      </div>
                      <p className={`font-display text-lg ${g.net >= 0 ? 'text-green-700' : 'text-chili'}`}>{g.net < 0 && '−'}{fmtRp(Math.abs(g.net))}</p>
                    </div>
                    {g.details.length === 0 && <p className="px-6 py-3 text-xs text-char/40">Tidak ada aktivitas.</p>}
                    {g.details.map((d) => (
                      <div key={d.label + d.kind} className="px-6 py-2.5 flex justify-between text-sm border-t border-black/5">
                        <span className="text-char/70 pl-2">{d.label}</span>
                        <span className={d.kind === 'in' ? 'text-green-700 font-semibold' : 'text-chili font-semibold'}>{d.kind === 'in' ? '+' : '−'} {fmtRp(d.amount)}</span>
                      </div>
                    ))}
                  </div>
                )
              })}
            </div>
          </div>
        </>
      )}
    </div>
  )
}
