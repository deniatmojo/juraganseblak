import { useEffect, useMemo, useRef, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import QRCode from 'qrcode'
import { api } from '../../api'

const payMethods = [
  { key: 'cash', label: 'Cash', icon: 'M3 10h18M7 15h1m4 0h5M4 6h16a1 1 0 011 1v10a1 1 0 01-1 1H4a1 1 0 01-1-1V7a1 1 0 011-1z' },
  { key: 'qris', label: 'QRIS', icon: 'M4 4h6v6H4V4zm10 0h6v6h-6V4zM4 14h6v6H4v-6zm10 3h3m3 0h-3m0-3v3m0 0v3' },
  { key: 'debit', label: 'Debit/Kredit', icon: 'M3 10h18M3 6h18a1 1 0 011 1v10a1 1 0 01-1 1H3a1 1 0 01-1-1V7a1 1 0 011-1zm3 8h4' },
]
const payLabels = { cash: 'Cash', qris: 'QRIS', debit: 'Debit/Kredit' }

const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

export default function Pos() {
  const { user } = useOutletContext()
  const [search, setSearch] = useState('')
  const [activeCat, setActiveCat] = useState('semua')
  const [cart, setCart] = useState([])
  const [selectedPay, setSelectedPay] = useState('cash')
  const [receipt, setReceipt] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')

  const [menuItems, setMenuItems] = useState([])
  const [categories, setCategories] = useState([{ key: 'semua', label: 'Semua' }])
  const [rates, setRates] = useState({ tax_rate: 0.1, service_rate: 0.05 })

  // Shift kasir
  const [shift, setShift] = useState(null)
  const [shiftModal, setShiftModal] = useState(null)   // 'open' | 'close'
  const [shiftCash, setShiftCash] = useState('')
  const [shiftResult, setShiftResult] = useState(null) // rekap tutup shift

  const loadShift = () => {
    api.get('/shifts/active').then(setShift).catch(() => setShift(null))
  }
  useEffect(loadShift, [])

  const startShift = async () => {
    try {
      const s = await api.post('/shifts', { opening_cash: Number(shiftCash || 0) })
      setShift(s)
      setShiftModal(null)
      setShiftCash('')
    } catch (e) { setError(e.message) }
  }

  const closeShift = async () => {
    try {
      const rekap = await api.post(`/shifts/${shift.id}/close`, { closing_cash: Number(shiftCash || 0) })
      setShiftResult(rekap)
      setShiftModal(null)
      setShiftCash('')
      setShift(null)
    } catch (e) { setError(e.message) }
  }

  useEffect(() => {
    let mounted = true
    Promise.all([api.get('/products'), api.get('/categories'), api.get('/settings')])
      .then(([products, cats, settings]) => {
        if (!mounted) return
        setMenuItems(products.map((p) => ({ id: p.id, name: p.name, cat: p.category, price: p.price, img: p.image_url })))
        setCategories([{ key: 'semua', label: 'Semua' }, ...cats.map((c) => ({ key: c.key, label: c.label }))])
        setRates({ tax_rate: settings.tax_rate ?? 0.1, service_rate: settings.service_rate ?? 0.05 })
      })
      .catch((e) => mounted && setError(`Gagal memuat data: ${e.message}`))
    return () => { mounted = false }
  }, [])

  const filteredMenu = useMemo(() => {
    const term = search.trim().toLowerCase()
    return menuItems.filter(
      (item) => (activeCat === 'semua' || item.cat === activeCat) && item.name.toLowerCase().includes(term)
    )
  }, [search, activeCat, menuItems])

  const addToCart = (id) => {
    setCart((prev) => {
      const existing = prev.find((c) => c.id === id)
      if (existing) return prev.map((c) => (c.id === id ? { ...c, qty: c.qty + 1 } : c))
      return [...prev, { ...menuItems.find((m) => m.id === id), qty: 1 }]
    })
  }

  const changeQty = (id, delta) => {
    setCart((prev) => {
      const item = prev.find((c) => c.id === id)
      if (!item) return prev
      const newQty = item.qty + delta
      if (newQty <= 0) return prev.filter((c) => c.id !== id)
      return prev.map((c) => (c.id === id ? { ...c, qty: newQty } : c))
    })
  }

  const subtotal = cart.reduce((sum, c) => sum + c.price * c.qty, 0)
  const tax = subtotal * rates.tax_rate
  const service = subtotal * rates.service_rate
  const grandTotal = subtotal + tax + service
  const totalQty = cart.reduce((sum, c) => sum + c.qty, 0)

  const openReceipt = async () => {
    setError('')
    setSubmitting(true)
    try {
      const order = await api.post('/orders', {
        items: cart.map((c) => ({ product_id: c.id, qty: c.qty })),
        pay_method: selectedPay,
        channel: 'pos',
      })
      setReceipt({
        no: order.order_no,
        date: new Date(order.created_at || Date.now()).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' }),
        items: cart,
        subtotal: order.subtotal,
        tax: order.tax_amount,
        service: order.service_amount,
        total: order.total,
        method: payLabels[order.pay_method] || order.pay_method,
        storeName: order.store_name,
        storeAddress: order.store_address,
        storePhone: order.store_phone,
        footer: order.receipt_footer,
      })
    } catch (e) {
      setError(e.message)
    } finally {
      setSubmitting(false)
    }
  }

  const closeReceipt = () => {
    setReceipt(null)
    setCart([])
  }

  // QR berisi nomor struk — digambar ke canvas saat struk muncul
  const qrCanvasRef = useRef(null)
  useEffect(() => {
    if (receipt && qrCanvasRef.current) {
      QRCode.toCanvas(qrCanvasRef.current, receipt.no, { width: 110, margin: 1 }, () => {})
    }
  }, [receipt])

  const receiptText = () => {
    if (!receipt) return ''
    return [
      `*${receipt.storeName || 'Juragan Seblak'}*`,
      receipt.storeAddress,
      `Telp: ${receipt.storePhone || '-'}`,
      '',
      `No: ${receipt.no} (${receipt.date})`,
      `Kasir: ${user?.name || '-'}`,
      '',
      ...receipt.items.map((i) => `${i.qty}x ${i.name} — ${formatRp(i.price * i.qty)}`),
      '',
      `Subtotal: ${formatRp(receipt.subtotal)}`,
      `Pajak: ${formatRp(receipt.tax)}`,
      `Service: ${formatRp(receipt.service)}`,
      `*Total: ${formatRp(receipt.total)}*`,
      `Metode: ${receipt.method}`,
      '',
      receipt.footer || 'Terima kasih!',
    ].join('\n')
  }

  const sendWhatsApp = () => {
    window.open(`https://wa.me/?text=${encodeURIComponent(receiptText())}`, '_blank')
  }

  return (
    <main className="flex-1 min-h-0 flex flex-col lg:flex-row gap-5 p-5 md:p-6">
      {/* LEFT: MENU GRID */}
      <section className="lg:w-[60%] flex flex-col min-h-0">
        {/* SHIFT BAR */}
        <div className={`flex flex-wrap items-center gap-3 mb-4 rounded-2xl px-5 py-3.5 border ${shift ? 'bg-green-50 border-green-200' : 'bg-white border-black/10'}`}>
          {shift ? (
            <>
              <span className="w-2.5 h-2.5 rounded-full bg-green-500 animate-pulse shrink-0"></span>
              <p className="text-xs font-bold text-green-800">
                Shift aktif sejak {new Date(shift.opened_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                &nbsp;·&nbsp;Kas awal {formatRp(shift.opening_cash)}
                &nbsp;·&nbsp;{shift.totals.order_count} pesanan · {formatRp(shift.totals.sales_total)}
              </p>
              <button onClick={() => setShiftModal('close')} className="ml-auto text-xs font-bold text-white bg-char hover:bg-char-soft px-4 py-2 rounded-full shrink-0">Tutup Shift</button>
            </>
          ) : (
            <>
              <span className="text-xs font-bold text-char/60">Belum ada shift aktif — checkout tetap bisa, tapi tidak tercatat di rekap kas.</span>
              <button onClick={() => setShiftModal('open')} className="ml-auto text-xs font-bold text-white bg-chili hover:bg-chili-dark px-4 py-2 rounded-full shrink-0">Mulai Shift</button>
            </>
          )}
        </div>

        <div className="relative mb-4">
          <svg className="w-5 h-5 absolute left-4 top-1/2 -translate-y-1/2 text-char/40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-4.35-4.35M17 10a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
          <input
            type="search"
            placeholder="Cari menu..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full bg-white border border-black/10 rounded-full pl-12 pr-4 py-3.5 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30 focus:border-chili"
          />
        </div>

        <div className="flex gap-2 mb-4 overflow-x-auto pb-1">
          {categories.map((cat) => (
            <button
              key={cat.key}
              onClick={() => setActiveCat(cat.key)}
              className={`cat-btn shrink-0 px-5 py-2.5 rounded-full text-sm font-bold bg-white border border-black/10 ${activeCat === cat.key ? 'active' : 'text-char/60'}`}
            >
              {cat.label}
            </button>
          ))}
        </div>

        <div className="flex-1 overflow-y-auto pr-1">
          <div className="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-4 gap-4 pb-2">
            {filteredMenu.length === 0 && (
              <p className="col-span-full text-center text-sm text-char/40 py-10">Menu tidak ditemukan.</p>
            )}
            {filteredMenu.map((item) => (
              <button key={item.id} onClick={() => addToCart(item.id)} className="menu-item text-left bg-white border border-black/10 rounded-xl overflow-hidden">
                <img src={item.img} alt={item.name} className="w-full h-24 object-cover" />
                <div className="p-3">
                  <p className="font-bold text-sm leading-snug">{item.name}</p>
                  <p className="text-chili font-bold text-sm mt-1">{formatRp(item.price)}</p>
                </div>
              </button>
            ))}
          </div>
        </div>
      </section>

      {/* RIGHT: CART */}
      <section className="lg:w-[40%] flex flex-col bg-white rounded-2xl border border-black/5 shadow-sm min-h-0">
        <div className="px-6 py-5 border-b border-black/5 flex items-center justify-between shrink-0">
          <div>
            <h2 className="font-bold">Pesanan Saat Ini</h2>
            <p className="text-xs text-char/50 mt-0.5">Kasir {user?.name || '-'} &middot; {totalQty} item</p>
          </div>
          {cart.length > 0 && (
            <button onClick={() => setCart([])} className="text-xs font-bold text-chili hover:underline">Kosongkan</button>
          )}
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-4 space-y-4 min-h-[140px]">
          {cart.length === 0 ? (
            <p className="text-center text-sm text-char/40 py-10">Keranjang masih kosong.<br />Pilih menu di sebelah kiri.</p>
          ) : (
            cart.map((item) => (
              <div key={item.id} className="flex items-center gap-3">
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-sm truncate">{item.name}</p>
                  <p className="text-xs text-char/50">{formatRp(item.price)}</p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button onClick={() => changeQty(item.id, -1)} className="w-7 h-7 rounded-full border border-black/15 text-char font-bold text-sm grid place-items-center">−</button>
                  <span className="w-5 text-center text-sm font-bold">{item.qty}</span>
                  <button onClick={() => changeQty(item.id, 1)} className="w-7 h-7 rounded-full border border-black/15 text-char font-bold text-sm grid place-items-center">+</button>
                </div>
                <p className="w-24 text-right font-bold text-sm shrink-0">{formatRp(item.price * item.qty)}</p>
              </div>
            ))
          )}
        </div>

        <div className="px-6 py-5 border-t border-black/5 space-y-2.5 shrink-0">
          <div className="flex justify-between text-sm text-char/60"><span>Subtotal</span><span>{formatRp(subtotal)}</span></div>
          <div className="flex justify-between text-sm text-char/60"><span>Pajak ({Math.round(rates.tax_rate * 100)}%)</span><span>{formatRp(tax)}</span></div>
          <div className="flex justify-between text-sm text-char/60"><span>Service Charge ({Math.round(rates.service_rate * 100)}%)</span><span>{formatRp(service)}</span></div>
          <div className="flex justify-between items-center pt-2.5 border-t border-black/5">
            <span className="font-bold">Grand Total</span>
            <span className="font-display text-2xl text-chili">{formatRp(grandTotal)}</span>
          </div>
        </div>

        <div className="px-6 pb-6 shrink-0">
          <p className="text-xs font-bold text-char/50 mb-2.5">Metode Pembayaran</p>
          <div className="grid grid-cols-3 gap-2.5 mb-5">
            {payMethods.map((m) => (
              <button
                key={m.key}
                onClick={() => setSelectedPay(m.key)}
                className={`pay-btn border border-black/10 rounded-xl py-3 flex flex-col items-center gap-1.5 text-xs font-bold ${selectedPay === m.key ? 'active' : 'text-char/70'}`}
              >
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d={m.icon} /></svg>
                {m.label}
              </button>
            ))}
          </div>

          {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3 mb-3">{error}</p>}

          <button
            onClick={openReceipt}
            disabled={cart.length === 0 || submitting}
            className="w-full bg-chili hover:bg-chili-dark disabled:opacity-40 disabled:cursor-not-allowed text-white font-bold py-4 rounded-full transition-colors"
          >
            {submitting ? 'Menyimpan...' : 'Bayar & Cetak Resi'}
          </button>
        </div>
      </section>

      {/* SHIFT MODAL (mulai / tutup) */}
      {shiftModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setShiftModal(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">{shiftModal === 'open' ? 'Mulai Shift' : 'Tutup Shift'}</h2>
            <p className="text-char/50 text-sm mb-6">
              {shiftModal === 'open'
                ? 'Hitung uang kas di laci dan catat sebagai kas awal.'
                : `Penjualan tunai shift ini: ${formatRp(shift?.totals.cash_total || 0)}. Hitung uang di laci dan catat sebagai kas akhir.`}
            </p>

            <label className="block text-sm font-bold mb-1.5">{shiftModal === 'open' ? 'Kas Awal (Rp)' : 'Kas Akhir di Laci (Rp)'}</label>
            <input
              type="number"
              min="0"
              value={shiftCash}
              onChange={(e) => setShiftCash(e.target.value)}
              className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-6 focus:outline-none focus:ring-2 focus:ring-chili/30"
            />

            <div className="flex gap-3">
              <button onClick={() => setShiftModal(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={shiftModal === 'open' ? startShift : closeShift} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">
                {shiftModal === 'open' ? 'Buka Shift' : 'Tutup & Rekap'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* REKAP TUTUP SHIFT */}
      {shiftResult && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setShiftResult(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-5">Rekap Shift</h2>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between text-char/60"><span>Pesanan</span><span className="font-bold text-char">{shiftResult.order_count}</span></div>
              <div className="flex justify-between text-char/60"><span>Total Penjualan</span><span className="font-bold text-char">{formatRp(shiftResult.sales_total)}</span></div>
              <div className="flex justify-between text-char/60"><span>Tunai</span><span>{formatRp(shiftResult.cash_total)}</span></div>
              <div className="flex justify-between text-char/60"><span>QRIS</span><span>{formatRp(shiftResult.qris_total)}</span></div>
              <div className="flex justify-between text-char/60"><span>Debit/Kredit</span><span>{formatRp(shiftResult.debit_total)}</span></div>
              <div className="border-t border-dashed border-black/20 pt-2 flex justify-between text-char/60"><span>Kas Awal</span><span>{formatRp(shiftResult.opening_cash)}</span></div>
              <div className="flex justify-between text-char/60"><span>Kas Seharusnya</span><span className="font-bold">{formatRp(shiftResult.expected_cash)}</span></div>
              <div className="flex justify-between text-char/60"><span>Kas Akhir (laci)</span><span>{formatRp(shiftResult.closing_cash)}</span></div>
              <div className={`flex justify-between font-bold pt-2 border-t border-black/10 ${shiftResult.selisih === 0 ? 'text-green-700' : 'text-chili'}`}>
                <span>Selisih</span>
                <span>{shiftResult.selisih === 0 ? 'Pas' : (shiftResult.selisih > 0 ? '+' : '−') + ' ' + formatRp(Math.abs(shiftResult.selisih))}</span>
              </div>
            </div>
            <button onClick={() => setShiftResult(null)} className="w-full bg-char hover:bg-char-soft text-white font-bold py-3 rounded-full text-sm mt-6">Selesai</button>
          </div>
        </div>
      )}

      {/* RECEIPT MODAL */}
      {receipt && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm"></div>

          <div className="relative bg-white rounded-2xl w-full max-w-sm overflow-hidden">
            <div id="receiptPrintArea" className="p-7">
              <div className="text-center mb-5">
                <p className="font-display text-xl tracking-wide">{receipt.storeName || 'Juragan Seblak'}</p>
                {receipt.storeAddress && <p className="text-xs text-char/50 mt-1">{receipt.storeAddress}</p>}
                {receipt.storePhone && <p className="text-xs text-char/50">{receipt.storePhone}</p>}
              </div>

              <div className="border-t border-dashed border-black/20 pt-3 mb-3 text-xs text-char/60 space-y-1">
                <div className="flex justify-between"><span>No. Struk</span><span>{receipt.no}</span></div>
                <div className="flex justify-between"><span>Kasir</span><span>{user?.name || '-'}</span></div>
                <div className="flex justify-between"><span>Tanggal</span><span>{receipt.date}</span></div>
              </div>

              <div className="border-t border-dashed border-black/20 pt-3 mb-3 space-y-2 text-sm">
                {receipt.items.map((item) => (
                  <div key={item.id} className="flex justify-between">
                    <span>{item.qty}x {item.name}</span>
                    <span>{formatRp(item.price * item.qty)}</span>
                  </div>
                ))}
              </div>

              <div className="border-t border-dashed border-black/20 pt-3 space-y-1.5 text-sm">
                <div className="flex justify-between text-char/60"><span>Subtotal</span><span>{formatRp(receipt.subtotal)}</span></div>
                <div className="flex justify-between text-char/60"><span>Pajak</span><span>{formatRp(receipt.tax)}</span></div>
                <div className="flex justify-between text-char/60"><span>Service</span><span>{formatRp(receipt.service)}</span></div>
                <div className="flex justify-between font-bold pt-1.5 border-t border-dashed border-black/20"><span>Total</span><span>{formatRp(receipt.total)}</span></div>
                <div className="flex justify-between text-char/60"><span>Metode</span><span>{receipt.method}</span></div>
              </div>

              <div className="text-center mt-5">
                <canvas ref={qrCanvasRef} className="mx-auto rounded-lg border border-black/10"></canvas>
                <p className="text-[10px] text-char/40 mt-1.5">{receipt.no}</p>
                <span className="inline-block bg-chili/10 text-chili font-bold text-sm px-4 py-1.5 rounded-full mt-3">LUNAS</span>
                <p className="text-xs text-char/40 mt-3">{receipt.footer || 'Terima kasih, sampai jumpa lagi 🔥'}</p>
              </div>
            </div>

            <div className="flex gap-3 px-7 pb-7 pt-1">
              <button onClick={() => window.print()} className="flex-1 bg-char text-white font-bold py-3 rounded-full text-sm flex items-center justify-center gap-2">
                <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M6 9V4h12v5M6 18h12v3H6v-3zm-3-9h18a1 1 0 011 1v6a1 1 0 01-1 1h-3v-3H6v3H3a1 1 0 01-1-1v-6a1 1 0 011-1z" /></svg>
                Print
              </button>
              <button onClick={sendWhatsApp} className="flex-1 bg-green-600 hover:bg-green-700 text-white font-bold py-3 rounded-full text-sm flex items-center justify-center gap-2">
                <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M17.5 14.4c-.3-.15-1.76-.87-2.03-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.65.07-.3-.15-1.26-.46-2.4-1.48-.89-.79-1.49-1.77-1.66-2.07-.17-.3-.02-.46.13-.61.13-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.37-.02-.52-.07-.15-.67-1.62-.92-2.22-.24-.58-.49-.5-.67-.51h-.57c-.2 0-.52.07-.8.37-.27.3-1.04 1.02-1.04 2.5 0 1.47 1.07 2.89 1.22 3.09.15.2 2.11 3.22 5.1 4.51.71.31 1.27.49 1.7.63.72.23 1.37.2 1.88.12.57-.09 1.76-.72 2.01-1.42.25-.7.25-1.29.17-1.42-.07-.13-.27-.2-.57-.35M12.05 21.5h-.01a9.5 9.5 0 01-4.83-1.32l-.35-.2-3.59.94.96-3.5-.22-.36A9.46 9.46 0 012.55 12 9.5 9.5 0 1112.05 21.5m8.09-17.6A11.47 11.47 0 0012.05.5C5.7.5.55 5.65.55 12c0 2.03.53 4.01 1.54 5.75L.5 23.5l5.89-1.54A11.44 11.44 0 0012.05 23.5c6.35 0 11.5-5.15 11.5-11.5 0-3.07-1.2-5.96-3.41-8.1" /></svg>
                WhatsApp
              </button>
            </div>
            <div className="px-7 pb-7">
              <button onClick={closeReceipt} className="w-full border border-black/15 text-char font-bold py-3 rounded-full text-sm">Pesanan Baru</button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
