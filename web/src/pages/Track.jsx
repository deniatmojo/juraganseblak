import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { api } from '../api'

const rupiah = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID')

// Kelompokkan baris order_items (dari /online/track) menjadi porsi prasmanan
// (kuah + topping per porsi_no) dan item biasa.
function groupItems(items) {
  const groups = []
  for (const it of items || []) {
    if (it.item_role === 'kuah') {
      groups.push({ kind: 'porsi', no: it.porsi_no, qty: it.qty, kuah: it, note: it.note, toppings: [] })
    } else if (it.item_role === 'topping') {
      const g = groups[groups.length - 1]
      if (g?.kind === 'porsi' && g.no === it.porsi_no) g.toppings.push(it)
      else groups.push({ kind: 'porsi', no: it.porsi_no, qty: null, kuah: null, note: null, toppings: [it] })
    } else {
      groups.push({ kind: 'item', item: it })
    }
  }
  return groups
}

// Tahapan pesanan setelah pembayaran di-ACC. Label "siap" menyesuaikan tipe:
// delivery = diantar, lainnya = siap diambil.
function progressSteps(orderType) {
  return [
    { key: 'queue', label: 'Masuk Antrian', icon: '🧾' },
    { key: 'processing', label: 'Diproses Dapur', icon: '🍳' },
    { key: 'ready', label: orderType === 'delivery' ? 'Diantar Kurir' : 'Siap Diambil', icon: orderType === 'delivery' ? '🛵' : '🥡' },
    { key: 'done', label: 'Selesai', icon: '✅' },
  ]
}

// Nomor HP lokal (08xx / format bebas) → format internasional wa.me (62xx).
function waNumber(phone) {
  const digits = String(phone || '').replace(/\D/g, '')
  if (!digits) return ''
  if (digits.startsWith('62')) return digits
  if (digits.startsWith('0')) return '62' + digits.slice(1)
  return digits
}

