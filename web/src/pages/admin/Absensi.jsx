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

const statusCls = {
  hadir: 'text-green-700 bg-green-50',
  terlambat: 'text-ember bg-ember/10',
  izin: 'text-ember bg-ember/10',
  sakit: 'text-ember bg-ember/10',
  alpa: 'text-chili bg-red-50',
}
const statusLabel = { hadir: 'Hadir', terlambat: 'Terlambat', izin: 'Izin', sakit: 'Sakit', alpa: 'Tanpa Keterangan' }

const inputCls = 'w-full bg-white border border-black/15 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30 focus:border-chili'

export default function Absensi() {
  const { user } = useOutletContext()
  const isOwner = user?.role === 'owner'

  const [rows, setRows] = useState([])
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10))
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [statusForm, setStatusForm] = useState(null) // { employee_id, name, status, note }
  const [schedule, setSchedule] = useState([])       // setting jadwal (owner)
  const [savingId, setSavingId] = useState(null)

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

  // Setting jadwal: ubah jam masuk / durasi kerja satu karyawan
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
  const alpa = rows.filter((r) => r.status === 'alpa' || (!r.status && date < new Date().toISOString().slice(0, 10))).length

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

      {isOwner && (
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

          {/* SETTING JADWAL KERJA — owner only */}
          <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
            <div className="px-6 py-5 border-b border-black/5">
              <h2 className="font-bold">Pengaturan Jadwal Kerja</h2>
              <p className="text-xs text-char/50 mt-1">
                Atur jam masuk & durasi kerja tiap karyawan. Absen keluar tercatat otomatis saat durasi kerja terlewati.
              </p>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm min-w-[720px]">
                <thead>
                  <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                    <th className="px-6 py-3 font-bold">Karyawan</th>
                    <th className="px-4 py-3 font-bold">Posisi</th>
                    <th className="px-4 py-3 font-bold w-36">Jam Masuk</th>
                    <th className="px-4 py-3 font-bold w-36">Durasi Kerja (jam)</th>
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
                        <input type="time" value={s.shift_start || ''} onChange={(e) => editSchedule(s.id, 'shift_start', e.target.value)} className={inputCls} />
                      </td>
                      <td className="px-4 py-3">
                        <input type="number" min="1" max="24" step="0.5" value={s.work_hours} onChange={(e) => editSchedule(s.id, 'work_hours', e.target.value)} className={inputCls} />
                      </td>
                      <td className="px-4 py-3 font-semibold text-char/70">
                        {s.shift_start ? `${addHours(s.shift_start, s.work_hours)} (auto)` : '—'}
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
                        <button onClick={() => setStatusForm({ employee_id: r.employee_id, name: r.name, status: 'izin', note: '' })} className="text-xs font-bold text-char/70 hover:text-chili underline">
                          Set Izin/Sakit
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
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
