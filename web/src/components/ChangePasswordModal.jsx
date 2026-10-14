import { useState } from 'react'
import { api } from '../api'

const inputCls = 'w-full border border-black/15 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30'

// Ganti password akun yang sedang login (semua role) — POST /api/auth/change-password.
export default function ChangePasswordModal({ onClose }) {
  const [form, setForm] = useState({ old: '', next: '', confirm: '' })
  const [error, setError] = useState('')
  const [done, setDone] = useState(false)
  const [busy, setBusy] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setError('')
    if (form.next.length < 8) return setError('Password baru minimal 8 karakter')
    if (form.next !== form.confirm) return setError('Konfirmasi password tidak sama')
    setBusy(true)
    try {
      await api.post('/auth/change-password', { old_password: form.old, new_password: form.next })
      setDone(true)
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
      <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={onClose}></div>
      <form onSubmit={submit} className="relative bg-white text-char rounded-2xl w-full max-w-sm p-7">
        <h2 className="font-display text-xl uppercase mb-1">Ganti Password</h2>
        {done ? (
          <>
            <p className="text-sm text-char/60 my-6">Password berhasil diganti. Gunakan password baru saat login berikutnya.</p>
            <button type="button" onClick={onClose} className="w-full bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Selesai</button>
          </>
        ) : (
          <>
            <p className="text-char/50 text-sm mb-5">Minimal 8 karakter, jangan memakai password yang mudah ditebak.</p>
            <label className="block text-sm font-bold mb-1.5" htmlFor="pw-old">Password lama</label>
            <input id="pw-old" type="password" autoComplete="current-password" required value={form.old} onChange={(e) => setForm({ ...form, old: e.target.value })} className={`${inputCls} mb-4`} />
            <label className="block text-sm font-bold mb-1.5" htmlFor="pw-new">Password baru</label>
            <input id="pw-new" type="password" autoComplete="new-password" required minLength={8} value={form.next} onChange={(e) => setForm({ ...form, next: e.target.value })} className={`${inputCls} mb-4`} />
            <label className="block text-sm font-bold mb-1.5" htmlFor="pw-confirm">Ulangi password baru</label>
            <input id="pw-confirm" type="password" autoComplete="new-password" required value={form.confirm} onChange={(e) => setForm({ ...form, confirm: e.target.value })} className={`${inputCls} mb-4`} />
            {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3 mb-4" role="alert">{error}</p>}
            <div className="flex gap-3">
              <button type="button" onClick={onClose} className="flex-1 border border-black/15 font-bold py-3 rounded-full text-sm">Batal</button>
              <button type="submit" disabled={busy} className="flex-1 bg-chili hover:bg-chili-dark disabled:opacity-50 text-white font-bold py-3 rounded-full text-sm">{busy ? 'Menyimpan…' : 'Simpan'}</button>
            </div>
          </>
        )}
      </form>
    </div>
  )
}
