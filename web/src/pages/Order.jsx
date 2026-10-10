import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { api } from '../api'

const rupiah = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID')

export default function Order() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  // Mode QR meja: /order?meja=ID dari QR yang ditempel di meja — pembeli
  // duduk, scan, pesan; meja jadi identitas pesanan (pelayan antar ke meja),
  // pembayaran langsung di meja lalu kasir meng-ACC.
  const mejaId = searchParams.get('meja')
  const [table, setTable] = useState(null)
  const [tableError, setTableError] = useState('')
  const [orderType, setOrderType] = useState('pickup')
  const [menu, setMenu] = useState([])
  const [store, setStore] = useState(null)
  const [cart, setCart] = useState({}) // { product_id: qty } — item biasa (minuman)
  // Seblak prasmanan: porsi yang sudah masuk keranjang + draft racikan aktif.
  // Satu porsi = 1 jenis kuah (WAJIB) + topping bebas + jumlah porsi.
  const [portions, setPortions] = useState([])
  const [draft, setDraft] = useState({ kuahId: null, toppings: {}, qty: 1, note: '' })
  const [draftError, setDraftError] = useState('')
  const [form, setForm] = useState({ nama: '', noHp: '', tanggal: '', jam: '', alamat: '', catatan: '' })
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')

  const tableMode = Boolean(mejaId)

  useEffect(() => {
    if (!mejaId) return
    api.get(`/online/tables/${encodeURIComponent(mejaId)}`)
      .then(setTable)
      .catch((e) => setTableError(e.message))
  }, [mejaId])

  useEffect(() => {
    setLoading(true)
    Promise.all([api.get('/online/menu'), api.get('/online/store')])
      .then(([m, s]) => { setMenu(m); setStore(s) })
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  // Kelompokkan menu per kategori untuk ditampilkan berurutan. Produk kuah &
  // topping tidak tampil sebagai daftar — keduanya lewat builder porsi.
  const kuahItems = useMemo(() => menu.filter((m) => m.category_key === 'kuah'), [menu])
  const toppingItems = useMemo(() => menu.filter((m) => m.category_key === 'topping'), [menu])
  const grouped = useMemo(() => {
    const map = new Map()
    for (const item of menu) {
      if (item.category_key === 'kuah' || item.category_key === 'topping') continue
      if (!map.has(item.category)) map.set(item.category, [])
      map.get(item.category).push(item)
    }
    return [...map.entries()]
  }, [menu])

  const isDineIn = orderType === 'dinein'
  const isDelivery = orderType === 'delivery'

  // Total satu porsi = (harga kuah + total topping) × jumlah porsi.
  const portionTotal = (p) => {
    const kuah = kuahItems.find((k) => k.id === p.kuahId)
    if (!kuah) return 0
    return (kuah.price + p.toppings.reduce((s, t) => s + t.price * t.qty, 0)) * p.qty
  }

  const cartItems = menu.filter((m) => cart[m.id] > 0).map((m) => ({ ...m, qty: cart[m.id] }))
  const subtotal =
    cartItems.reduce((s, it) => s + it.price * it.qty, 0) +
    portions.reduce((s, p) => s + portionTotal(p), 0)
  const taxRate = store?.tax_rate ?? 0
  const serviceRate = store?.service_rate ?? 0
  const tax = Math.round(subtotal * taxRate)
  const service = Math.round(subtotal * serviceRate)
  const total = subtotal + tax + service
  const cartCount = cartItems.reduce((s, it) => s + it.qty, 0) + portions.reduce((s, p) => s + p.qty, 0)

  const changeQty = (id, delta) => {
    setCart((prev) => {
      const next = { ...prev }
      const q = (next[id] || 0) + delta
      if (q <= 0) delete next[id]
      else next[id] = q
      return next
    })
  }

  // ---- RACIKAN PORSI ----
  const toggleDraftTopping = (id) => {
    setDraft((d) => {
      const next = { ...d.toppings }
      if (next[id] > 0) delete next[id]
      else next[id] = 1
      return { ...d, toppings: next }
    })
  }
  const changeDraftToppingQty = (id, delta) => {
    setDraft((d) => {
      const next = { ...d.toppings }
      const q = (next[id] || 0) + delta
      if (q <= 0) delete next[id]
      else next[id] = q
      return { ...d, toppings: next }
    })
  }
  const draftTotal = () => {
    const kuah = kuahItems.find((k) => k.id === draft.kuahId)
    if (!kuah) return 0
    const toppingSum = toppingItems.reduce((s, t) => s + (draft.toppings[t.id] || 0) * t.price, 0)
    return (kuah.price + toppingSum) * draft.qty
  }
  // "Tambah Porsi" → porsi masuk keranjang, draft bersih untuk porsi berikutnya.
  const addPortion = () => {
    const kuah = kuahItems.find((k) => k.id === draft.kuahId)
    if (!kuah) {
      setDraftError('Wajib pilih jenis kuah dulu (Nyemek, Sedang, atau Full Kuah)')
      return
    }
    setPortions((prev) => [
      ...prev,
      {
        kuah,
        toppings: toppingItems.filter((t) => draft.toppings[t.id] > 0).map((t) => ({ ...t, qty: draft.toppings[t.id] })),
        qty: draft.qty,
        note: draft.note.trim() || null,
      },
    ])
    setDraft({ kuahId: null, toppings: {}, qty: 1, note: '' })
    setDraftError('')
  }
  const removePortion = (idx) => setPortions((prev) => prev.filter((_, i) => i !== idx))

  const handleChange = (e) => {
    const { name, value } = e.target
    setForm((prev) => ({ ...prev, [name]: value }))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (portions.length === 0 && cartItems.length === 0) {
      setError('Racik minimal satu porsi seblak dulu ya')
      return
    }
    setSubmitting(true)
    setError('')
    try {
      const order = await api.post('/online/orders', {
        customer_name: form.nama || null,
        customer_phone: tableMode ? null : form.noHp,
        order_type: tableMode ? null : orderType,
        table_id: tableMode ? Number(mejaId) : null,
        items: [
          // Porsi prasmanan: kuah wajib + topping bebas per porsi
          ...portions.map((p) => ({
            kuah_id: p.kuah.id,
            qty: p.qty,
            note: p.note,
            toppings: p.toppings.map((t) => ({ product_id: t.id, qty: t.qty })),
          })),
          // Item biasa (minuman)
          ...cartItems.map((it) => ({ product_id: it.id, qty: it.qty })),
        ],
        schedule_date: !tableMode && isDineIn ? form.tanggal : null,
        schedule_time: !tableMode && isDineIn ? form.jam : null,
        delivery_address: !tableMode && isDelivery ? form.alamat : null,
        note: form.catatan,
      })
      // Simpan kode pelacakan supaya pelanggan bisa buka lagi tanpa menyalin.
      try {
        const saved = JSON.parse(localStorage.getItem('js_my_orders') || '[]')
        saved.unshift({ order_no: order.order_no, code: order.track_code, at: Date.now() })
        localStorage.setItem('js_my_orders', JSON.stringify(saved.slice(0, 20)))
      } catch { /* storage penuh/diblokir — kode tetap ditampilkan */ }
      navigate(`/track/${order.order_no}?code=${order.track_code}&baru=1`)
    } catch (err) {
      setError(err.message)
      setSubmitting(false)
    }
  }

  const inputCls = 'w-full border border-black/15 rounded-xl px-4 py-3 text-sm'
  const typeTabs = [
    { key: 'pickup', label: 'Ambil di Tempat' },
    { key: 'dinein', label: 'Pre-Order Dine-In' },
    { key: 'delivery', label: 'Order Delivery' },
  ]

  return (
    <div className="bg-cream text-char antialiased min-h-screen">
      <header className="bg-char sticky top-0 z-40">
        <div className="max-w-5xl mx-auto px-5 md:px-8 h-16 md:h-20 flex items-center justify-between">
          <Link to="/" className="font-display text-2xl text-cream tracking-wide">
            JURAGAN <span className="text-chili">SEBLAK</span>
          </Link>
          <div className="flex items-center gap-4">
            <Link to="/track" className="text-cream/70 hover:text-ember text-sm font-semibold transition-colors">
              Lacak Pesanan
            </Link>
            <Link to="/" className="text-cream/70 hover:text-ember text-sm font-semibold flex items-center gap-1.5 transition-colors">
              <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2"><path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" /></svg>
              Kembali
            </Link>
          </div>
        </div>
      </header>

      <main className="py-10 md:py-14 px-5">
        <div className="max-w-5xl mx-auto">
          {tableError ? (
            <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-10 text-center">
              <p className="font-display text-3xl uppercase mb-2">QR Tidak Valid</p>
              <p className="text-char/60 text-sm">QR meja ini tidak dikenal atau meja sudah dinonaktifkan. Silakan hubungi pelayan.</p>
            </div>
          ) : (
          <>
          <div className="text-center mb-6">
            <p className="text-chili font-bold text-sm mb-2">{tableMode ? 'Pesan dari Meja' : 'Pesan Online'}</p>
            <h1 className="font-display text-4xl md:text-5xl uppercase leading-tight">
              {tableMode ? <>Meja {table?.label ?? '…'}</> : <>Pesan Sekarang,<br />Bayar via QRIS</>}
            </h1>
            <p className="mt-3 text-char/60 text-sm max-w-xl mx-auto">
              {tableMode
                ? 'Pilih menu, kirim pesanan, lalu bayar langsung di meja — kasir kami verifikasi. Pantau statusnya di HP-mu.'
                : 'Pilih menu, bayar dengan QRIS, lalu pantau pesananmu sampai selesai — semuanya online.'}
            </p>
          </div>

          {tableMode && table && (
            <div className="max-w-xl mx-auto mb-6 bg-chili/10 border border-chili/30 rounded-2xl px-5 py-4 flex items-center gap-4">
              <span className="text-3xl">🪑</span>
              <p className="text-sm text-char/80">
                Kamu memesan untuk <strong>Meja {table.label}</strong>. Pelayan akan mengantar pesanan ke meja ini —
                tunjukkan halaman ini ke pelayan bila perlu.
              </p>
            </div>
          )}

          {error && (
            <div className="mb-6 bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm font-semibold text-center">{error}</div>
          )}

          {loading ? (
            <p className="text-center text-char/50 py-16">Memuat menu…</p>
          ) : (
            <div className="grid lg:grid-cols-[1fr_360px] gap-8 items-start">
              {/* PILIH MENU */}
              <div className="space-y-8">
                {/* BUILDER PORSI SEBLAK PRASMANAN — kuah wajib, isi bebas */}
                <section className="bg-white rounded-2xl border-2 border-chili/30 p-5 md:p-6">
                  <div className="flex items-center justify-between gap-3 mb-1">
                    <h2 className="font-display text-2xl uppercase">Racik Porsi Seblakmu</h2>
                    {portions.length > 0 && (
                      <span className="text-xs font-bold bg-chili/10 text-chili px-3 py-1 rounded-full">{portions.length} porsi di keranjang</span>
                    )}
                  </div>
                  <p className="text-char/60 text-sm mb-5">
                    Pilih jenis kuah (wajib), isi topping sesuai selera, tentukan jumlah porsi —
                    lalu tambahkan lagi untuk porsi berikutnya dengan isian berbeda.
                  </p>

                  <p className="text-xs font-bold text-char/60 mb-2">1. Jenis Kuah — <span className="text-chili">WAJIB</span></p>
                  <div className="grid grid-cols-3 gap-2 mb-5">
                    {kuahItems.map((k) => (
                      <button
                        key={k.id}
                        type="button"
                        onClick={() => { setDraft((d) => ({ ...d, kuahId: k.id })); setDraftError('') }}
                        className={`border rounded-xl px-2 py-3 text-center transition-colors ${draft.kuahId === k.id ? 'border-chili bg-chili/5 ring-1 ring-chili' : 'border-black/10 hover:border-chili/50'}`}
                      >
                        <p className="font-bold text-xs md:text-sm leading-snug">{k.name}</p>
                        <p className="text-chili font-bold text-xs mt-1">{rupiah(k.price)}</p>
                      </button>
                    ))}
                    {kuahItems.length === 0 && (
                      <p className="col-span-3 text-xs text-char/40">Menu belum tersedia — coba lagi nanti.</p>
                    )}
                  </div>

                  <p className="text-xs font-bold text-char/60 mb-2">2. Isian / Topping — sesuai selera</p>
                  <div className="space-y-1.5 mb-5">
                    {toppingItems.map((t) => {
                      const qty = draft.toppings[t.id] || 0
                      return (
                        <div key={t.id} className={`flex items-center gap-3 border rounded-xl px-3 py-2 ${qty > 0 ? 'border-chili bg-chili/5' : 'border-black/10'}`}>
                          <button type="button" onClick={() => toggleDraftTopping(t.id)} className="flex-1 text-left min-w-0">
                            <span className="text-sm font-semibold">{t.name}</span>
                            <span className="text-xs text-char/50 ml-2">{rupiah(t.price)}</span>
                          </button>
                          {qty === 0 ? (
                            <button type="button" onClick={() => toggleDraftTopping(t.id)} aria-label={`Tambah ${t.name}`} className="w-8 h-8 rounded-full bg-chili text-white font-bold grid place-items-center shrink-0">+</button>
                          ) : (
                            <div className="flex items-center gap-2 shrink-0">
                              <button type="button" onClick={() => changeDraftToppingQty(t.id, -1)} aria-label={`Kurangi ${t.name}`} className="w-8 h-8 rounded-full bg-cream border border-black/10 font-bold grid place-items-center">−</button>
                              <span className="w-6 text-center font-bold tabular-nums">{qty}</span>
                              <button type="button" onClick={() => changeDraftToppingQty(t.id, 1)} aria-label={`Tambah ${t.name}`} className="w-8 h-8 rounded-full bg-chili text-white font-bold grid place-items-center">+</button>
                            </div>
                          )}
                        </div>
                      )
                    })}
                    {toppingItems.length === 0 && (
                      <p className="text-xs text-char/40">Topping belum tersedia — coba lagi nanti.</p>
                    )}
                  </div>

                  <div className="grid sm:grid-cols-2 gap-4 mb-5">
                    <div>
                      <p className="text-xs font-bold text-char/60 mb-2">3. Jumlah Porsi</p>
                      <div className="flex items-center gap-3 border border-black/10 rounded-xl px-3 py-2">
                        <button type="button" onClick={() => setDraft((d) => ({ ...d, qty: Math.max(1, d.qty - 1) }))} className="w-8 h-8 rounded-full bg-cream border border-black/10 font-bold grid place-items-center">−</button>
                        <span className="flex-1 text-center font-bold tabular-nums">{draft.qty}</span>
                        <button type="button" onClick={() => setDraft((d) => ({ ...d, qty: d.qty + 1 }))} className="w-8 h-8 rounded-full bg-chili text-white font-bold grid place-items-center">+</button>
                      </div>
                    </div>
                    <div>
                      <p className="text-xs font-bold text-char/60 mb-2">4. Catatan Dapur <span className="font-normal text-char/40">(opsional)</span></p>
                      <input
                        type="text"
                        value={draft.note}
                        onChange={(e) => setDraft((d) => ({ ...d, note: e.target.value }))}
                        placeholder="mis. pedas level 3"
                        className={inputCls}
                      />
                    </div>
                  </div>

                  {draftError && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-2.5 mb-3">{draftError}</p>}

                  <div className="flex items-center gap-4">
                    <div className="shrink-0">
                      <p className="text-[11px] text-char/50 font-bold uppercase">Subtotal Porsi</p>
                      <p className="font-display text-xl text-chili">{rupiah(draftTotal())}</p>
                    </div>
                    <button type="button" onClick={addPortion} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3.5 rounded-full text-sm transition-colors">
                      Tambah Porsi ke Keranjang
                    </button>
                  </div>
                </section>

                <div className="flex flex-wrap gap-2">
                  {grouped.map(([cat]) => (
                    <a key={cat} href={`#cat-${cat.replace(/\W+/g, '-')}`} className="bg-white border border-black/10 rounded-full px-4 py-2 text-xs font-bold hover:border-chili transition-colors">
                      {cat}
                    </a>
                  ))}
                </div>

                {grouped.map(([cat, items]) => (
                  <section key={cat} id={`cat-${cat.replace(/\W+/g, '-')}`}>
                    <h2 className="font-display text-2xl uppercase mb-4">{cat}</h2>
                    <div className="space-y-3">
                      {items.map((item) => {
                        const qty = cart[item.id] || 0
                        return (
                          <div key={item.id} className={`bg-white rounded-2xl border p-4 flex items-center gap-4 transition-colors ${qty > 0 ? 'border-chili' : 'border-black/5'}`}>
                            {item.image_url && (
                              <img src={item.image_url} alt={item.name} className="w-16 h-16 rounded-xl object-cover bg-cream shrink-0" onError={(e) => { e.currentTarget.style.display = 'none' }} />
                            )}
                            <div className="flex-1 min-w-0">
                              <p className="font-bold text-sm leading-snug">{item.name}</p>
                              <p className="text-chili font-display text-lg mt-0.5">{rupiah(item.price)}</p>
                            </div>
                            {qty === 0 ? (
                              <button onClick={() => changeQty(item.id, 1)} aria-label={`Tambah ${item.name}`} className="w-9 h-9 rounded-full bg-chili text-white font-bold text-lg grid place-items-center hover:bg-chili-dark transition-colors shrink-0">+</button>
                            ) : (
                              <div className="flex items-center gap-2 shrink-0">
                                <button onClick={() => changeQty(item.id, -1)} aria-label={`Kurangi ${item.name}`} className="w-8 h-8 rounded-full bg-cream border border-black/10 font-bold grid place-items-center hover:border-chili transition-colors">−</button>
                                <span className="w-6 text-center font-bold tabular-nums">{qty}</span>
                                <button onClick={() => changeQty(item.id, 1)} aria-label={`Tambah ${item.name}`} className="w-8 h-8 rounded-full bg-chili text-white font-bold grid place-items-center hover:bg-chili-dark transition-colors">+</button>
                              </div>
                            )}
                          </div>
                        )
                      })}
                    </div>
                  </section>
                ))}
              </div>

              {/* KERANJANG + FORM */}
              <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-black/5 shadow-sm p-6 space-y-5 lg:sticky lg:top-24" noValidate>
                <div>
                  <p className="font-display text-xl uppercase mb-3">Pesananmu</p>
                  {portions.length === 0 && cartItems.length === 0 ? (
                    <p className="text-sm text-char/40 py-3">Belum ada pesanan. Racik porsi seblakmu di atas 👆</p>
                  ) : (
                    <div className="space-y-3 text-sm">
                      {portions.map((p, i) => (
                        <div key={i} className="bg-cream/60 border border-black/5 rounded-xl p-3">
                          <div className="flex justify-between gap-3">
                            <span className="font-semibold min-w-0">
                              Porsi {i + 1} · {p.qty}× {p.kuah.name}
                            </span>
                            <span className="font-semibold shrink-0">{rupiah(portionTotal(p))}</span>
                          </div>
                          {p.toppings.length > 0 && (
                            <p className="text-xs text-char/60 mt-1">
                              {p.toppings.map((t) => `${t.qty > 1 ? `${t.qty}x ` : ''}${t.name}`).join(', ')}
                            </p>
                          )}
                          {p.note && <p className="text-xs text-char/40 mt-0.5">↳ {p.note}</p>}
                          <button type="button" onClick={() => removePortion(i)} className="text-xs font-bold text-chili hover:underline mt-1.5">
                            Hapus porsi
                          </button>
                        </div>
                      ))}
                      {cartItems.length > 0 && (
                        <ul className="space-y-2">
                          {cartItems.map((it) => (
                            <li key={it.id} className="flex justify-between gap-3">
                              <span className="truncate">{it.qty}× {it.name}</span>
                              <span className="font-semibold shrink-0">{rupiah(it.price * it.qty)}</span>
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>
                  )}
                </div>

                {(taxRate > 0 || serviceRate > 0) && (portions.length > 0 || cartItems.length > 0) && (
                  <div className="space-y-1 text-sm text-char/60 border-t border-black/5 pt-4">
                    <div className="flex justify-between"><span>Subtotal</span><span>{rupiah(subtotal)}</span></div>
                    {taxRate > 0 && <div className="flex justify-between"><span>Pajak {Math.round(taxRate * 100)}%</span><span>{rupiah(tax)}</span></div>}
                    {serviceRate > 0 && <div className="flex justify-between"><span>Service {Math.round(serviceRate * 100)}%</span><span>{rupiah(service)}</span></div>}
                  </div>
                )}
                {(portions.length > 0 || cartItems.length > 0) && (
                  <div className="flex justify-between font-bold border-t border-black/5 pt-4">
                    <span>Total</span>
                    <span className="text-chili">{rupiah(total)}</span>
                  </div>
                )}

                <div className="border-t border-black/5 pt-5 space-y-5">
                  <p className="font-bold text-sm">Data Pemesan</p>

                  {!tableMode && (
                    <div className="grid grid-cols-3 gap-2" role="tablist" aria-label="Tipe pesanan">
                      {typeTabs.map((t) => (
                        <button
                          key={t.key}
                          type="button"
                          role="tab"
                          aria-selected={orderType === t.key}
                          onClick={() => setOrderType(t.key)}
                          className={`py-2.5 px-1 rounded-xl font-bold text-[11px] leading-tight transition-colors border ${orderType === t.key ? 'bg-chili text-white border-chili' : 'bg-white text-char/60 border-black/10'}`}
                        >
                          {t.label}
                        </button>
                      ))}
                    </div>
                  )}

                  <div>
                    <label htmlFor="nama" className="block text-sm font-bold mb-1.5">
                      Nama Lengkap {tableMode && <span className="font-normal text-char/40">(opsional)</span>}
                    </label>
                    <input type="text" id="nama" name="nama" required={!tableMode} placeholder={tableMode ? 'Nama kamu — boleh dikosongkan' : 'Nama kamu'} value={form.nama} onChange={handleChange} className={inputCls} />
                  </div>

                  {!tableMode && (
                    <div>
                      <label htmlFor="noHp" className="block text-sm font-bold mb-1.5">Nomor HP / WhatsApp</label>
                      <input type="tel" id="noHp" name="noHp" required placeholder="08xx-xxxx-xxxx" value={form.noHp} onChange={handleChange} className={inputCls} />
                    </div>
                  )}

                  {!tableMode && isDineIn && (
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
                  )}

                  {!tableMode && isDelivery && (
                    <div>
                      <label htmlFor="alamat" className="block text-sm font-bold mb-1.5">Alamat Lengkap</label>
                      <textarea id="alamat" name="alamat" rows="3" required placeholder="Nama jalan, nomor rumah, RT/RW, kecamatan, patokan" value={form.alamat} onChange={handleChange} className={`${inputCls} resize-none`}></textarea>
                    </div>
                  )}

                  <div>
                    <label htmlFor="catatan" className="block text-sm font-bold mb-1.5">
                      Catatan Tambahan <span className="font-normal text-char/40">(opsional)</span>
                    </label>
                    <textarea id="catatan" name="catatan" rows="2" placeholder="Contoh: kurangi level pedas untuk 1 pax" value={form.catatan} onChange={handleChange} className={`${inputCls} resize-none`}></textarea>
                  </div>

                  <button
                    type="submit"
                    disabled={submitting}
                    className="w-full bg-chili hover:bg-chili-dark disabled:opacity-60 text-white font-bold py-4 rounded-full transition-colors text-sm md:text-base"
                  >
                    {submitting ? 'Memproses…' : tableMode ? 'Kirim Pesanan ke Dapur' : 'Buat Pesanan & Bayar via QRIS'}
                  </button>

                  <p className="text-center text-xs text-char/40">
                    {tableMode
                      ? 'Pesanan masuk ke dapur setelah kasir memverifikasi pembayaranmu di meja.'
                      : 'Setelah pesanan dibuat, kamu akan scan QRIS statis kami lalu kasir meng-ACC pembayaranmu.'}
                  </p>
                </div>
              </form>
            </div>
          )}
          </>
          )}
        </div>
      </main>
    </div>
  )
}
