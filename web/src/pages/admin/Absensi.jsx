import { useCallback, useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { api } from '../../api'

const fmtTime = (dt) => (dt ? new Date(dt).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : '—')

// shift '09:00' + 8 jam → '17:00' (untuk pratinjau estimasi jam keluar)
const addHours = (hhmm, hours) => {
  if (!hhmm) return ''
  const [h, m] = hhmm.split(':').map(Number)
  const total = Math.round(h * 60 + m + Number(hours || 0) * 60)
  const hh = String(Math.floor(total / 60) % 24).padStart(2, '0')
  const mm = String(total % 60).padStart(2, '0')
  return `${hh}:${mm}`
}

const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

// Preset rentang tanggal untuk rekap
function rangePreset(kind) {
  const now = new Date()
  if (kind === 'today') return { from: iso(now), to: iso(now) }
  if (kind === 'week') {
    const from = new Date(now); from.setDate(now.getDate() - 6)
    return { from: iso(from), to: iso(now) }
  }
  if (kind === 'month') {
    const from = new Date(now.getFullYear(), now.getMonth(), 1)
    return { from: iso(from), to: iso(now) }
  }
  if (kind === 'lastmonth') {
    const from = new Date(now.getFullYear(), now.getMonth() - 1, 1)
    const to = new Date(now.getFullYear(), now.getMonth(), 0)
    return { from: iso(from), to: iso(to) }
  }
  return null
}

const statusCls = {
  hadir: 'text-green-700 bg-green-50',
  terlambat: 'text-ember bg-ember/10',
  izin: 'text-ember bg-ember/10',
  sakit: 'text-ember bg-ember/10',
  alpa: 'text-chili bg-red-50',
}
const statusLabel = { hadir: 'Hadir', terlambat: 'Terlambat', izin: 'Izin', sakit: 'Sakit', alpa: 'Tanpa Keterangan' }

const inputCls = 'w-full bg-white border border-black/15 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30 focus:border-chili'

/* ============ CLOCK DIAL — picker jam berputar 24 jam dalam popup ============ */
function ClockDial({ value, onChange, onClose, name }) {
  const [hh, m0] = (value || '').split(':')
  const [hour, setHour] = useState(hh ? Number(hh) : null)
  const [minute, setMinute] = useState(m0 ? Number(m0) : null)
  const [step, setStep] = useState('hour') // 'hour' | 'minute'

  const SIZE = 260, C = SIZE / 2, R = 104
  const values = step === 'hour'
    ? Array.from({ length: 24 }, (_, i) => i)
    : Array.from({ length: 12 }, (_, i) => i * 5)
  const max = step === 'hour' ? 24 : 60
  const current = step === 'hour' ? hour : minute

  const pos = (v) => {
    const ang = (v / max) * Math.PI * 2 - Math.PI / 2
    return { x: C + R * Math.cos(ang), y: C + R * Math.sin(ang), ang }
  }

  const pick = (v) => {
    if (step === 'hour') { setHour(v); setStep('minute') }
    else {
      setMinute(v)
      onChange(`${String(hour ?? 0).padStart(2, '0')}:${String(v).padStart(2, '0')}`)
      onClose()
    }
  }

  const needle = current !== null ? pos(current) : null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
      <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={onClose}></div>
      <div className="relative bg-white rounded-3xl w-full max-w-xs p-7 text-center">
        <h3 className="font-display text-lg uppercase">Atur Jam Masuk</h3>
        <p className="text-char/50 text-sm mb-4">{name}</p>

        {/* Tampilan HH : MM — klik untuk pindah langkah */}
        <div className="flex items-center justify-center gap-2 mb-4">
          <button onClick={() => setStep('hour')} className={`font-display text-4xl tabular-nums rounded-2xl px-4 py-1.5 transition-colors ${step === 'hour' ? 'bg-chili text-white' : 'bg-cream text-char/60 hover:bg-cream/70'}`}>
            {hour !== null ? String(hour).padStart(2, '0') : '––'}
          </button>
          <span className="font-display text-3xl text-char/30 animate-pulse">:</span>
          <button onClick={() => hour !== null && setStep('minute')} className={`font-display text-4xl tabular-nums rounded-2xl px-4 py-1.5 transition-colors ${step === 'minute' ? 'bg-chili text-white' : 'bg-cream text-char/60 hover:bg-cream/70'}`}>
            {minute !== null ? String(minute).padStart(2, '0') : '––'}
          </button>
        </div>
        <p className="text-[11px] text-char/40 -mt-2 mb-3">
          {step === 'hour' ? 'Pilih jam (0–23) pada pukul berputar' : 'Pilih menit (kelipatan 5)'}
        </p>

        {/* Dial */}
        <svg viewBox={`0 0 ${SIZE} ${SIZE}`} className="w-full select-none">
          <circle cx={C} cy={C} r={R + 18} fill="#FAF3EC" />
          {needle && (
            <g>
              <line x1={C} y1={C} x2={needle.x} y2={needle.y} stroke="#C81E1E" strokeWidth="3" strokeLinecap="round" />
              <circle cx={C} cy={C} r="6" fill="#C81E1E" />
              <circle cx={needle.x} cy={needle.y} r="14" fill="#C81E1E" />
            </g>
          )}
          {values.map((v) => {
            const p = pos(v)
            const active = current === v
            return (
              <g key={v} onClick={() => pick(v)} className="cursor-pointer">
                <circle cx={p.x} cy={p.y} r={active ? 15 : 13} fill={active ? '#C81E1E' : '#fff'} stroke={active ? '#C81E1E' : '#16110F22'} strokeWidth="1" />
                <text x={p.x} y={p.y + 4} textAnchor="middle" fontSize="12" fontWeight={active ? 800 : 600} fill={active ? '#fff' : '#16110FB0'} className="pointer-events-none">
                  {String(v).padStart(2, '0')}
                </text>
              </g>
            )
          })}
        </svg>

        <div className="flex gap-3 mt-4">
          {value && (
            <button onClick={() => { onChange(''); onClose() }} className="flex-1 border border-black/15 text-chili font-bold py-3 rounded-full text-sm">Hapus</button>
          )}
          <button onClick={onClose} className="flex-1 bg-char hover:bg-char-soft text-white font-bold py-3 rounded-full text-sm">Selesai</button>
        </div>
      </div>
    </div>
  )
}

