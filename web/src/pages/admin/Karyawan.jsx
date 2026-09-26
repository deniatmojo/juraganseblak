import { useEffect, useState } from 'react'
import { api } from '../../api'

const roleLabels = { owner: 'Super Admin', admin: 'Admin', kasir: 'Karyawan Kasir', karyawan: 'Karyawan' }
const inputCls = 'w-full bg-white text-char border border-black/15 rounded-xl px-4 py-3 text-sm'

export default function Karyawan() {
  const [users, setUsers] = useState([])
  const [employees, setEmployees] = useState([])
  const [branches, setBranches] = useState([])
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  // Form akun login
  const [accForm, setAccForm] = useState({ name: '', email: '', password: '', role: 'kasir' })
  // Form karyawan
  const [empForm, setEmpForm] = useState({ name: '', role: '', phone: '', daily_rate: '', user_id: '', branch_id: '' })
  const [resetTarget, setResetTarget] = useState(null) // user yang di-reset password

  const load = () => {
    Promise.all([api.get('/users'), api.get('/employees'), api.get('/branches')])
      .then(([u, e, b]) => { setUsers(u); setEmployees(e); setBranches(b.filter((x) => x.is_active)) })
      .catch((e) => setError(e.message))
  }
  useEffect(load, [])

  const createAccount = async (e) => {
    e.preventDefault()
    setError(''); setSuccess('')
    try {
      await api.post('/users', accForm)
      setSuccess(`Akun ${accForm.name} berhasil dibuat.`)
      setAccForm({ name: '', email: '', password: '', role: 'kasir' })
      load()
    } catch (err) { setError(err.message) }
  }

  const createEmployee = async (e) => {
    e.preventDefault()
    setError(''); setSuccess('')
    try {
      await api.post('/employees', {
        ...empForm,
        daily_rate: Number(empForm.daily_rate || 0),
        user_id: empForm.user_id ? Number(empForm.user_id) : null,
        branch_id: empForm.branch_id ? Number(empForm.branch_id) : null,
      })
      setSuccess(`Karyawan ${empForm.name} berhasil ditambahkan.`)
      setEmpForm({ name: '', role: '', phone: '', daily_rate: '', user_id: '', branch_id: '' })
      load()
    } catch (err) { setError(err.message) }
  }

  const toggleUser = async (u) => {
    const action = u.is_active ? 'Nonaktifkan' : 'Aktifkan'
    if (!window.confirm(`${action} akun ${u.email}?`)) return
    try {
      await api.patch(`/users/${u.id}`, { is_active: u.is_active ? 0 : 1 })
      load()
    } catch (err) { setError(err.message) }
  }

  const doReset = async () => {
    try {
      await api.patch(`/users/${resetTarget.id}`, { password: resetTarget.password })
      setSuccess(`Password ${resetTarget.email} berhasil direset.`)
      setResetTarget(null)
    } catch (err) { setError(err.message) }
  }

  const removeEmployee = async (emp) => {
    if (!window.confirm(`Hapus data karyawan ${emp.name}?`)) return
    try {
      await api.del(`/employees/${emp.id}`)
      load()
    } catch (err) { setError(err.message) }
  }

  // Tugaskan / ubah cabang absen karyawan langsung dari tabel
  const assignBranch = async (emp, branchId) => {
    setError(''); setSuccess('')
    try {
      await api.patch(`/employees/${emp.id}`, { branch_id: branchId ? Number(branchId) : null })
      setSuccess(`${emp.name} ditugaskan ke ${branches.find((b) => String(b.id) === String(branchId))?.name || 'tanpa cabang'}.`)
      load()
    } catch (err) { setError(err.message); load() }
  }

  return (
    <div className="space-y-8">
      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}
      {success && <p className="text-xs font-bold text-green-700 bg-green-50 rounded-xl px-4 py-3">{success}</p>}

      {/* AKUN LOGIN */}
      <section className="bg-white border border-black/10 rounded-2xl p-6 md:p-8">
        <h2 className="font-display text-xl mb-1">Akun Login</h2>
        <p className="text-sm text-char/60 mb-6">
          Akun disimpan di server (password di-hash). Kasir hanya bisa mengakses menu <strong>POS &amp; Absensi</strong>.
        </p>

        <form onSubmit={createAccount} className="grid md:grid-cols-4 gap-5 mb-8">
          <div>
            <label className="block text-sm font-bold mb-1.5">Nama Lengkap</label>
            <input required value={accForm.name} onChange={(e) => setAccForm({ ...accForm, name: e.target.value })} className={inputCls} placeholder="cth. Siti Nurhaliza" />
          </div>
          <div>
            <label className="block text-sm font-bold mb-1.5">Email (login)</label>
            <input type="email" required value={accForm.email} onChange={(e) => setAccForm({ ...accForm, email: e.target.value })} className={inputCls} placeholder="nama@juraganseblak.id" />
          </div>
          <div>
            <label className="block text-sm font-bold mb-1.5">Password Awal</label>
            <input type="text" required minLength={6} value={accForm.password} onChange={(e) => setAccForm({ ...accForm, password: e.target.value })} className={inputCls} placeholder="Minimal 6 karakter" />
          </div>
          <div>
            <label className="block text-sm font-bold mb-1.5">Role</label>
            <select value={accForm.role} onChange={(e) => setAccForm({ ...accForm, role: e.target.value })} className={inputCls}>
              <option value="kasir">Karyawan Kasir</option>
              <option value="karyawan">Karyawan (Absensi saja)</option>
              <option value="admin">Admin</option>
              <option value="owner">Super Admin</option>
            </select>
          </div>
          <div className="md:col-span-4">
            <button type="submit" className="bg-chili hover:bg-chili-dark text-white font-bold px-8 py-3.5 rounded-full transition-colors text-sm">
              Buat Akun
            </button>
          </div>
        </form>

        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[680px]">
            <thead>
              <tr className="bg-char text-cream text-left">
                <th className="px-6 py-3 font-semibold">Nama</th>
                <th className="px-6 py-3 font-semibold">Email</th>
                <th className="px-6 py-3 font-semibold">Role</th>
                <th className="px-6 py-3 font-semibold">Status</th>
                <th className="px-6 py-3 font-semibold text-right">Aksi</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id} className="border-t border-black/5">
                  <td className="px-6 py-4 font-semibold">{u.name}</td>
                  <td className="px-6 py-4">{u.email}</td>
                  <td className="px-6 py-4">
                    <span className="inline-block bg-ember/15 text-ember-dark text-xs font-bold px-3 py-1 rounded-full">{roleLabels[u.role] || u.role}</span>
                  </td>
                  <td className="px-6 py-4">
                    {u.is_active ? (
                      <span className="text-xs font-bold text-green-700 bg-green-50 px-2.5 py-1 rounded-full">Aktif</span>
                    ) : (
                      <span className="text-xs font-bold text-char/50 bg-cream px-2.5 py-1 rounded-full">Nonaktif</span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-right space-x-3 whitespace-nowrap">
                    <button onClick={() => setResetTarget({ ...u, password: '' })} className="text-char/70 hover:text-char font-semibold text-xs">Reset Password</button>
                    <button onClick={() => toggleUser(u)} className="text-chili hover:underline font-semibold text-xs">
                      {u.is_active ? 'Nonaktifkan' : 'Aktifkan'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* DATA KARYAWAN */}
      <section className="bg-white border border-black/10 rounded-2xl p-6 md:p-8">
        <h2 className="font-display text-xl mb-1">Data Karyawan</h2>
        <p className="text-sm text-char/60 mb-6">
          Data untuk absensi &amp; payroll. Hubungkan ke akun login supaya karyawan bisa clock in/out sendiri.
        </p>

        <form onSubmit={createEmployee} className="grid md:grid-cols-5 gap-5 mb-8">
          <div>
            <label className="block text-sm font-bold mb-1.5">Nama</label>
            <input required value={empForm.name} onChange={(e) => setEmpForm({ ...empForm, name: e.target.value })} className={inputCls} />
          </div>
          <div>
            <label className="block text-sm font-bold mb-1.5">Posisi</label>
            <input value={empForm.role} onChange={(e) => setEmpForm({ ...empForm, role: e.target.value })} className={inputCls} placeholder="Kasir / Koki / Pelayan" />
          </div>
          <div>
            <label className="block text-sm font-bold mb-1.5">Tarif Harian (Rp)</label>
            <input type="number" min="0" value={empForm.daily_rate} onChange={(e) => setEmpForm({ ...empForm, daily_rate: e.target.value })} className={inputCls} placeholder="70000" />
          </div>
          <div>
            <label className="block text-sm font-bold mb-1.5">No. HP</label>
            <input value={empForm.phone} onChange={(e) => setEmpForm({ ...empForm, phone: e.target.value })} className={inputCls} placeholder="opsional" />
          </div>
          <div>
            <label className="block text-sm font-bold mb-1.5">Akun Login</label>
            <select value={empForm.user_id} onChange={(e) => setEmpForm({ ...empForm, user_id: e.target.value })} className={inputCls}>
              <option value="">— tanpa akun —</option>
              {users
                .filter((u) => u.is_active && u.role !== 'owner' && !employees.some((e) => e.user_id === u.id))
                .map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.name} ({u.email}){u.role === 'admin' ? ' — Admin' : ''}
                  </option>
                ))}
            </select>
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-bold mb-1.5">Cabang (Lokasi Absen)</label>
            <select value={empForm.branch_id} onChange={(e) => setEmpForm({ ...empForm, branch_id: e.target.value })} className={inputCls}>
              <option value="">— belum ditugaskan —</option>
              {branches.map((b) => (
                <option key={b.id} value={b.id}>{b.name} (radius {b.radius_m} m)</option>
              ))}
            </select>
          </div>
          <div className="md:col-span-5">
            <button type="submit" className="bg-char hover:bg-char-soft text-white font-bold px-8 py-3.5 rounded-full transition-colors text-sm">
              Tambah Karyawan
            </button>
          </div>
        </form>

        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[720px]">
            <thead>
              <tr className="bg-char text-cream text-left">
                <th className="px-6 py-3 font-semibold">Nama</th>
                <th className="px-6 py-3 font-semibold">Posisi</th>
                <th className="px-6 py-3 font-semibold">Tarif Harian</th>
                <th className="px-6 py-3 font-semibold">Kasbon Belum Lunas</th>
                <th className="px-6 py-3 font-semibold">Cabang</th>
                <th className="px-6 py-3 font-semibold">Akun Login</th>
                <th className="px-6 py-3 font-semibold text-right">Aksi</th>
              </tr>
            </thead>
            <tbody>
              {employees.length === 0 && (
                <tr><td colSpan={7} className="px-6 py-8 text-center text-char/50">Belum ada karyawan.</td></tr>
              )}
              {employees.map((emp) => (
                <tr key={emp.id} className="border-t border-black/5">
                  <td className="px-6 py-4 font-semibold">{emp.name}</td>
                  <td className="px-6 py-4">{emp.role || '—'}</td>
                  <td className="px-6 py-4">{emp.daily_rate ? 'Rp ' + emp.daily_rate.toLocaleString('id-ID') : '—'}</td>
                  <td className="px-6 py-4">
                    {emp.kasbon_open > 0 ? (
                      <span className="text-xs font-bold text-chili bg-red-50 px-2.5 py-1 rounded-full">Rp {emp.kasbon_open.toLocaleString('id-ID')}</span>
                    ) : '—'}
                  </td>
                  <td className="px-6 py-4">
                    <select
                      value={emp.branch_id ?? ''}
                      onChange={(e) => assignBranch(emp, e.target.value)}
                      className="bg-cream/60 border border-black/10 rounded-lg px-2 py-1.5 text-xs font-semibold max-w-[160px]"
                    >
                      <option value="">— belum ditugaskan —</option>
                      {branches.map((b) => (
                        <option key={b.id} value={b.id}>{b.name}</option>
                      ))}
                    </select>
                  </td>
                  <td className="px-6 py-4 text-char/60">{emp.account_email || <span className="text-char/30">belum terhubung</span>}</td>
                  <td className="px-6 py-4 text-right">
                    <button onClick={() => removeEmployee(emp)} className="text-chili hover:underline font-semibold text-xs">Hapus</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* MODAL RESET PASSWORD */}
      {resetTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setResetTarget(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">Reset Password</h2>
            <p className="text-char/50 text-sm mb-6">{resetTarget.email}</p>
            <label className="block text-sm font-bold mb-1.5">Password Baru</label>
            <input
              type="text"
              minLength={6}
              value={resetTarget.password}
              onChange={(e) => setResetTarget({ ...resetTarget, password: e.target.value })}
              className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-6 focus:outline-none focus:ring-2 focus:ring-chili/30"
              placeholder="Minimal 6 karakter"
            />
            <div className="flex gap-3">
              <button onClick={() => setResetTarget(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={doReset} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Reset</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
