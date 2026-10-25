import { useEffect, useState } from 'react'
import { api, getToken } from '../../api'

// Halaman Pengaturan Pembayaran: QRIS statis (gambar dari bank/e-wallet) dan
// konfigurasi payment gateway (API keys). Setelah terisi, POS langsung memakai
// konfigurasi ini tanpa perubahan kode lagi.

const GATEWAYS = [
  { key: 'none', label: 'Belum pakai gateway (QRIS statis saja)' },
  { key: 'tripay', label: 'Tripay — QRIS dinamis' },
  { key: 'duitku', label: 'Duitku — QRIS dinamis' },
  { key: 'midtrans', label: 'Midtrans (GoPay/QRIS) — QRIS dinamis' },
]

const FIELDS = [
  { key: 'gateway_merchant_id', label: 'Merchant ID / Merchant Code', secret: false },
  { key: 'gateway_api_key', label: 'API Key / Server Key', secret: true },
  { key: 'gateway_private_key', label: 'Private Key (Tripay & Duitku)', secret: true },
  { key: 'gateway_callback_url', label: 'URL Publik Server (mis. https://pos.example.com)', secret: false },
]

const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

export default function Pembayaran() {
  const [form, setForm] = useState({})
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [uploading, setUploading] = useState('')   // kunci setting QRIS yang sedang diunggah
  const [branches, setBranches] = useState([])
  const [msg, setMsg] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    api.get('/settings')
      .then((s) => setForm(s))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    api.get('/branch-options').then(setBranches).catch(() => {})
  }, [])

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }))

  // Biaya & pembulatan disimpan sebagai pecahan (5% -> 0.05) dan langkah pembulatan (Rp).
  const pct = (key) => (form[key] === undefined || form[key] === null || form[key] === '' ? '' : String(Number((Number(form[key]) * 100).toFixed(3))))
  const setPct = (key, value) => set(key, value === '' ? '' : String(Number(value) / 100))
  const feeSample = 20000
  const sTax = Math.round(feeSample * (Number(form.tax_rate) || 0))
  const sService = Math.round(feeSample * (Number(form.service_rate) || 0))
  const sRaw = feeSample + sTax + sService
  const sStep = Number(form.rounding_step) || 0
  const sTotal = sStep > 0 ? Math.round(sRaw / sStep) * sStep : sRaw

  const uploadQris = async (file, key) => {
    if (!file) return
    setUploading(key)
    try {
      const fd = new FormData()
      fd.append('photo', file)
      const res = await fetch('/api/upload', {
        method: 'POST',
        headers: { Authorization: `Bearer ${getToken()}` },
        body: fd,
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Upload gagal')
      set(key, data.url)
    } catch (e) {
      setError(e.message)
    } finally {
      setUploading('')
    }
  }

  const save = async () => {
    setSaving(true)
    setMsg('')
    setError('')
    try {
      const payload = {}
      for (const k of Object.keys(form).filter((x) => /^qris_static_(image|merchant)_b\d+$/.test(x))) {
        if (form[k] !== undefined && form[k] !== null) payload[k] = form[k]
      }
      for (const k of ['tax_rate', 'service_rate', 'rounding_step', 'qris_static_image', 'qris_static_merchant', 'payment_gateway', 'gateway_mode', 'gateway_merchant_id', 'gateway_api_key', 'gateway_private_key', 'gateway_callback_url']) {
        if (form[k] !== undefined && form[k] !== null) payload[k] = form[k]
      }
      await api.patch('/settings', payload)
      setMsg('Pengaturan pembayaran tersimpan.')
    } catch (e) {
      setError(e.message)
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <main className="flex-1 p-6"><p className="text-sm text-char/50">Memuat...</p></main>

  return (
    <main className="flex-1 overflow-y-auto p-5 md:p-6">
      <div className="max-w-2xl space-y-6">
        {/* BIAYA LAYANAN & PEMBULATAN */}
        <section className="bg-white rounded-2xl border border-black/10 p-6">
          <h2 className="font-bold">Biaya Layanan &amp; Pembulatan</h2>
          <p className="text-xs text-char/50 mt-1 mb-4">
            Biaya layanan (service charge) dan pajak dihitung sebagai persen dari total pembelian (subtotal), berlaku di POS maupun pesanan online.
          </p>
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div>
              <label className="block text-xs font-bold text-char/60 mb-1.5">Biaya Layanan (%)</label>
              <input
                type="number" min="0" max="100" step="0.1"
                value={pct('service_rate')}
                onChange={(e) => setPct('service_rate', e.target.value)}
                placeholder="mis. 5"
                className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30"
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-char/60 mb-1.5">Pajak (%)</label>
              <input
                type="number" min="0" max="100" step="0.1"
                value={pct('tax_rate')}
                onChange={(e) => setPct('tax_rate', e.target.value)}
                placeholder="mis. 10"
                className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30"
              />
            </div>
          </div>
          <label className="flex items-start gap-3 bg-cream/70 rounded-xl px-4 py-3 cursor-pointer">
            <input
              type="checkbox"
              checked={sStep > 0}
              onChange={(e) => set('rounding_step', e.target.checked ? '1000' : '0')}
              className="mt-0.5 w-4 h-4 accent-chili"
            />
            <span className="text-sm">
              <span className="font-bold">Bulatkan total per Rp1.000 (500 ke atas naik, di bawah 500 turun)</span>
              <span className="block text-xs text-char/50 mt-0.5">Contoh: total Rp4.200 menjadi Rp5.000. Selisihnya tampil sebagai baris &ldquo;Pembulatan&rdquo; di struk dan tercatat sebagai pendapatan.</span>
            </span>
          </label>
          <p className="text-xs text-char/50 mt-3">
            Simulasi pembelian {formatRp(feeSample)}: layanan {formatRp(sService)} + pajak {formatRp(sTax)}
            {sTotal > sRaw ? ` + pembulatan ${formatRp(sTotal - sRaw)}` : ''} = <strong className="text-char">{formatRp(sTotal)}</strong>
          </p>
        </section>

        {/* QRIS STATIS — satu per cabang */}
        <section className="bg-white rounded-2xl border border-black/10 p-6">
          <h2 className="font-bold">QRIS Statis per Cabang</h2>
          <p className="text-xs text-char/50 mt-1 mb-4">
            Tiap cabang punya QRIS statis sendiri (dari bank / e-wallet merchant cabang tersebut). Kasir menampilkan QRIS cabang
            shift yang sedang dibuka; pelanggan online melihat QRIS cabang tempat pesanannya. Konfirmasi manual setelah pembayaran diterima.
          </p>
          <div className="space-y-6">
            {branches.map((b) => {
              const imgKey = `qris_static_image_b${b.id}`
              const merKey = `qris_static_merchant_b${b.id}`
              return (
                <div key={b.id} className="border border-black/10 rounded-xl p-4">
                  <h3 className="font-bold text-sm mb-3">{b.name}</h3>
                  <div className="flex items-start gap-5">
                    {form[imgKey] ? (
                      <img src={form[imgKey]} alt={`QRIS ${b.name}`} className="w-36 h-36 object-contain rounded-xl border border-black/10 bg-white" />
                    ) : (
                      <div className="w-36 h-36 rounded-xl border-2 border-dashed border-black/15 grid place-items-center text-xs text-char/40 text-center p-3">
                        {form.qris_static_image ? 'Memakai QRIS umum' : 'Belum ada gambar QRIS'}
                      </div>
                    )}
                    <div className="flex-1 space-y-3">
                      <input
                        type="file"
                        accept="image/jpeg,image/png,image/webp,image/gif"
                        onChange={(e) => uploadQris(e.target.files?.[0], imgKey)}
                        className="text-xs border border-black/15 rounded-xl px-4 py-2.5 bg-white w-full file:mr-3 file:py-1.5 file:px-4 file:rounded-full file:border-0 file:bg-char file:text-white file:text-xs file:font-bold"
                      />
                      {uploading === imgKey && <p className="text-xs text-char/50">Mengunggah...</p>}
                      <label className="block text-xs font-bold text-char/60">Nama Merchant (opsional, tampil di modal QR)</label>
                      <input
                        type="text"
                        value={form[merKey] || ''}
                        onChange={(e) => set(merKey, e.target.value)}
                        placeholder="mis. JURAGAN SEBLAK CABANG 1 - NMID ID1234"
                        className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30"
                      />
                    </div>
                  </div>
                </div>
              )
            })}
            {/* QRIS umum lama — tetap dipakai cabang yang belum punya QRIS sendiri */}
            {form.qris_static_image && (
              <div className="border border-dashed border-black/15 rounded-xl p-4">
                <h3 className="font-bold text-sm mb-1">QRIS Umum (cadangan)</h3>
                <p className="text-xs text-char/50 mb-3">Dipakai cabang yang belum diunggah QRIS-nya sendiri.</p>
                <div className="flex items-start gap-5">
                  <img src={form.qris_static_image} alt="QRIS umum" className="w-24 h-24 object-contain rounded-xl border border-black/10 bg-white" />
                  <div className="flex-1 space-y-3">
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp,image/gif"
                      onChange={(e) => uploadQris(e.target.files?.[0], 'qris_static_image')}
                      className="text-xs border border-black/15 rounded-xl px-4 py-2.5 bg-white w-full file:mr-3 file:py-1.5 file:px-4 file:rounded-full file:border-0 file:bg-char file:text-white file:text-xs file:font-bold"
                    />
                    {uploading === 'qris_static_image' && <p className="text-xs text-char/50">Mengunggah...</p>}
                  </div>
                </div>
              </div>
            )}
          </div>
        </section>

        {/* GATEWAY */}
        <section className="bg-white rounded-2xl border border-black/10 p-6">
          <h2 className="font-bold">Payment Gateway (QRIS Dinamis)</h2>
          <p className="text-xs text-char/50 mt-1 mb-4">
            Opsional. Aktif hanya bila gateway dipilih <em>dan</em> API keys terisi — POS otomatis menampilkan QR dinamis
            per transaksi dan melunaskan pesanan lewat webhook. Gunakan provider yang terdaftar sebagai PJSP berizin Bank Indonesia.
          </p>

          <label className="block text-xs font-bold text-char/60 mb-1.5">Provider</label>
          <select
            value={form.payment_gateway || 'none'}
            onChange={(e) => set('payment_gateway', e.target.value)}
            className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm mb-4 bg-white focus:outline-none focus:ring-2 focus:ring-chili/30"
          >
            {GATEWAYS.map((g) => <option key={g.key} value={g.key}>{g.label}</option>)}
          </select>

          {form.payment_gateway && form.payment_gateway !== 'none' && (
            <>
              <label className="block text-xs font-bold text-char/60 mb-1.5">Mode</label>
              <select
                value={form.gateway_mode || 'sandbox'}
                onChange={(e) => set('gateway_mode', e.target.value)}
                className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm mb-4 bg-white focus:outline-none focus:ring-2 focus:ring-chili/30"
              >
                <option value="sandbox">Sandbox (uji coba)</option>
                <option value="production">Production (live)</option>
              </select>

              {FIELDS.map((f) => (
                <div key={f.key} className="mb-4">
                  <label className="block text-xs font-bold text-char/60 mb-1.5">{f.label}</label>
                  <input
                    type="text"
                    value={form[f.key] || ''}
                    onChange={(e) => set(f.key, e.target.value)}
                    className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-chili/30"
                  />
                </div>
              ))}

              <p className="text-xs text-char/50 bg-cream/70 rounded-xl px-4 py-3">
                Daftarkan webhook ke provider dengan URL:<br />
                <code className="font-mono">{(form.gateway_callback_url || 'https://domain-anda')}/api/payments/webhook/{form.payment_gateway}</code><br />
                Endpoint ini publik dan tervalidasi signature dari provider.
              </p>
            </>
          )}
        </section>

        {msg && <p className="text-xs font-bold text-green-700 bg-green-50 rounded-xl px-4 py-3">{msg}</p>}
        {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

        <button
          onClick={save}
          disabled={saving || uploading}
          className="w-full bg-chili hover:bg-chili-dark disabled:opacity-40 text-white font-bold py-3.5 rounded-full"
        >
          {saving ? 'Menyimpan...' : 'Simpan Pengaturan'}
        </button>
        <p className="text-[11px] text-char/40 text-center">API key tersimpan di database dan hanya tampil penuh untuk Super Admin.</p>
      </div>
    </main>
  )
}
