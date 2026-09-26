import { useCallback, useEffect, useState } from 'react'
import { api } from '../../api'

const inputCls = 'w-full bg-white border border-black/15 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30 focus:border-chili'

const num = (v) => (v === '' || v === null ? null : Number(v))

// Ambil lat/lng dari URL Google Maps yang di-paste. Mendukung beberapa format:
//   https://maps.google.com/@-6.123,106.456,17z
//   .../@lat,lng  |  ...?q=lat,lng  |  ...?query=lat,lng
//   .../place/.../!3d-6.123!4d106.456...
export function parseMapsUrl(text) {
  if (!text) return null
  const s = String(text).trim()
  // Format !3dlat!4dlng (place URL)
  const m34 = s.match(/!3d(-?\d+(?:\.\d+))!4d(-?\d+(?:\.\d+))/)
  if (m34) return { lat: m34[1], lng: m34[2] }
  // Parameter q= / query= / destination=
  const mq = s.match(/[?&](?:q|query|destination)=(-?\d+(?:\.\d+))\s*,\s*(-?\d+(?:\.\d+))/)
  if (mq) return { lat: mq[1], lng: mq[2] }
  // Pola @lat,lng (umum di URL share desktop)
  const mAt = s.match(/@(-?\d+(?:\.\d+))\s*,\s*(-?\d+(?:\.\d+))/)
  if (mAt) return { lat: mAt[1], lng: mAt[2] }
  // Dua angka desimal berurutan (mis. paste "lat, lng" langsung)
  const m2 = s.match(/^(-?\d{1,3}(?:\.\d+))\s*,\s*(-?\d{1,3}(?:\.\d+))$/)
  if (m2) return { lat: m2[1], lng: m2[2] }
  return null
}

const blankForm = { name: '', address: '', lat: '', lng: '', radius_m: 100 }

/* ============ KELOLA LOKASI CABANG — Super Admin only ============
   Titik absen per cabang (bujur/lintang dari Google Maps) + radius.
   Karyawan hanya bisa absen bila GPS-nya berada dalam radius cabangnya. */
