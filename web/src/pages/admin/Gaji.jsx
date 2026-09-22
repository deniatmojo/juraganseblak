import { useCallback, useEffect, useState } from 'react'
import { api } from '../../api'
import { jsPDF } from 'jspdf'

const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

const MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

// Slip gaji PDF — rekap periode yang dibayar + kolom tanda tangan, auto-download.
function downloadSlip(p) {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  const W = 210
  let y = 18

  // Kop
  doc.setFillColor(22, 17, 15) // char
  doc.rect(0, 0, W, 26, 'F')
  doc.setTextColor(250, 243, 236) // cream
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(16)
  doc.text('JURAGAN SEBLAK', 14, 12)
  doc.setFontSize(8)
  doc.setFont('helvetica', 'normal')
  doc.text('Slip Pembayaran Gaji Karyawan', 14, 18)
  doc.setTextColor(249, 115, 22) // ember
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(9)
  doc.text(`No. #${String(p.payment_id).padStart(5, '0')}`, W - 14, 12, { align: 'right' })
  doc.setTextColor(250, 243, 236)
  doc.setFont('helvetica', 'normal')
  doc.text(new Date().toLocaleString('id-ID'), W - 14, 18, { align: 'right' })
  y = 36

  doc.setTextColor(22, 17, 15)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(12)
  doc.text('BUKTI PEMBAYARAN GAJI', W / 2, y, { align: 'center' })
  y += 8

  // Info karyawan & periode
  doc.setFontSize(10)
  doc.setFont('helvetica', 'normal')
  const info = [
    ['Nama Karyawan', `: ${p.employee}`],
    ['Periode', `: ${p.from} s/d ${p.to}`],
    ['Tarif Harian', `: ${formatRp(p.daily_rate)}`],
    ['Hari Hadir', `: ${p.days} hari`],
  ]
  info.forEach(([k, v]) => { doc.text(`${k}   ${v}`, 14, y); y += 6 })
  y += 2

  // Tabel rincian
  const rows = [
    [`Gaji (${p.days} hari x ${formatRp(p.daily_rate)})`, formatRp(p.gaji)],
    ['Potongan Kasbon', p.kasbon > 0 ? `- ${formatRp(p.kasbon)}` : '-'],
  ]
  doc.setDrawColor(200)
  doc.line(14, y, W - 14, y)
  y += 6
  rows.forEach(([label, val]) => {
    doc.setFont('helvetica', 'normal')
    doc.text(label, 14, y)
    doc.text(val, W - 14, y, { align: 'right' })
    y += 6
  })
  doc.line(14, y, W - 14, y)
  y += 7
  doc.setFillColor(22, 17, 15)
  doc.rect(14, y - 5, W - 28, 10, 'F')
  doc.setTextColor(250, 243, 236)
  doc.setFont('helvetica', 'bold')
  doc.text('TOTAL DIBAYARKAN', 18, y + 1.5)
  doc.text(formatRp(p.total), W - 18, y + 1.5, { align: 'right' })
  y += 16

  doc.setTextColor(22, 17, 15)
  doc.setFontSize(8)
  doc.setFont('helvetica', 'normal')
  doc.text('Pembayaran tercatat sebagai pengeluaran kategori "gaji" di modul Keuangan. Dokumen ini sah tanpa tanda tangan basah.', 14, y, { maxWidth: W - 28 })
  y += 10

  // Tanda tangan
  const sy = Math.max(y + 10, 240)
  doc.setFontSize(10)
  doc.text('Diterima oleh,', 34, sy)
  doc.text('Disetujui oleh,', W - 64, sy)
  doc.setDrawColor(120)
  doc.line(24, sy + 22, 74, sy + 22)
  doc.line(W - 74, sy + 22, W - 24, sy + 22)
  doc.setFont('helvetica', 'bold')
  doc.text(p.employee, 49, sy + 27, { align: 'center' })
  doc.text('Owner Juragan Seblak', W / 2 + 25, sy + 27, { align: 'center' })

  doc.save(`Slip-Gaji-${p.employee.replace(/\s+/g, '_')}-${p.from}_${p.to}.pdf`)
}