/* ============ REKAP ABSENSI — filter rentang tanggal, pribadi vs semua ============ */
function RekapAbsensi({ personal }) {
  const [preset, setPreset] = useState('month')
  const [from, setFrom] = useState(rangePreset('month').from)
  const [to, setTo] = useState(rangePreset('month').to)
  const [data, setData] = useState({ employees: [], records: [] })
  const [error, setError] = useState('')

  const applyPreset = (k) => {
    setPreset(k)
    const r = rangePreset(k)
    if (r) { setFrom(r.from); setTo(r.to) }
  }

  const load = useCallback(() => {
    api.get(`/attendance/recap?from=${from}&to=${to}`)
      .then(setData)
      .catch((e) => setError(e.message))
  }, [from, to])
  useEffect(load, [load])

  const presets = [
    ['today', 'Hari Ini'],
    ['week', '7 Hari Terakhir'],
    ['month', 'Bulan Ini'],
    ['lastmonth', 'Bulan Lalu'],
    ['custom', 'Rentang Custom'],
  ]

  return (
    <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
      <div className="flex flex-wrap items-center justify-between gap-3 px-6 py-5 border-b border-black/5">
        <div>
          <h2 className="font-bold">Rekap Absensi {personal ? 'Saya' : 'Semua Karyawan'}</h2>
          <p className="text-xs text-char/50 mt-0.5">
            {personal ? 'Riwayat absensi pribadi Anda.' : 'Ringkasan kehadiran seluruh karyawan aktif.'}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {presets.map(([k, label]) => (
            <button
              key={k}
              onClick={() => applyPreset(k)}
              className={`text-xs font-bold px-3.5 py-2 rounded-full transition-colors ${preset === k ? 'bg-char text-white' : 'bg-cream text-char/60 hover:bg-cream/70'}`}
            >
              {label}
            </button>
          ))}
          {preset === 'custom' && (
            <span className="flex items-center gap-2">
              <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} className="border border-black/15 rounded-full px-3 py-1.5 text-xs" />
              <span className="text-char/40 text-xs">s/d</span>
              <input type="date" value={to} onChange={(e) => setTo(e.target.value)} className="border border-black/15 rounded-full px-3 py-1.5 text-xs" />
            </span>
          )}
        </div>
      </div>
      <div className="overflow-x-auto">
        {error ? (
          <p className="px-6 py-8 text-center text-chili text-sm font-bold">{error}</p>
        ) : personal ? (
          <table className="w-full text-sm min-w-[560px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Tanggal</th>
                <th className="px-6 py-3 font-bold">Jam Masuk</th>
                <th className="px-6 py-3 font-bold">Jam Keluar</th>
                <th className="px-6 py-3 font-bold">Status</th>
                <th className="px-6 py-3 font-bold">Catatan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {data.records.length === 0 && (
                <tr><td colSpan={5} className="px-6 py-8 text-center text-char/40">Belum ada absensi pada rentang ini.</td></tr>
              )}
              {data.records.map((r) => (
                <tr key={r.work_date} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4 font-semibold">{r.tanggal}</td>
                  <td className={`px-6 py-4 ${r.clock_in ? '' : 'text-char/40'}`}>{r.clock_in || '—'}</td>
                  <td className={`px-6 py-4 ${r.clock_out ? '' : 'text-char/40'}`}>{r.clock_out || '—'}</td>
                  <td className="px-6 py-4">
                    <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${statusCls[r.status] || ''}`}>{statusLabel[r.status] || r.status || '—'}</span>
                  </td>
                  <td className="px-6 py-4 text-char/50 text-xs">{r.note || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <table className="w-full text-sm min-w-[720px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Karyawan</th>
                <th className="px-4 py-3 font-bold">Posisi</th>
                <th className="px-4 py-3 font-bold text-center">Hadir</th>
                <th className="px-4 py-3 font-bold text-center">Terlambat</th>
                <th className="px-4 py-3 font-bold text-center">Izin</th>
                <th className="px-4 py-3 font-bold text-center">Sakit</th>
                <th className="px-4 py-3 font-bold text-center">Alpa</th>
                <th className="px-6 py-3 font-bold text-center">Total Tercatat</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {data.employees.length === 0 && (
                <tr><td colSpan={8} className="px-6 py-8 text-center text-char/40">Belum ada data.</td></tr>
              )}
              {data.employees.map((r) => (
                <tr key={r.id} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <span className="w-9 h-9 rounded-full bg-cream grid place-items-center font-display text-sm shrink-0">{r.name.slice(0, 1)}</span>
                      <span className="font-semibold">{r.name}</span>
                    </div>
                  </td>
                  <td className="px-4 py-4 text-char/60">{r.posisi || '—'}</td>
                  <td className="px-4 py-4 text-center font-bold text-green-700">{r.hadir}</td>
                  <td className="px-4 py-4 text-center font-bold text-ember">{r.terlambat}</td>
                  <td className="px-4 py-4 text-center text-char/60">{r.izin}</td>
                  <td className="px-4 py-4 text-center text-char/60">{r.sakit}</td>
                  <td className="px-4 py-4 text-center font-bold text-chili">{r.alpa}</td>
                  <td className="px-6 py-4 text-center font-display">{r.tercatat}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

export default function Absensi() {
  const { user } = useOutletContext()
  const isOwner = user?.role === 'owner'
  const isBoss = isOwner || user?.role === 'admin'

  const [rows, setRows] = useState([])
  const [date, setDate] = useState(iso(new Date()))
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [statusForm, setStatusForm] = useState(null) // { employee_id, name, status, note }
  const [schedule, setSchedule] = useState([])       // setting jadwal (owner)
  const [savingId, setSavingId] = useState(null)
  const [dialFor, setDialFor] = useState(null)       // { id, name, shift_start }

  const myEmployee = rows.find((r) => r.user_id === user?.id)
  const myRow = myEmployee

  const load = useCallback(() => {
    api.get(`/attendance?date=${date}`)
      .then(setRows)
      .catch((e) => setError(e.message))
  }, [date])
  useEffect(load, [load])

  const loadSchedule = useCallback(() => {
    if (!isOwner) return
    api.get('/employees')
      .then(setSchedule)
      .catch(() => {})
  }, [isOwner])
  useEffect(loadSchedule, [loadSchedule])

  const clock = async (kind) => {
    setBusy(true)
    setError('')
    try {
      await api.post(`/attendance/${kind}`)
      load()
    } catch (e) { setError(e.message) }
    finally { setBusy(false) }
  }

  const saveStatus = async () => {
    try {
      await api.patch('/attendance/status', {
        employee_id: statusForm.employee_id,
        work_date: date,
        status: statusForm.status,
        note: statusForm.note || null,
      })
      setStatusForm(null)
      load()
    } catch (e) { setError(e.message) }
  }

  // Setting jadwal: ubah durasi kerja (jam masuk via ClockDial)
  const editSchedule = (id, field, value) => {
    setSchedule((prev) => prev.map((s) => (s.id === id ? { ...s, [field]: value, dirty: true } : s)))
  }
  const saveSchedule = async (s) => {
    setSavingId(s.id)
    setError('')
    try {
      await api.patch(`/employees/${s.id}`, {
        shift_start: s.shift_start || null,
        work_hours: Number(s.work_hours || 8),
      })
      setSchedule((prev) => prev.map((x) => (x.id === s.id ? { ...x, dirty: false } : x)))
      load()
    } catch (e) { setError(e.message) }
    finally { setSavingId(null) }
  }

  const hadir = rows.filter((r) => r.status === 'hadir' || r.status === 'terlambat').length
  const izinSakit = rows.filter((r) => r.status === 'izin' || r.status === 'sakit').length
  const alpa = rows.filter((r) => r.status === 'alpa' || (!r.status && date < iso(new Date()))).length

  const summary = [
    { value: hadir, label: 'Hadir', iconCls: 'bg-green-50', color: 'text-green-600', icon: 'M5 13l4 4L19 7' },
    { value: izinSakit, label: 'Izin / Sakit', iconCls: 'bg-ember/10', color: 'text-ember', icon: 'M12 8v4l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z' },
    { value: alpa, label: 'Tanpa Keterangan', iconCls: 'bg-red-50', color: 'text-chili', icon: 'M6 18L18 6M6 6l12 12' },
  ]

  const statusText = !myEmployee
    ? 'Akun belum terhubung ke data karyawan — hubungi admin.'
    : !myRow.clock_in
      ? 'Belum absen masuk hari ini'
      : myRow.clock_out
        ? `Selesai — masuk ${fmtTime(myRow.clock_in)}, keluar ${fmtTime(myRow.clock_out)}`
        : `Absen masuk pukul ${fmtTime(myRow.clock_in)}${myRow.est_clock_out ? ` — keluar otomatis ~${myRow.est_clock_out}` : ''}`

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      {/* CLOCK IN/OUT CARD */}
      <div className="bg-char rounded-2xl p-7 md:p-8 grid md:grid-cols-[1fr_auto] gap-6 items-center">
        <div>
          <p className="text-ember font-bold text-xs mb-2">Absensi Kamu</p>
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-full bg-chili/20 grid place-items-center ring-2 ring-chili text-cream font-display text-xl">
              {(user?.name || '?').slice(0, 1)}
            </div>
            <div>
              <p className="font-display text-xl text-cream uppercase leading-none">{user?.name}</p>
              <p className="text-cream/50 text-sm mt-1.5">{statusText}</p>
            </div>
          </div>
        </div>
        <button
          onClick={() => clock(myRow?.clock_in ? 'clock-out' : 'clock-in')}
          disabled={!myEmployee || busy || (myRow?.clock_in && myRow?.clock_out)}
          className={`clock-btn w-full md:w-auto font-bold text-white px-10 py-5 rounded-2xl text-lg flex items-center justify-center gap-3 disabled:opacity-40 disabled:cursor-not-allowed ${
            myRow?.clock_in ? 'bg-char-soft hover:bg-char-line border border-cream/20' : 'bg-chili hover:bg-chili-dark'
          }`}
        >
          <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          {myRow?.clock_in ? 'Clock Out' : 'Clock In'}
        </button>
      </div>

      {/* REKAP ABSENSI — pribadi (kasir/karyawan), semua karyawan (owner/admin) */}
      <RekapAbsensi personal={!isBoss} />

      {isBoss && (
        <>
          {/* SUMMARY STRIP */}
          <div className="grid sm:grid-cols-3 gap-5">
            {summary.map((s) => (
              <div key={s.label} className="bg-white rounded-2xl p-6 border border-black/5 shadow-sm flex items-center gap-4">
                <span className={`w-11 h-11 rounded-xl ${s.iconCls} grid place-items-center shrink-0`}>
                  <svg className={`w-5 h-5 ${s.color}`} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d={s.icon} /></svg>
                </span>
                <div>
                  <p className="text-2xl font-display">{s.value}</p>
                  <p className="text-xs text-char/50">{s.label}</p>
                </div>
              </div>
            ))}
          </div>

          {/* SETTING JADWAL KERJA — Super Admin only */}
          {isOwner && (
            <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
              <div className="bg-gradient-to-r from-char to-char-soft px-6 py-5 flex items-start gap-4">
                <span className="w-11 h-11 rounded-xl bg-chili/20 grid place-items-center shrink-0 ring-1 ring-chili/40">
                  <svg className="w-5 h-5 text-ember" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                </span>
                <div>
                  <h2 className="font-bold text-cream">Pengaturan Jadwal Kerja</h2>
                  <p className="text-xs text-cream/50 mt-1">
                    Atur jam masuk (format 24 jam) &amp; durasi kerja tiap karyawan. Absen keluar tercatat otomatis saat durasi kerja terlewati.
                  </p>
                </div>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm min-w-[720px]">
                  <thead>
                    <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                      <th className="px-6 py-3 font-bold">Karyawan</th>
                      <th className="px-4 py-3 font-bold">Posisi</th>
                      <th className="px-4 py-3 font-bold w-40">Jam Masuk</th>
                      <th className="px-4 py-3 font-bold w-40">Durasi Kerja</th>
                      <th className="px-4 py-3 font-bold">Estimasi Keluar</th>
                      <th className="px-6 py-3 font-bold text-right w-28">Aksi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-black/5">
                    {schedule.length === 0 && (
                      <tr><td colSpan={6} className="px-6 py-8 text-center text-char/40">Belum ada data karyawan.</td></tr>
                    )}
                    {schedule.map((s) => (
                      <tr key={s.id} className="hover:bg-cream/60 transition-colors">
                        <td className="px-6 py-3">
                          <div className="flex items-center gap-3">
                            <span className="w-9 h-9 rounded-full bg-cream grid place-items-center font-display text-sm shrink-0">{s.name.slice(0, 1)}</span>
                            <span className="font-semibold">{s.name}</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-char/60">{s.role || '—'}</td>
                        <td className="px-4 py-3">
                          <button
                            onClick={() => setDialFor({ id: s.id, name: s.name, shift_start: s.shift_start })}
                            className="inline-flex items-center gap-2.5 bg-cream/60 hover:bg-cream border border-black/10 rounded-xl px-4 py-2 transition-colors"
                          >
                            <svg className="w-4 h-4 text-chili" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            <span className="font-display text-lg tabular-nums">{s.shift_start || '--:--'}</span>
                          </button>
                        </td>
                        <td className="px-4 py-3">
                          <div className="inline-flex items-center gap-2">
                            <input type="number" min="1" max="24" step="0.5" value={s.work_hours} onChange={(e) => editSchedule(s.id, 'work_hours', e.target.value)} className={`${inputCls} w-20 text-center font-display text-lg`} />
                            <span className="text-xs text-char/40 font-bold">jam</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 whitespace-nowrap">
                          {s.shift_start ? (
                            <span className="inline-flex items-center gap-2 bg-ember/10 text-ember font-bold text-sm px-3 py-1.5 rounded-full">
                              <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1" /></svg>
                              {addHours(s.shift_start, s.work_hours)}
                              <span className="text-[10px] font-bold opacity-60">AUTO</span>
                            </span>
                          ) : <span className="text-char/40">—</span>}
                        </td>
                        <td className="px-6 py-3 text-right">
                          <button
                            onClick={() => saveSchedule(s)}
                            disabled={!s.dirty || savingId === s.id}
                            className="text-xs font-bold text-white bg-char hover:bg-char-soft disabled:opacity-30 disabled:cursor-not-allowed px-4 py-2 rounded-full"
                          >
                            {savingId === s.id ? 'Menyimpan...' : 'Simpan'}
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* EMPLOYEE TABLE */}
          <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
            <div className="flex flex-wrap items-center justify-between gap-3 px-6 py-5 border-b border-black/5">
              <h2 className="font-bold">Daftar Karyawan</h2>
              <div className="flex items-center gap-3">
                <input
                  type="date"
                  value={date}
                  onChange={(e) => setDate(e.target.value)}
                  className="border border-black/15 rounded-full px-4 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-chili/30"
                />
                <span className="text-xs text-char/50">{rows.length} karyawan</span>
              </div>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm min-w-[860px]">
                <thead>
                  <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                    <th className="px-6 py-3 font-bold">Karyawan</th>
                    <th className="px-6 py-3 font-bold">Posisi</th>
                    <th className="px-6 py-3 font-bold">Jadwal</th>
                    <th className="px-6 py-3 font-bold">Jam Masuk</th>
                    <th className="px-6 py-3 font-bold">Jam Keluar</th>
                    <th className="px-6 py-3 font-bold">Status</th>
                    <th className="px-6 py-3 font-bold text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-black/5">
                  {rows.length === 0 && (
                    <tr><td colSpan={7} className="px-6 py-8 text-center text-char/40">Belum ada data karyawan.</td></tr>
                  )}
                  {rows.map((r) => (
                    <tr key={r.employee_id} className="hover:bg-cream/60 transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <span className="w-9 h-9 rounded-full bg-cream grid place-items-center font-display text-sm shrink-0">{r.name.slice(0, 1)}</span>
                          <span className="font-semibold">{r.name}</span>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-char/60">{r.posisi || '—'}</td>
                      <td className="px-6 py-4 text-char/60 whitespace-nowrap">
                        {r.shift_start ? `${r.shift_start} · ${r.work_hours} jam` : <span className="text-char/30">belum diatur</span>}
                      </td>
                      <td className={`px-6 py-4 ${r.clock_in ? '' : 'text-char/40'}`}>{fmtTime(r.clock_in)}</td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        {r.clock_out ? (
                          <span>{fmtTime(r.clock_out)}{r.note?.includes('auto clock-out') && <span className="text-xs text-char/40"> (auto)</span>}</span>
                        ) : r.est_clock_out && r.clock_in ? (
                          <span className="text-char/40">{r.est_clock_out} <span className="text-xs">(estimasi)</span></span>
                        ) : (
                          <span className="text-char/40">—</span>
                        )}
                      </td>
                      <td className="px-6 py-4">
                        {r.status ? (
                          <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${statusCls[r.status]}`}>{statusLabel[r.status]}</span>
                        ) : (
                          <span className="text-xs text-char/30">belum absen</span>
                        )}
                      </td>
                      <td className="px-6 py-4 text-right">
                        {isOwner ? (
                          <button onClick={() => setStatusForm({ employee_id: r.employee_id, name: r.name, status: 'izin', note: '' })} className="text-xs font-bold text-char/70 hover:text-chili underline">
                            Set Izin/Sakit
                          </button>
                        ) : <span className="text-xs text-char/30">—</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}

      {/* POPUP CLOCK DIAL (owner, atur jam masuk) */}
      {dialFor && (
        <ClockDial
          name={dialFor.name}
          value={dialFor.shift_start}
          onClose={() => setDialFor(null)}
          onChange={(v) => editSchedule(dialFor.id, 'shift_start', v)}
        />
      )}

      {/* MODAL SET STATUS */}
      {statusForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setStatusForm(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">Set Absensi</h2>
            <p className="text-char/50 text-sm mb-6">{statusForm.name} — {date}</p>
            <label className="block text-sm font-bold mb-1.5">Status</label>
            <select value={statusForm.status} onChange={(e) => setStatusForm({ ...statusForm, status: e.target.value })} className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-4">
              <option value="izin">Izin</option>
              <option value="sakit">Sakit</option>
              <option value="alpa">Tanpa Keterangan</option>
              <option value="hadir">Hadir (manual)</option>
            </select>
            <label className="block text-sm font-bold mb-1.5">Catatan <span className="font-normal text-char/40">(opsional)</span></label>
            <input
              type="text"
              value={statusForm.note}
              onChange={(e) => setStatusForm({ ...statusForm, note: e.target.value })}
              className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-6"
              placeholder="mis. Acara keluarga"
            />
            <div className="flex gap-3">
              <button onClick={() => setStatusForm(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={saveStatus} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Simpan</button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
