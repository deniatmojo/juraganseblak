import { useMemo, useState } from 'react'
import { addAccount, getAccounts, removeAccount } from '../../auth'

const roleLabels = { owner: 'Super Admin', karyawan: 'Karyawan' }

export default function Karyawan() {
  const [accounts, setAccounts] = useState(getAccounts)
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [position, setPosition] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const employees = useMemo(() => accounts.filter((a) => a.role === 'karyawan'), [accounts])

  const inputCls = 'w-full bg-white text-char border border-black/15 rounded-xl px-4 py-3 text-sm'

  const refresh = () => setAccounts(getAccounts())

  const handleSubmit = (e) => {
    e.preventDefault()
    setError('')
    setSuccess('')
    if (password.length < 6) {
      setError('Password minimal 6 karakter.')
      return
    }
    try {
      addAccount({ name, email, password, role: 'karyawan', position })
      refresh()
      setSuccess(`Akun ${name} berhasil dibuat. Karyawan bisa login dengan email tersebut.`)
      setName(''); setEmail(''); setPosition(''); setPassword('')
    } catch (err) {
      setError(err.message)
    }
  }

  const handleDelete = (id) => {
    if (window.confirm('Hapus akun karyawan ini?')) {
      removeAccount(id)
      refresh()
    }
  }

  return (
    <div className="space-y-8">
      <section className="bg-white border border-black/10 rounded-2xl p-6 md:p-8">
        <h2 className="font-display text-xl mb-1">Tambah Karyawan</h2>
        <p className="text-sm text-char/60 mb-6">
          Buat akun login untuk karyawan. Karyawan hanya bisa mengakses menu <strong>Absensi</strong>;
          menu lainnya khusus super admin.
        </p>

        <form onSubmit={handleSubmit} className="grid md:grid-cols-2 gap-5">
          <div>
            <label htmlFor="k-nama" className="block text-sm font-bold mb-1.5">Nama Lengkap</label>
            <input id="k-nama" required value={name} onChange={(e) => setName(e.target.value)} className={inputCls} placeholder="cth. Siti Nurhaliza" />
          </div>
          <div>
            <label htmlFor="k-email" className="block text-sm font-bold mb-1.5">Email (untuk login)</label>
            <input id="k-email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} className={inputCls} placeholder="karyawan@barapedas.id" />
          </div>
          <div>
            <label htmlFor="k-posisi" className="block text-sm font-bold mb-1.5">Posisi</label>
            <input id="k-posisi" value={position} onChange={(e) => setPosition(e.target.value)} className={inputCls} placeholder="cth. Kasir / Dapur" />
          </div>
          <div>
            <label htmlFor="k-pass" className="block text-sm font-bold mb-1.5">Password Awal</label>
            <input id="k-pass" type="password" required minLength={6} value={password} onChange={(e) => setPassword(e.target.value)} className={inputCls} placeholder="Minimal 6 karakter" />
          </div>

          {error && <p className="md:col-span-2 text-chili text-sm font-semibold" role="alert">{error}</p>}
          {success && <p className="md:col-span-2 text-green-700 text-sm font-semibold">{success}</p>}

          <div className="md:col-span-2">
            <button type="submit" className="bg-chili hover:bg-chili-dark text-white font-bold px-8 py-3.5 rounded-full transition-colors text-sm">
              Buat Akun Karyawan
            </button>
          </div>
        </form>
      </section>

      <section className="bg-white border border-black/10 rounded-2xl overflow-hidden">
        <div className="px-6 md:px-8 pt-6 pb-4">
          <h2 className="font-display text-xl">Daftar Karyawan</h2>
          <p className="text-sm text-char/60">{employees.length} akun karyawan terdaftar.</p>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-char text-cream text-left">
                <th className="px-6 py-3 font-semibold">Nama</th>
                <th className="px-6 py-3 font-semibold">Email</th>
                <th className="px-6 py-3 font-semibold">Posisi</th>
                <th className="px-6 py-3 font-semibold">Role</th>
                <th className="px-6 py-3 font-semibold text-right">Aksi</th>
              </tr>
            </thead>
            <tbody>
              {employees.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center text-char/50">Belum ada karyawan. Tambahkan lewat form di atas.</td>
                </tr>
              )}
              {employees.map((emp) => (
                <tr key={emp.id} className="border-t border-black/5">
                  <td className="px-6 py-4 font-semibold">{emp.name}</td>
                  <td className="px-6 py-4">{emp.email}</td>
                  <td className="px-6 py-4">{emp.position || '—'}</td>
                  <td className="px-6 py-4">
                    <span className="inline-block bg-ember/15 text-ember-dark text-xs font-bold px-3 py-1 rounded-full">{roleLabels[emp.role]}</span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <button onClick={() => handleDelete(emp.id)} className="text-chili hover:underline font-semibold text-xs">
                      Hapus
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  )
}
