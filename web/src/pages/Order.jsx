import { useState } from 'react'
import { Link } from 'react-router-dom'

export default function Order() {
  const [orderType, setOrderType] = useState('dinein')
  const [showModal, setShowModal] = useState(false)
  const [form, setForm] = useState({
    nama: '',
    noHp: '',
    paket: '',
    jumlahPax: 1,
    tanggal: '',
    jam: '',
    alamat: '',
    catatan: '',
  })

  const isDineIn = orderType === 'dinein'

  const handleChange = (e) => {
    const { name, value } = e.target
    setForm((prev) => ({ ...prev, [name]: value }))
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    // TODO: kirim data pesanan ke backend ERP
    setShowModal(true)
  }

  const closeModal = () => {
    setShowModal(false)
    setForm({ nama: '', noHp: '', paket: '', jumlahPax: 1, tanggal: '', jam: '', alamat: '', catatan: '' })
    setOrderType('dinein')
  }

  const inputCls = 'w-full border border-black/15 rounded-xl px-4 py-3 text-sm'

  return (
    <div className="bg-cream text-char antialiased min-h-screen">
      {/* Simple top bar */}
      <header className="bg-char">
        <div className="max-w-3xl mx-auto px-5 md:px-8 h-16 md:h-20 flex items-center justify-between">
          <Link to="/" className="font-display text-2xl text-cream tracking-wide">
            BARA<span className="text-chili">.</span>PEDAS
          </Link>
          <Link to="/" className="text-cream/70 hover:text-ember text-sm font-semibold flex items-center gap-1.5 transition-colors">
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2"><path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" /></svg>
            Kembali
          </Link>
        </div>
      </header>

      <main className="py-12 md:py-20 px-5">
        <div className="max-w-xl mx-auto">
          <div className="text-center mb-9">
            <p className="text-chili font-bold text-sm mb-2">Form Pemesanan</p>
            <h1 className="font-display text-4xl md:text-5xl uppercase leading-tight">Pesan Sekarang,<br />Makan Sepuasnya</h1>
            <p className="mt-3 text-char/60 text-sm">Isi data di bawah, tim kami akan konfirmasi lewat WhatsApp dalam beberapa menit.</p>
          </div>

          {/* Tabs */}
          <div className="flex bg-white rounded-full p-1.5 border border-black/10 mb-8" role="tablist" aria-label="Tipe pesanan">
            <button
              type="button"
              role="tab"
              aria-selected={isDineIn}
              onClick={() => setOrderType('dinein')}
              className={`flex-1 py-3 rounded-full font-bold text-sm transition-colors ${isDineIn ? 'bg-chili text-white' : 'text-char/60'}`}
            >
              Pre-Order Dine-In
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={!isDineIn}
              onClick={() => setOrderType('delivery')}
              className={`flex-1 py-3 rounded-full font-bold text-sm transition-colors ${!isDineIn ? 'bg-chili text-white' : 'text-char/60'}`}
            >
              Order Delivery
            </button>
          </div>

          <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-black/5 shadow-sm p-6 md:p-8 space-y-5" noValidate>
            <div>
              <label htmlFor="nama" className="block text-sm font-bold mb-1.5">Nama Lengkap</label>
              <input type="text" id="nama" name="nama" required placeholder="Nama kamu" value={form.nama} onChange={handleChange} className={inputCls} />
            </div>

            <div>
              <label htmlFor="noHp" className="block text-sm font-bold mb-1.5">Nomor HP / WhatsApp</label>
              <input type="tel" id="noHp" name="noHp" required placeholder="08xx-xxxx-xxxx" value={form.noHp} onChange={handleChange} className={inputCls} />
            </div>

            <div>
              <label htmlFor="paket" className="block text-sm font-bold mb-1.5">Pilihan Paket AYCE</label>
              <select id="paket" name="paket" required value={form.paket} onChange={handleChange} className={`${inputCls} bg-white`}>
                <option value="" disabled>Pilih paket</option>
                <option value="reguler">Paket Reguler — Rp 75K/pax</option>
                <option value="pedas">Paket Pedas Jagoan — Rp 95K/pax</option>
                <option value="extreme">Paket Extreme Level 10 — Rp 115K/pax</option>
                <option value="keluarga">Paket Keluarga (4 pax) — Rp 340K</option>
              </select>
            </div>

            <div>
              <label htmlFor="jumlahPax" className="block text-sm font-bold mb-1.5">Jumlah Orang</label>
              <input type="number" id="jumlahPax" name="jumlahPax" min="1" value={form.jumlahPax} onChange={handleChange} required className={inputCls} />
            </div>

            {/* Dine-in only */}
            {isDineIn && (
              <div className="space-y-5">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label htmlFor="tanggal" className="block text-sm font-bold mb-1.5">Tanggal</label>
                    <input type="date" id="tanggal" name="tanggal" required value={form.tanggal} onChange={handleChange} className={inputCls} />
                  </div>
                  <div>
                    <label htmlFor="jam" className="block text-sm font-bold mb-1.5">Jam</label>
                    <input type="time" id="jam" name="jam" required value={form.jam} onChange={handleChange} className={inputCls} />
                  </div>
                </div>
                <p className="text-xs text-char/50">Meja akan dipegang selama 15 menit dari jam reservasi.</p>
              </div>
            )}

            {/* Delivery only */}
            {!isDineIn && (
              <div className="space-y-5">
                <div>
                  <label htmlFor="alamat" className="block text-sm font-bold mb-1.5">Alamat Lengkap</label>
                  <textarea
                    id="alamat"
                    name="alamat"
                    rows="3"
                    required
                    placeholder="Nama jalan, nomor rumah, RT/RW, kecamatan, patokan"
                    value={form.alamat}
                    onChange={handleChange}
                    className={`${inputCls} resize-none`}
                  ></textarea>
                </div>
              </div>
            )}

            <div>
              <label htmlFor="catatan" className="block text-sm font-bold mb-1.5">
                Catatan Tambahan <span className="font-normal text-char/40">(opsional)</span>
              </label>
              <textarea
                id="catatan"
                name="catatan"
                rows="2"
                placeholder="Contoh: kurangi level pedas untuk 1 pax"
                value={form.catatan}
                onChange={handleChange}
                className={`${inputCls} resize-none`}
              ></textarea>
            </div>

            <button
              type="submit"
              className="w-full bg-chili hover:bg-chili-dark text-white font-bold py-4 rounded-full transition-colors text-sm md:text-base"
            >
              Konfirmasi Pesanan
            </button>

            <p className="text-center text-xs text-char/40">
              Dengan menekan tombol di atas, kamu setuju dihubungi tim Bara.Pedas via WhatsApp untuk konfirmasi.
            </p>
          </form>
        </div>
      </main>

      {/* Success modal */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-char/70 backdrop-blur-sm px-5">
          <div className="bg-white rounded-2xl max-w-sm w-full p-8 text-center">
            <div className="w-14 h-14 rounded-full bg-chili/10 grid place-items-center mx-auto mb-5">
              <svg className="w-7 h-7 text-chili" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2"><path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" /></svg>
            </div>
            <h2 className="font-display text-2xl uppercase mb-2">Pesanan Diterima</h2>
            <p className="text-char/60 text-sm mb-6">
              {isDineIn
                ? 'Reservasi dine-in kamu sudah kami catat. Tim kami akan konfirmasi jadwal lewat WhatsApp.'
                : 'Pesanan delivery kamu sudah kami catat. Tim kami akan konfirmasi alamat & estimasi antar lewat WhatsApp.'}
            </p>
            <button onClick={closeModal} className="w-full bg-char text-white font-bold py-3 rounded-full">Tutup</button>
          </div>
        </div>
      )}
    </div>
  )
}