export default function CabangManager() {
  const [list, setList] = useState([])
  const [form, setForm] = useState(blankForm)
  const [editId, setEditId] = useState(null)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [busy, setBusy] = useState(false)
  const [geoBusy, setGeoBusy] = useState(false)
  const [linkInput, setLinkInput] = useState('')

  const load = useCallback(() => {
    api.get('/branches').then(setList).catch((e) => setError(e.message))
  }, [])
  useEffect(load, [load])

  const setField = (f, v) => setForm((p) => ({ ...p, [f]: v }))

  const startEdit = (b) => {
    setEditId(b.id)
    setForm({ name: b.name, address: b.address || '', lat: String(b.lat), lng: String(b.lng), radius_m: b.radius_m })
    setNotice(''); setError('')
  }

  const resetForm = () => {
    setEditId(null); setForm(blankForm); setError(''); setNotice(''); setLinkInput('')
  }

  const useMapsLink = (text) => {
    const parsed = parseMapsUrl(text)
    if (parsed) {
      setForm((p) => ({ ...p, lat: parsed.lat, lng: parsed.lng }))
      setError(''); setNotice('Koordinat berhasil diambil dari link Google Maps.')
    } else {
      setNotice(''); setError('Link tidak dikenali. Buka Google Maps → klik kanan titik lokasi → Copy lat/lng, lalu paste di sini.')
    }
  }

  const useMyLocation = () => {
    if (!navigator.geolocation) return setError('Browser tidak mendukung geolocation.')
    setGeoBusy(true); setError('')
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setForm((p) => ({ ...p, lat: pos.coords.latitude.toFixed(7), lng: pos.coords.longitude.toFixed(7) }))
        setGeoBusy(false)
        setNotice('Koordinat diambil dari lokasi perangkat ini.')
      },
      () => { setGeoBusy(false); setError('Gagal mengambil lokasi — izinkan akses lokasi di browser.') },
      { enableHighAccuracy: true, timeout: 10_000 }
    )
  }

  const submit = async (e) => {
    e.preventDefault()
    if (!form.name.trim()) return setError('Nama cabang wajib diisi')
    setBusy(true); setError(''); setNotice('')
    try {
      const payload = {
        name: form.name.trim(),
        address: form.address.trim() || null,
        lat: num(form.lat),
        lng: num(form.lng),
        radius_m: num(form.radius_m) ?? 100,
      }
      if (editId) await api.patch(`/branches/${editId}`, payload)
      else await api.post('/branches', payload)
      resetForm()
      setNotice(editId ? 'Cabang diperbarui.' : 'Cabang ditambahkan.')
      load()
    } catch (err) { setError(err.message) }
    finally { setBusy(false) }
  }

  const deactivate = async (b) => {
    if (!window.confirm(`Nonaktifkan cabang "${b.name}"? Karyawan yang masih ditugaskan ke sini tidak akan bisa absen sampai dipindahkan.`)) return
    try { await api.del(`/branches/${b.id}`); load() } catch (e) { setError(e.message) }
  }

  const mapsLink = (b) => `https://www.google.com/maps/search/?api=1&query=${b.lat},${b.lng}`

  return (
    <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
      <div className="bg-gradient-to-r from-char to-char-soft px-6 py-5 flex items-start gap-4">
        <span className="w-11 h-11 rounded-xl bg-chili/20 grid place-items-center shrink-0 ring-1 ring-chili/40">
          <svg className="w-5 h-5 text-ember" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M17.657 16.657L13.414 20.9a1.99 1.99 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
        </span>
        <div>
          <h2 className="font-bold text-cream">Lokasi Absen per Cabang</h2>
          <p className="text-xs text-cream/50 mt-1">
            Tetapkan titik koordinat tiap cabang (ambil dari Google Maps). Karyawan hanya bisa absen bila berada dalam radius titik cabangnya.
          </p>
        </div>
      </div>

      <div className="p-6 space-y-5">
        {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}
        {notice && <p className="text-xs font-bold text-green-700 bg-green-50 rounded-xl px-4 py-3">{notice}</p>}

        {/* FORM TAMBAH / EDIT */}
        <form onSubmit={submit} className="bg-cream/60 rounded-2xl p-5 space-y-4">
          <p className="font-bold text-sm">{editId ? `Edit Cabang: ${form.name}` : 'Tambah Cabang Baru'}</p>
          <div className="grid sm:grid-cols-2 gap-4">
            <label className="block">
              <span className="block text-xs font-bold text-char/60 mb-1.5">Nama Cabang *</span>
              <input className={inputCls} value={form.name} onChange={(e) => setField('name', e.target.value)} placeholder="mis. Cabang Cibaduyut" />
            </label>
            <label className="block">
              <span className="block text-xs font-bold text-char/60 mb-1.5">Alamat <span className="font-normal text-char/40">(opsional)</span></span>
              <input className={inputCls} value={form.address} onChange={(e) => setField('address', e.target.value)} placeholder="mis. Jl. Raya No. 12" />
            </label>
          </div>
          <label className="block">
            <span className="block text-xs font-bold text-char/60 mb-1.5">Link Google Maps</span>
            <span className="flex flex-wrap gap-2">
              <input
                className={inputCls + ' flex-1 min-w-[220px]'}
                value={linkInput}
                onChange={(e) => setLinkInput(e.target.value)}
                placeholder="Paste link Google Maps atau 'lat, lng'"
              />
              <button type="button" onClick={() => useMapsLink(linkInput)} className="bg-char hover:bg-char-soft text-white font-bold text-xs px-4 rounded-xl">Ambil</button>
              <button type="button" onClick={useMyLocation} className="border border-black/15 text-char/70 hover:text-chili font-bold text-xs px-4 rounded-xl">
                {geoBusy ? 'Mengambil...' : 'Lokasi saya'}
              </button>
            </span>
            <span className="block text-[11px] text-char/40 mt-1.5">Klik kanan titik di Google Maps → angka pertama = lintang (lat), kedua = bujur (lng)</span>
          </label>
          <div className="grid sm:grid-cols-3 gap-4">
            <label className="block">
              <span className="block text-xs font-bold text-char/60 mb-1.5">Lintang (lat) *</span>
              <input className={inputCls} value={form.lat} onChange={(e) => setField('lat', e.target.value)} placeholder="-6.9218278" required />
            </label>
            <label className="block">
              <span className="block text-xs font-bold text-char/60 mb-1.5">Bujur (lng) *</span>
              <input className={inputCls} value={form.lng} onChange={(e) => setField('lng', e.target.value)} placeholder="107.6071831" required />
            </label>
            <label className="block">
              <span className="block text-xs font-bold text-char/60 mb-1.5">Radius Absen (meter)</span>
              <input type="number" min="10" max="10000" className={inputCls} value={form.radius_m} onChange={(e) => setField('radius_m', e.target.value)} />
            </label>
          </div>
          <div className="flex gap-3 pt-1">
            {editId && (
              <button type="button" onClick={resetForm} className="border border-black/15 text-char font-bold py-2.5 px-5 rounded-full text-sm">Batal</button>
            )}
            <button type="submit" disabled={busy} className="bg-chili hover:bg-chili-dark text-white font-bold py-2.5 px-6 rounded-full text-sm disabled:opacity-40">
              {editId ? 'Simpan Perubahan' : 'Tambah Cabang'}
            </button>
          </div>
        </form>

        {/* DAFTAR CABANG */}
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[720px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-3 py-3 font-bold">Cabang</th>
                <th className="px-3 py-3 font-bold">Titik (lat, lng)</th>
                <th className="px-3 py-3 font-bold text-center">Radius</th>
                <th className="px-3 py-3 font-bold text-center">Karyawan</th>
                <th className="px-3 py-3 font-bold">Status</th>
                <th className="px-3 py-3 font-bold text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {list.length === 0 && (
                <tr><td colSpan={6} className="px-3 py-8 text-center text-char/40">Belum ada cabang. Tambahkan lokasi pertama di atas.</td></tr>
              )}
              {list.map((b) => (
                <tr key={b.id} className={`hover:bg-cream/60 transition-colors ${!b.is_active ? 'opacity-50' : ''}`}>
                  <td className="px-3 py-3">
                    <span className="font-semibold">{b.name}</span>
                    {b.address && <span className="block text-xs text-char/40">{b.address}</span>}
                  </td>
                  <td className="px-3 py-3 whitespace-nowrap text-char/60 tabular-nums text-xs">
                    {b.lat}, {b.lng}
                    <a href={mapsLink(b)} target="_blank" rel="noreferrer" className="block text-chili font-bold text-xs underline">Lihat di Maps</a>
                  </td>
                  <td className="px-3 py-3 text-center font-display">{b.radius_m} m</td>
                  <td className="px-3 py-3 text-center">{b.employee_count}</td>
                  <td className="px-3 py-3">
                    <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${b.is_active ? 'text-green-700 bg-green-50' : 'text-char/50 bg-cream'}`}>
                      {b.is_active ? 'Aktif' : 'Nonaktif'}
                    </span>
                  </td>
                  <td className="px-3 py-3 text-right whitespace-nowrap">
                    <button onClick={() => startEdit(b)} className="text-xs font-bold text-char/70 hover:text-chili underline mr-3">Edit</button>
                    {b.is_active && (
                      <button onClick={() => deactivate(b)} className="text-xs font-bold text-char/70 hover:text-chili underline">Nonaktifkan</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