export default function Track() {
  const { orderNo } = useParams()
  const navigate = useNavigate()
  const [search, setSearch] = useSearchParams()
  const [order, setOrder] = useState(null)
  const [store, setStore] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(Boolean(orderNo))
  const [lookup, setLookup] = useState({ no: orderNo || '', hp: '' })

  const load = useCallback((no, { code, phone } = {}) => {
    const qs = code ? `code=${encodeURIComponent(code)}` : `phone=${encodeURIComponent(phone || '')}`
    return api
      .get(`/online/track/${encodeURIComponent(no)}?${qs}`)
      .then((o) => { setOrder(o); setError('') })
      .catch((e) => { setOrder(null); setError(e.message) })
  }, [])

  // Info toko (QRIS statis, nomor WA admin) — publik.
  useEffect(() => {
    api.get('/online/store').then(setStore).catch(() => {})
  }, [])

  // Muat sekali saat halaman dibuka (kode pelacakan dari URL).
  useEffect(() => {
    if (!orderNo) return
    setLoading(true)
    const code = search.get('code')
    load(orderNo, code ? { code } : { phone: search.get('phone') || '' })
      .finally(() => setLoading(false))
  }, [orderNo, search, load])

  // Polling "live": status pesanan diperbarui tiap 10 detik selama tab terbuka.
  useEffect(() => {
    if (!order || error) return
    const timer = setInterval(() => {
      const code = search.get('code')
      load(order.order_no, code ? { code } : { phone: order.customer_phone || '' })
        .catch(() => {})
    }, 10_000)
    return () => clearInterval(timer)
  }, [order, error, search, load])

  const submitLookup = async (e) => {
    e.preventDefault()
    const input = lookup.no.trim()
    // Cukup kode pelacakan (8 karakter heksadesimal) — tanpa nomor HP.
    if (/^[0-9a-f]{8}$/i.test(input)) {
      try {
        const r = await api.get(`/online/track-code/${input.toLowerCase()}`)
        navigate(`/track/${r.order_no}?code=${input.toLowerCase()}`)
      } catch (err) {
        setError(err.message)
      }
      return
    }
    if (!input) {
      setError('Isi kode pelacakan atau nomor pesanan')
      return
    }
    // Nomor pesanan saja → tampilan ringkas; dengan nomor HP → detail lengkap.
    if (lookup.hp.replace(/\D/g, '').length < 4) {
      navigate(`/track/${encodeURIComponent(input.toUpperCase())}`)
      return
    }
    load(input, { phone: lookup.hp })
  }

  const isPending = order?.status === 'pending'
  const isCanceled = order?.status === 'canceled'
  const steps = progressSteps(order?.order_type)
  const currentIdx = order?.progress ? steps.findIndex((s) => s.key === order.progress) : -1

  // Chat WA langsung ke admin dengan nomor & nama pesanan otomatis terlampir.
  const waLink = order && store?.store_phone
    ? `https://wa.me/${waNumber(store.store_phone)}?text=${encodeURIComponent(
        `Halo Admin ${store.store_name || 'Juragan Seblak'}, saya mau bertanya tentang pesanan saya.\n\nNo. Pesanan: ${order.order_no}\nNama: ${order.customer_name}${order.table_no ? `\nMeja: ${order.table_no}` : ''}\nTotal: ${rupiah(order.total)}\nStatus: ${isPending ? 'Menunggu ACC pembayaran' : isCanceled ? 'Dibatalkan' : (steps[currentIdx]?.label || 'Lunas')}\n\n`
      )}`
    : null

  return (
    <div className="bg-cream text-char antialiased min-h-screen">
      <header className="bg-char">
        <div className="max-w-3xl mx-auto px-5 md:px-8 h-16 md:h-20 flex items-center justify-between">
          <Link to="/" className="font-display text-2xl text-cream tracking-wide">
            JURAGAN <span className="text-chili">SEBLAK</span>
          </Link>
          <div className="flex items-center gap-4">
            <Link to="/order" className="text-cream/70 hover:text-ember text-sm font-semibold transition-colors">Pesan Lagi</Link>
            <Link to="/" className="text-cream/70 hover:text-ember text-sm font-semibold flex items-center gap-1.5 transition-colors">
              <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2"><path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" /></svg>
              Kembali
            </Link>
          </div>
        </div>
      </header>

      <main className="py-10 md:py-14 px-5">
        <div className="max-w-xl mx-auto">
          {/* FORM PENCARIAN (halaman /track tanpa nomor, atau akses ditolak) */}
          {(!orderNo || (error && !loading)) && (
            <form onSubmit={submitLookup} className="bg-white rounded-2xl border border-black/5 shadow-sm p-6 md:p-8 space-y-5 mb-8">
              <div className="text-center">
                <p className="text-chili font-bold text-sm mb-2">Lacak Pesanan</p>
                <h1 className="font-display text-3xl uppercase">Pesananmu Sampai Mana?</h1>
                <p className="mt-2 text-char/60 text-sm">Masukkan kode pelacakan, atau nomor pesanan (JS-…). Tambahkan nomor HP untuk melihat detail lengkap.</p>
              </div>
              <div>
                <label htmlFor="no" className="block text-sm font-bold mb-1.5">Kode pelacakan atau nomor pesanan</label>
                <input type="text" id="no" placeholder="mis. dae94e27 atau JS-20260927-0001" value={lookup.no} onChange={(e) => setLookup((p) => ({ ...p, no: e.target.value }))} className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm" required />
              </div>
              <div>
                <label htmlFor="hp" className="block text-sm font-bold mb-1.5">Nomor HP saat memesan <span className="font-normal text-char/40">(opsional — untuk detail lengkap)</span></label>
                <input type="tel" id="hp" placeholder="08xx-xxxx-xxxx" value={lookup.hp} onChange={(e) => setLookup((p) => ({ ...p, hp: e.target.value }))} className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm" />
              </div>
              <button type="submit" className="w-full bg-chili hover:bg-chili-dark text-white font-bold py-4 rounded-full transition-colors">Lacak Pesanan</button>
            </form>
          )}

          {loading && <p className="text-center text-char/50 py-16">Memuat pesanan…</p>}

          {error && !loading && (
            <p className="text-center text-red-600 text-sm font-semibold mb-6">{error}</p>
          )}

          {order && !loading && (
            <div className="space-y-6">
              {order.limited && (
                <p className="bg-white border border-black/10 rounded-2xl px-5 py-3 text-xs text-char/60">
                  Tampilan ringkas (dicari lewat nomor pesanan). Data pribadi disembunyikan. Untuk detail lengkap, lacak memakai kode pelacakan atau nomor HP saat memesan.
                </p>
              )}
              {/* KEPALA PESANAN */}
              <div className="bg-char text-cream rounded-2xl p-6 md:p-8">
                <div className="flex items-start justify-between gap-4 flex-wrap">
                  <div>
                    <p className="text-cream/50 text-xs font-bold uppercase tracking-widest">No. Pesanan</p>
                    <p className="font-display text-2xl md:text-3xl mt-1">{order.order_no}</p>
                    <p className="text-cream/60 text-sm mt-1">
                      {order.customer_name} · {order.order_type === 'dinein' ? 'Dine-In' : order.order_type === 'delivery' ? 'Delivery' : 'Ambil di Tempat'}
                    </p>
                    {order.table_no && (
                      <p className="inline-block mt-2 bg-ember text-char text-xs font-bold px-3 py-1 rounded-full">🪑 Meja {order.table_no} — antar ke sini</p>
                    )}
                  </div>
                  <div className="text-right">
                    <p className="text-cream/50 text-xs font-bold uppercase tracking-widest">Total Bayar</p>
                    <p className="font-display text-2xl md:text-3xl text-ember mt-1">{rupiah(order.total)}</p>
                  </div>
                </div>
                {order.schedule_at && (
                  <p className="text-cream/70 text-sm mt-3">📅 Jadwal kedatangan: {new Date(order.schedule_at).toLocaleString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })}</p>
                )}
                {order.delivery_address && <p className="text-cream/70 text-sm mt-3">📍 Diantar ke: {order.delivery_address}</p>}
                {order.customer_note && <p className="text-cream/70 text-sm mt-3">📝 Catatan: {order.customer_note}</p>}
              </div>

              {/* PEMBAYARAN — QRIS STATIS, ACC MANUAL KASIR */}
              {isPending && (
                <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-6 md:p-8">
                  <div className="flex items-center gap-3 mb-4">
                    <span className="relative flex h-3 w-3">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
                      <span className="relative inline-flex rounded-full h-3 w-3 bg-amber-500"></span>
                    </span>
                    <h2 className="font-display text-xl uppercase">Menunggu ACC Pembayaran</h2>
                  </div>
                  <p className="text-char/60 text-sm mb-5">
                    {order.table_no
                      ? 'Bayar langsung di meja: tunai ke pelayan atau scan QRIS di bawah ini (tekan untuk memperbesar). '
                      : 'Scan & bayar '}
                    <strong>{rupiah(order.total)}</strong>
                    {order.table_no ? ' Setelah bayar, kasir meng-ACC — status pesanan berubah otomatis di halaman ini.' : ' lewat QRIS di bawah ini (tekan untuk memperbesar). Setelah bayar, admin kasir akan mengecek dan meng-ACC — status pesanan berubah otomatis di halaman ini.'}
                  </p>
                  {store?.qris_static_image ? (
                    <a href={store.qris_static_image} target="_blank" rel="noopener" className="block max-w-[280px] mx-auto">
                      <img src={store.qris_static_image} alt="QRIS statis" className="w-full object-contain rounded-xl border border-black/10 bg-white" />
                    </a>
                  ) : (
                    <p className="text-sm text-char/50 bg-cream rounded-xl p-4 text-center">
                      QRIS belum dipasang admin. Silakan hubungi admin lewat WhatsApp untuk pembayaran.
                    </p>
                  )}
                  {store?.qris_static_merchant && (
                    <p className="text-center text-xs text-char/50 mt-3">Merchant: {store.qris_static_merchant}</p>
                  )}
                  <p className="text-center text-xs text-char/40 mt-4">Halaman ini memperbarui status otomatis setiap 10 detik. Jangan tutup ya!</p>
                </div>
              )}

              {isCanceled && (
                <div className="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                  <p className="font-display text-xl uppercase text-red-700 mb-1">Pesanan Dibatalkan</p>
                  <p className="text-red-600/80 text-sm">Hubungi admin lewat WhatsApp bila kamu merasa ada kekeliruan.</p>
                </div>
              )}

              {/* TIMELINE PROGRES — tampil setelah pembayaran di-ACC */}
              {order.status === 'paid' && (
                <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-6 md:p-8">
                  <h2 className="font-display text-xl uppercase mb-1">Pesanan Diluncurkan 🎉</h2>
                  <p className="text-char/50 text-xs mb-6">Terakhir diperbarui {order.progress_updated_at ? new Date(order.progress_updated_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : 'baru saja'} · otomatis tiap 10 detik</p>
                  <ol className="relative border-l-2 border-black/10 ml-3 space-y-7">
                    {steps.map((s, i) => {
                      const done = i < currentIdx
                      const active = i === currentIdx
                      return (
                        <li key={s.key} className="pl-6">
                          <span className={`absolute -left-[11px] w-5 h-5 rounded-full grid place-items-center text-[10px] font-bold ring-4 ring-white ${done ? 'bg-chili text-white' : active ? 'bg-chili text-white animate-pulse' : 'bg-black/10 text-char/40'}`}>
                            {done ? '✓' : i + 1}
                          </span>
                          <p className={`font-bold text-sm ${active ? 'text-chili' : done ? 'text-char' : 'text-char/40'}`}>
                            {s.icon} {s.label} {active && <span className="text-xs font-semibold">— sedang berjalan</span>}
                          </p>
                        </li>
                      )
                    })}
                  </ol>
                </div>
              )}

              {/* RINCIAN ITEM */}
              <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-6">
                <p className="font-bold text-sm mb-3">Rincian Pesanan</p>
                <div className="space-y-3 text-sm">
                  {groupItems(order.items).map((g, i) =>
                    g.kind === 'item' ? (
                      <div key={i} className="flex justify-between gap-3">
                        <span>{g.item.qty}× {g.item.name}</span>
                        <span className="font-semibold shrink-0">{rupiah(g.item.unit_price * g.item.qty)}</span>
                      </div>
                    ) : (
                      <div key={i} className="border border-black/5 rounded-xl p-3 bg-cream/40">
                        {g.kuah ? (
                          <div className="flex justify-between gap-3">
                            <span className="font-semibold">
                              Porsi {g.no} · {g.qty}× {g.kuah.name}
                              {g.note && <span className="block text-xs font-normal text-char/50">↳ {g.note}</span>}
                            </span>
                            <span className="font-semibold shrink-0">{rupiah(g.kuah.unit_price * g.qty + g.toppings.reduce((s, t) => s + t.unit_price * t.qty, 0))}</span>
                          </div>
                        ) : (
                          <p className="font-semibold">Porsi {g.no}</p>
                        )}
                        {g.toppings.length > 0 && (
                          <p className="text-xs text-char/60 mt-1">
                            {g.toppings.map((t) => `+ ${t.qty > 1 ? `${t.qty}x ` : ''}${t.name}`).join(' · ')}
                          </p>
                        )}
                      </div>
                    )
                  )}
                </div>
                <div className="border-t border-black/5 mt-3 pt-3 space-y-1 text-sm text-char/60">
                  <div className="flex justify-between"><span>Subtotal</span><span>{rupiah(order.subtotal)}</span></div>
                  {order.tax_amount > 0 && <div className="flex justify-between"><span>Pajak</span><span>{rupiah(order.tax_amount)}</span></div>}
                  {(order.service_amount > 0 || order.rounding_amount > 0) && <div className="flex justify-between"><span>Service</span><span>{rupiah(Number(order.service_amount) + Number(order.rounding_amount || 0))}</span></div>}
                  <div className="flex justify-between font-bold text-char pt-1"><span>Total</span><span className="text-chili">{rupiah(order.total)}</span></div>
                </div>
                <p className="text-xs text-char/40 mt-4">Simpan kode pelacakanmu: <strong className="text-char/60">{order.track_code || '—'}</strong></p>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* BUBBLE WA — langsung ke admin, nomor pesanan otomatis terlampir */}
      {order && waLink && (
        <a
          href={waLink}
          target="_blank"
          rel="noopener"
          aria-label="Tanya pesanan ini via WhatsApp"
          className="fixed bottom-6 right-6 z-50 flex items-center gap-3 pl-5 pr-6 py-3.5 rounded-full bg-[#25D366] text-white font-bold shadow-xl hover:scale-105 transition-transform text-sm"
        >
          <span className="wa-pulse absolute inset-0 rounded-full"></span>
          <svg className="relative w-6 h-6" viewBox="0 0 24 24" fill="currentColor"><path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.29-1.39a9.9 9.9 0 004.75 1.21h.01c5.46 0 9.9-4.45 9.9-9.91C21.96 6.45 17.5 2 12.04 2zm5.8 14.02c-.24.68-1.4 1.3-1.94 1.38-.5.08-1.13.11-1.82-.11-.42-.13-.96-.31-1.66-.6-2.92-1.26-4.83-4.2-4.98-4.4-.15-.2-1.19-1.58-1.19-3.02 0-1.44.75-2.14 1.02-2.44.27-.29.6-.36.8-.36.2 0 .4 0 .58.01.19.01.44-.07.68.53.25.6.85 2.08.92 2.23.07.15.12.33.02.53-.1.2-.15.32-.3.5-.15.18-.31.4-.44.53-.15.15-.3.31-.13.6.17.3.77 1.28 1.65 2.07 1.14 1.02 2.1 1.34 2.4 1.49.3.15.47.13.65-.08.18-.2.75-.87.95-1.17.2-.3.4-.25.66-.15.27.1 1.7.8 1.99.95.29.15.48.22.55.34.07.13.07.72-.17 1.4z" /></svg>
          <span className="relative">Tanya Pesanan Ini</span>
        </a>
      )}
    </div>
  )
}
