import { useCallback, useEffect, useState } from 'react'
import { api } from '../../../api'
import RangeFilter, { rangePreset } from '../../../components/RangeFilter'
import { fmtRp, reportPdf } from '../../../financePdf'

const GROUP_LABEL = { aset: 'Aset', hpp: 'Harga Pokok', pendapatan: 'Pendapatan', beban: 'Beban', investasi: 'Investasi', pendanaan: 'Pendanaan' }

export default function BukuBesar() {
  const [accounts, setAccounts] = useState([])
  const [account, setAccount] = useState('kas')
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

  useEffect(() => {
    api.get('/finance/accounts').then(setAccounts).catch(() => {})
  }, [])

  const load = useCallback(() => {
    api.get(`/finance/ledger?account=${account}&from=${from}&to=${to}`)
      .then(setData)
      .catch((e) => setError(e.message))
  }, [account, from, to])
  useEffect(load, [load])

  const accountLabel = accounts.find((a) => a.key === account)?.label || account

  const download = () => {
    const d = data
    reportPdf({
      title: `Buku Besar — ${accountLabel}`,
      from, to,
      filename: `Buku-Besar_${account}_${from}_${to}.pdf`,
      blocks: [
        { rows: [{ label: 'Saldo Awal', value: d.opening_balance }] },
        { heading: 'MUTASI', rows: d.rows.map((r) => ({
          label: `${String(r.date).slice(0, 10).split('-').reverse().join('/')} · ${r.description}`,
          value: r.debit - r.credit,
          sub: true, negative: r.credit > 0,
        })) },
        {
          rows: [
            { label: 'Total Debit', value: d.total_debit },
            { label: 'Total Kredit', value: d.total_kredit },
            { label: 'Saldo Akhir', value: d.closing_balance, strong: true },
          ],
          rule: true,
        },
      ],
    })
  }

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm px-6 py-5 flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <select value={account} onChange={(e) => setAccount(e.target.value)} className="border border-black/15 rounded-xl px-4 py-2.5 text-sm font-semibold min-w-[220px]">
            <optgroup label="Utama">
              {accounts.filter((a) => a.key === 'kas' || a.key === 'hpp').map((a) => <option key={a.key} value={a.key}>{a.label}</option>)}
            </optgroup>
            {['pendapatan', 'beban', 'investasi', 'pendanaan'].map((g) => accounts.some((a) => a.group === g) && (
              <optgroup key={g} label={GROUP_LABEL[g]}>
                {accounts.filter((a) => a.group === g).map((a) => <option key={a.key} value={a.key}>{a.label}</option>)}
              </optgroup>
            ))}
          </select>
          <RangeFilter preset={preset} onPreset={applyPreset} from={from} to={to} onFrom={setFrom} onTo={setTo} />
        </div>
        <button onClick={download} disabled={!data} className="bg-chili hover:bg-chili-dark disabled:opacity-40 text-white font-bold px-5 py-2.5 rounded-full text-sm flex items-center gap-2">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
          Unduh PDF
        </button>
      </div>

      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      {data && (
        <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
          <div className="px-6 py-5 border-b border-black/5 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h3 className="font-bold">Buku Besar — {accountLabel}</h3>
              <p className="text-xs text-char/50 mt-0.5">Saldo berjalan per mutasi akun</p>
            </div>
            <div className="flex gap-6 text-sm">
              <div><p className="text-xs text-char/50">Saldo Awal</p><p className="font-display text-lg">{fmtRp(data.opening_balance)}</p></div>
              <div><p className="text-xs text-char/50">Saldo Akhir</p><p className="font-display text-lg text-ember">{fmtRp(data.closing_balance)}</p></div>
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm min-w-[760px]">
              <thead>
                <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                  <th className="px-6 py-3 font-bold">Tanggal</th>
                  <th className="px-6 py-3 font-bold">Keterangan</th>
                  <th className="px-4 py-3 font-bold text-right">Debit</th>
                  <th className="px-4 py-3 font-bold text-right">Kredit</th>
                  <th className="px-6 py-3 font-bold text-right">Saldo</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-black/5">
                <tr className="bg-cream/40">
                  <td className="px-6 py-3 text-char/60" colSpan={4}>Saldo awal periode</td>
                  <td className="px-6 py-3 text-right font-display">{fmtRp(data.opening_balance)}</td>
                </tr>
                {data.rows.length === 0 && (
                  <tr><td colSpan={5} className="px-6 py-8 text-center text-char/40">Tidak ada mutasi pada periode ini.</td></tr>
                )}
                {data.rows.map((r, i) => (
                  <tr key={i} className="hover:bg-cream/60 transition-colors">
                    <td className="px-6 py-3 text-char/60 whitespace-nowrap">{String(r.date).slice(0, 10).split('-').reverse().join('/')}</td>
                    <td className="px-6 py-3">{r.description}</td>
                    <td className="px-4 py-3 text-right">{r.debit ? fmtRp(r.debit) : '—'}</td>
                    <td className="px-4 py-3 text-right text-chili">{r.credit ? fmtRp(r.credit) : '—'}</td>
                    <td className="px-6 py-3 text-right font-semibold">{fmtRp(r.balance)}</td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t border-black/10 bg-cream/50 font-bold">
                  <td className="px-6 py-4" colSpan={2}>Total</td>
                  <td className="px-4 py-4 text-right">{fmtRp(data.total_debit)}</td>
                  <td className="px-4 py-4 text-right text-chili">{fmtRp(data.total_kredit)}</td>
                  <td className="px-6 py-4 text-right font-display text-ember">{fmtRp(data.closing_balance)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
