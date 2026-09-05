import { useMemo, useState } from 'react'

const menuItems = [
  { id: 1, name: 'Paket Reguler', cat: 'paket', price: 75000, img: '/images/menu-geprek.jpg' },
  { id: 2, name: 'Paket Pedas Jagoan', cat: 'paket', price: 95000, img: '/images/menu-mie.jpg' },
  { id: 3, name: 'Paket Extreme Lv.10', cat: 'paket', price: 115000, img: '/images/pos-extreme.jpg' },
  { id: 4, name: 'Paket Keluarga (4px)', cat: 'paket', price: 340000, img: '/images/pos-keluarga.jpg' },
  { id: 5, name: 'Es Teh Manis', cat: 'minuman', price: 8000, img: '/images/pos-esteh.jpg' },
  { id: 6, name: 'Es Jeruk Peras', cat: 'minuman', price: 12000, img: '/images/pos-esjeruk.jpg' },
  { id: 7, name: 'Es Campur Segar', cat: 'minuman', price: 18000, img: '/images/pos-escampur.jpg' },
  { id: 8, name: 'Air Mineral', cat: 'minuman', price: 5000, img: '/images/pos-air.jpg' },
  { id: 9, name: 'Tambah Nasi', cat: 'ekstra', price: 5000, img: '/images/pos-nasi.jpg' },
  { id: 10, name: 'Kerupuk', cat: 'ekstra', price: 5000, img: '/images/pos-kerupuk.jpg' },
  { id: 11, name: 'Extra Sambal', cat: 'ekstra', price: 7000, img: '/images/pos-sambal.jpg' },
  { id: 12, name: 'Telur Ceplok', cat: 'ekstra', price: 6000, img: '/images/pos-telur.jpg' },
]

const categories = [
  { key: 'semua', label: 'Semua' },
  { key: 'paket', label: 'Paket AYCE' },
  { key: 'minuman', label: 'Minuman' },
  { key: 'ekstra', label: 'Ekstra' },
]

const payMethods = [
  { key: 'cash', label: 'Cash', icon: 'M3 10h18M7 15h1m4 0h5M4 6h16a1 1 0 011 1v10a1 1 0 01-1 1H4a1 1 0 01-1-1V7a1 1 0 011-1z' },
  { key: 'qris', label: 'QRIS', icon: 'M4 4h6v6H4V4zm10 0h6v6h-6V4zM4 14h6v6H4v-6zm10 3h3m3 0h-3m0-3v3m0 0v3' },
  { key: 'debit', label: 'Debit/Kredit', icon: 'M3 10h18M3 6h18a1 1 0 011 1v10a1 1 0 01-1 1H3a1 1 0 01-1-1V7a1 1 0 011-1zm3 8h4' },
]
const payLabels = { cash: 'Cash', qris: 'QRIS', debit: 'Debit/Kredit' }

const TAX_RATE = 0.10
const SERVICE_RATE = 0.05

const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

export default function Pos() {
  const [search, setSearch] = useState('')
  const [activeCat, setActiveCat] = useState('semua')
  const [cart, setCart] = useState([])
  const [selectedPay, setSelectedPay] = useState('cash')
  const [receipt, setReceipt] = useState(null)

  const filteredMenu = useMemo(() => {
    const term = search.trim().toLowerCase()
    return menuItems.filter(
      (item) => (activeCat === 'semua' || item.cat === activeCat) && item.name.toLowerCase().includes(term)
    )
  }, [search, activeCat])

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
  const tax = subtotal * TAX_RATE
  const service = subtotal * SERVICE_RATE
  const grandTotal = subtotal + tax + service
  const totalQty = cart.reduce((sum, c) => sum + c.qty, 0)

  const openReceipt = () => {
    setReceipt({
      no: '#BP-' + Math.floor(10000 + Math.random() * 9000),
      date: new Date().toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' }),
      items: cart,
      subtotal,
      tax,
      service,
      total: grandTotal,
      method: payLabels[selectedPay],
    })
  }

  const closeReceipt = () => {
    setReceipt(null)
    setCart([])
  }

  return (
    <main className="flex-1 min-h-0 flex flex-col lg:flex-row gap-5 p-5 md:p-6">
      {/* LEFT: MENU GRID */}
      <section className="lg:w-[60%] flex flex-col min-h-0">
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
            <p className="text-xs text-char/50 mt-0.5">Meja 07 &middot; {totalQty} item</p>
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
          <div className="flex justify-between text-sm text-char/60"><span>Pajak (10%)</span><span>{formatRp(tax)}</span></div>
          <div className="flex justify-between text-sm text-char/60"><span>Service Charge (5%)</span><span>{formatRp(service)}</span></div>
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

          <button
            onClick={openReceipt}
            disabled={cart.length === 0}
            className="w-full bg-chili hover:bg-chili-dark disabled:opacity-40 disabled:cursor-not-allowed text-white font-bold py-4 rounded-full transition-colors"
          >
            Bayar &amp; Cetak Resi
          </button>
        </div>
      </section>

      {/* RECEIPT MODAL */}
      {receipt && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm"></div>

          <div className="relative bg-white rounded-2xl w-full max-w-sm overflow-hidden">
            <div id="receiptPrintArea" className="p-7">
              <div className="text-center mb-5">
                <p className="font-display text-xl tracking-wide">BARA<span className="text-chili">.</span>PEDAS</p>
                <p className="text-xs text-char/50 mt-1">Jl. Raya Darmo No. 12, Surabaya</p>
                <p className="text-xs text-char/50">0812-3456-7890</p>
              </div>

              <div className="border-t border-dashed border-black/20 pt-3 mb-3 text-xs text-char/60 space-y-1">
                <div className="flex justify-between"><span>No. Struk</span><span>{receipt.no}</span></div>
                <div className="flex justify-between"><span>Meja</span><span>07</span></div>
                <div className="flex justify-between"><span>Kasir</span><span>Melati Putri</span></div>
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
                <div className="flex justify-between text-char/60"><span>Pajak (10%)</span><span>{formatRp(receipt.tax)}</span></div>
                <div className="flex justify-between text-char/60"><span>Service (5%)</span><span>{formatRp(receipt.service)}</span></div>
                <div className="flex justify-between font-bold pt-1.5 border-t border-dashed border-black/20"><span>Total</span><span>{formatRp(receipt.total)}</span></div>
                <div className="flex justify-between text-char/60"><span>Metode</span><span>{receipt.method}</span></div>
              </div>

              <div className="text-center mt-5">
                <span className="inline-block bg-chili/10 text-chili font-bold text-sm px-4 py-1.5 rounded-full">LUNAS</span>
                <p className="text-xs text-char/40 mt-3">Terima kasih, sampai jumpa lagi 🔥</p>
              </div>
            </div>

            <div className="flex gap-3 px-7 pb-7 pt-1">
              <button onClick={() => window.print()} className="flex-1 bg-char text-white font-bold py-3 rounded-full text-sm flex items-center justify-center gap-2">
                <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M6 9V4h12v5M6 18h12v3H6v-3zm-3-9h18a1 1 0 011 1v6a1 1 0 01-1 1h-3v-3H6v3H3a1 1 0 01-1-1v-6a1 1 0 011-1z" /></svg>
                Print
              </button>
              <button onClick={closeReceipt} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Pesanan Baru</button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
