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
  const [uploading, setUploading] = useState(false)
  const [msg, setMsg] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    api.get('/settings')
      .then((s) => setForm(s))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }))

  const uploadQris = async (file) => {
    if (!file) return
    setUploading(true)
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
      set('qris_static_image', data.url)
    } catch (e) {
      setError(e.message)
    } finally {
      setUploading(false)
    }
  }

  const save = async () => {
    setSaving(true)
    setMsg('')
    setError('')
    try {
      const payload = {}
      for (const k of ['qris_static_image', 'qris_static_merchant', 'payment_gateway', 'gateway_mode', 'gateway_merchant_id', 'gateway_api_key', 'gateway_private_key', 'gateway_callback_url']) {
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
        {/* QRIS STATIS */}
        <section className="bg-white rounded-2xl border border-black/10 p-6">
          <h2 className="font-bold">QRIS Statis</h2>
          <p className="text-xs text-char/50 mt-1 mb-4">
            Gambar QRIS statis dari bank / e-wallet merchant Anda (daftar gratis di bank tempat rekening usaha).
            Kasir akan menampilkan QR ini sebelum transaksi QRIS, lalu konfirmasi manual setelah pembayaran diterima.
          </p>
          <div className="flex items-start gap-5">
            {form.qris_static_image ? (
              <img src={form.qris_static_image} alt="QRIS statis" className="w-36 h-36 object-contain rounded-xl border border-black/10 bg-white" />
            ) : (
              <div className="w-36 h-36 rounded-xl border-2 border-dashed border-black/15 grid place-items-center text-xs text-char/40 text-center p-3">Belum ada gambar QRIS</div>
            )}
            <div className="flex-1 space-y-3">
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp,image/gif"
                onChange={(e) => uploadQris(e.target.files?.[0])}
                className="text-xs border border-black/15 rounded-xl px-4 py-2.5 bg-white w-full file:mr-3 file:py-1.5 file:px-4 file:rounded-full file:border-0 file:bg-char file:text-white file:text-xs file:font-bold"
              />
              {uploading && <p className="text-xs text-char/50">Mengunggah...</p>}
              <label className="block text-xs font-bold text-char/60">Nama Merchant (opsional, tampil di modal QR)</label>
              <input
                type="text"
                value={form.qris_static_merchant || ''}
                onChange={(e) => set('qris_static_merchant', e.target.value)}
                placeholder="mis. JURAGAN SEBLAK - NMID ID1234"
                className="w-full border border-black/15 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30"
              />
            </div>
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
          {saving ? 'Menyimpan...' : 'Simpan Pengaturan Pembayaran'}
        </button>
        <p className="text-[11px] text-char/40 text-center">API key tersimpan di database dan hanya tampil penuh untuk Super Admin.</p>
      </div>
    </main>
  )
}
