import { useCallback, useEffect, useState } from 'react'
import { api } from '../../../api'
import RangeFilter, { rangePreset } from '../../../components/RangeFilter'
import { fmtRp, reportPdf } from '../../../financePdf'

export default function Jurnal() {
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
    api.get(`/finance/journal?from=${from}&to=${to}`)
      .then(setData)
      .catch((e) => setError(e.message))
  }, [from, to])
  useEffect(load, [load])

  const download = () => {
    const d = data
    reportPdf({
      title: 'Jurnal Umum',
      from, to,
      filename: `Jurnal-Umum_${from}_${to}.pdf`,
      blocks: [
        ...d.entries.map((e) => ({
          rows: [
            { label: `${String(e.date).slice(0, 10).split('-').reverse().join('/')} · ${e.description}`, value: e.amount, strong: true },
            { label: `    D  ${e.debit_account}`, value: '', sub: true },
            { label: `    K  ${e.credit_account}`, value: '', sub: true },
          ],
        })),
        { rows: [{ label: 'TOTAL DEBIT = TOTAL KREDIT', value: d.total_debit, strong: true }], rule: true },
      ],
    })
  }

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm px-6 py-5 flex flex-wrap items-center justify-between gap-3">
        <RangeFilter preset={preset} onPreset={applyPreset} from={from} to={to} onFrom={setFrom} onTo={setTo} />
        <div className="flex items-center gap-4">
          {data && <span className={`text-xs font-bold px-3 py-1.5 rounded-full ${data.balanced ? 'bg-green-50 text-green-700' : 'bg-red-50 text-chili'}`}>{data.balanced ? '✓ Seimbang (Debit = Kredit)' : '✗ Tidak Seimbang'}</span>}
          <button onClick={download} disabled={!data} className="bg-chili hover:bg-chili-dark disabled:opacity-40 text-white font-bold px-5 py-2.5 rounded-full text-sm flex items-center gap-2">
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
            Unduh PDF
          </button>
        </div>
      </div>

      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      {data && (
        <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
          <div className="px-6 py-5 border-b border-black/5 flex items-center justify-between">
            <h3 className="font-bold">Jurnal Umum</h3>
            <span className="text-xs text-char/50">{data.entries.length} entri</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm min-w-[860px]">
              <thead>
                <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                  <th className="px-6 py-3 font-bold w-12">No</th>
                  <th className="px-4 py-3 font-bold">Tanggal</th>
                  <th className="px-4 py-3 font-bold">Keterangan</th>
                  <th className="px-4 py-3 font-bold">Akun Debit</th>
                  <th className="px-4 py-3 font-bold">Akun Kredit</th>
                  <th className="px-6 py-3 font-bold text-right">Nominal</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-black/5">
                {data.entries.length === 0 && (
                  <tr><td colSpan={6} className="px-6 py-8 text-center text-char/40">Tidak ada transaksi pada periode ini.</td></tr>
                )}
                {data.entries.map((e) => (
                  <tr key={e.id} className="hover:bg-cream/60 transition-colors">
                    <td className="px-6 py-3 text-char/40">{e.no}</td>
                    <td className="px-4 py-3 text-char/60 whitespace-nowrap">{String(e.date).slice(0, 10).split('-').reverse().join('/')}</td>
                    <td className="px-4 py-3">{e.description}</td>
                    <td className="px-4 py-3 font-semibold">{e.debit_account}</td>
                    <td className="px-4 py-3 text-char/70">{e.credit_account}</td>
                    <td className="px-6 py-3 text-right font-display">{fmtRp(e.amount)}</td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t border-black/10 bg-cream/50 font-bold">
                  <td className="px-6 py-4" colSpan={5}>Total Debit (= Total Kredit)</td>
                  <td className="px-6 py-4 text-right font-display text-ember">{fmtRp(data.total_debit)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