export default function Gaji() {
  const monthStart = new Date()
  monthStart.setDate(1)
  const [dateFrom, setDateFrom] = useState(monthStart.toISOString().slice(0, 10))
  const [dateTo, setDateTo] = useState(new Date().toISOString().slice(0, 10))
  const [rows, setRows] = useState([])
  const [error, setError] = useState('')
  const [kasbonForm, setKasbonForm] = useState(null) // { id, name, amount, note }
  const [payTarget, setPayTarget] = useState(null)   // row yang mau dibayar
  const [justPaid, setJustPaid] = useState(null)     // hasil bayar → tombol slip PDF

  // Filter rekap riwayat pembayaran
  const [histYear, setHistYear] = useState(new Date().getFullYear())
  const [histMonth, setHistMonth] = useState('')     // '' = setahun
  const [histEmp, setHistEmp] = useState('')         // '' = semua
  const [history, setHistory] = useState([])

  const load = useCallback(() => {
    api.get(`/payroll?from=${dateFrom}&to=${dateTo}`)
      .then(setRows)
      .catch((e) => setError(e.message))
  }, [dateFrom, dateTo])
  useEffect(load, [load])

  const loadHistory = useCallback(() => {
    const q = new URLSearchParams({ year: histYear })
    if (histMonth) q.set('month', histMonth)
    if (histEmp) q.set('employee_id', histEmp)
    api.get(`/payroll/history?${q}`)
      .then(setHistory)
      .catch(() => setHistory([]))
  }, [histYear, histMonth, histEmp])
  useEffect(loadHistory, [loadHistory])

  const years = Array.from({ length: 5 }, (_, i) => new Date().getFullYear() - i)

  const totalGaji = rows.reduce((s, r) => s + r.gaji, 0)
  const totalKasbon = rows.reduce((s, r) => s + r.kasbon_open, 0)
  const totalPending = rows.reduce((s, r) => s + Math.max(r.pending, 0), 0)

  const histTotal = history.reduce((s, r) => s + r.total, 0)
  const histGaji = history.reduce((s, r) => s + r.gaji, 0)
  const histKasbon = history.reduce((s, r) => s + r.kasbon, 0)

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
      setJustPaid(res)
      load()
      loadHistory()
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
          <div><p className="text-xs text-char/50">Pending Bayar</p><p className="font-display text-xl text-ember">{formatRp(totalPending)}</p></div>
        </div>
      </div>

      {/* SUKSES BAYAR → SLIP PDF */}
      {justPaid && (
        <div className="bg-char text-cream rounded-2xl p-6 flex flex-wrap items-center gap-5 shadow-sm">
          <span className="w-12 h-12 rounded-full bg-green-500/20 grid place-items-center shrink-0">
            <svg className="w-6 h-6 text-green-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" /></svg>
          </span>
          <div className="flex-1 min-w-[220px]">
            <p className="font-display uppercase">Gaji {justPaid.employee} dibayar</p>
            <p className="text-cream/60 text-sm mt-1">
              {formatRp(justPaid.total)} — periode {justPaid.from} s/d {justPaid.to} ({justPaid.days} hari{justPaid.kasbon > 0 ? `, dikurangi kasbon ${formatRp(justPaid.kasbon)}` : ''}). Tercatat di Keuangan & rekap di bawah.
            </p>
          </div>
          <button onClick={() => downloadSlip(justPaid)} className="bg-chili hover:bg-chili-dark text-white font-bold px-5 py-3 rounded-full text-sm flex items-center gap-2">
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
            Unduh Slip Gaji (PDF)
          </button>
          <button onClick={() => setJustPaid(null)} className="text-cream/50 hover:text-cream text-xl leading-none px-2" aria-label="Tutup">×</button>
        </div>
      )}

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
                <th className="px-6 py-3 font-bold">Pending Bayar</th>
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
                  <td className={`px-6 py-4 font-display ${r.pending > 0 ? 'text-ember' : 'text-char/40'}`}>
                    {r.pending > 0 ? formatRp(r.pending) : 'Lunas ✓'}
                  </td>
                  <td className="px-6 py-4 text-right space-x-3 whitespace-nowrap">
                    <button onClick={() => setKasbonForm({ id: r.id, name: r.name, amount: '', note: '' })} className="text-xs font-bold text-char/70 hover:text-char underline">+ Kasbon</button>
                    {r.pending > 0 && (
                      <button onClick={() => setPayTarget(r)} className="text-xs font-bold text-white bg-char hover:bg-char-soft px-4 py-2 rounded-full">Bayar</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* REKAP RIWAYAT PEMBAYARAN (BULANAN / TAHUNAN) */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-3 px-6 py-5 border-b border-black/5">
          <div>
            <h2 className="font-bold">Rekap Pembayaran Gaji</h2>
            <p className="text-xs text-char/50 mt-0.5">Riwayat gaji yang sudah dibayar — bisa difilter per tahun, bulan, atau karyawan.</p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <select value={histYear} onChange={(e) => setHistYear(Number(e.target.value))} className="border border-black/15 rounded-full px-4 py-2 text-xs font-semibold">
              {years.map((y) => <option key={y} value={y}>{y}</option>)}
            </select>
            <select value={histMonth} onChange={(e) => setHistMonth(e.target.value)} className="border border-black/15 rounded-full px-4 py-2 text-xs font-semibold">
              <option value="">Semua Bulan</option>
              {MONTHS.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
            </select>
            <select value={histEmp} onChange={(e) => setHistEmp(e.target.value)} className="border border-black/15 rounded-full px-4 py-2 text-xs font-semibold">
              <option value="">Semua Karyawan</option>
              {rows.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
            </select>
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[760px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Tanggal Bayar</th>
                <th className="px-6 py-3 font-bold">Karyawan</th>
                <th className="px-6 py-3 font-bold">Posisi</th>
                <th className="px-6 py-3 font-bold">Periode</th>
                <th className="px-6 py-3 font-bold">Hari</th>
                <th className="px-6 py-3 font-bold">Gaji</th>
                <th className="px-6 py-3 font-bold">Kasbon</th>
                <th className="px-6 py-3 font-bold">Dibayarkan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {history.length === 0 && (
                <tr><td colSpan={8} className="px-6 py-8 text-center text-char/40">Belum ada pembayaran pada filter ini.</td></tr>
              )}
              {history.map((h) => (
                <tr key={h.id} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4 text-char/60 whitespace-nowrap">{h.paid_at}</td>
                  <td className="px-6 py-4 font-semibold">{h.name}</td>
                  <td className="px-6 py-4 text-char/60">{h.posisi || '—'}</td>
                  <td className="px-6 py-4 text-char/60 whitespace-nowrap">{h.periode_from} — {h.periode_to}</td>
                  <td className="px-6 py-4 font-semibold">{h.days}</td>
                  <td className="px-6 py-4">{formatRp(h.gaji)}</td>
                  <td className={`px-6 py-4 ${h.kasbon > 0 ? 'text-chili font-bold' : 'text-char/40'}`}>{h.kasbon > 0 ? formatRp(h.kasbon) : '—'}</td>
                  <td className="px-6 py-4 font-display text-ember">{formatRp(h.total)}</td>
                </tr>
              ))}
            </tbody>
            {history.length > 0 && (
              <tfoot>
                <tr className="border-t border-black/10 bg-cream/50 font-bold">
                  <td className="px-6 py-4" colSpan={4}>Total ({history.length} pembayaran)</td>
                  <td className="px-6 py-4">{history.reduce((s, h) => s + h.days, 0)}</td>
                  <td className="px-6 py-4">{formatRp(histGaji)}</td>
                  <td className="px-6 py-4 text-chili">{histKasbon > 0 ? formatRp(histKasbon) : '—'}</td>
                  <td className="px-6 py-4 font-display text-ember">{formatRp(histTotal)}</td>
                </tr>
              </tfoot>
            )}
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
              <div className="flex justify-between font-bold pt-2 border-t border-black/10"><span>Pending Bayar</span><span className="text-ember">{formatRp(payTarget.pending)}</span></div>
            </div>
            <p className="text-xs text-char/40 mb-5">Setelah dibayar: tercatat di Keuangan, masuk rekap pembayaran, dan slip gaji (PDF) bisa diunduh.</p>
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
