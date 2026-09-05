import { useState } from 'react'

const initialStock = [
  { id: 1, name: 'Daging Ayam', cat: 'Protein', stock: 8, min: 15, unit: 'kg' },
  { id: 2, name: 'Daging Sapi', cat: 'Protein', stock: 22, min: 10, unit: 'kg' },
  { id: 3, name: 'Cabai Rawit', cat: 'Bumbu', stock: 3, min: 8, unit: 'kg' },
  { id: 4, name: 'Cabai Merah Besar', cat: 'Bumbu', stock: 5, min: 6, unit: 'kg' },
  { id: 5, name: 'Bawang Merah', cat: 'Bumbu', stock: 14, min: 8, unit: 'kg' },
  { id: 6, name: 'Bawang Putih', cat: 'Bumbu', stock: 11, min: 6, unit: 'kg' },
  { id: 7, name: 'Beras', cat: 'Pokok', stock: 60, min: 30, unit: 'kg' },
  { id: 8, name: 'Mie Basah', cat: 'Pokok', stock: 4, min: 10, unit: 'kg' },
  { id: 9, name: 'Minyak Goreng', cat: 'Pelengkap', stock: 18, min: 10, unit: 'liter' },
  { id: 10, name: 'Telur Ayam', cat: 'Protein', stock: 25, min: 10, unit: 'kg' },
  { id: 11, name: 'Kerupuk Mentah', cat: 'Pelengkap', stock: 6, min: 5, unit: 'kg' },
  { id: 12, name: 'Gula Pasir', cat: 'Bumbu', stock: 9, min: 5, unit: 'kg' },
  { id: 13, name: 'Kecap Manis', cat: 'Pelengkap', stock: 12, min: 6, unit: 'liter' },
  { id: 14, name: 'Jeruk Nipis', cat: 'Bumbu', stock: 2, min: 4, unit: 'kg' },
]

export default function Stock() {
  const [stockItems, setStockItems] = useState(initialStock)
  const [activeItem, setActiveItem] = useState(null)
  const [newStock, setNewStock] = useState(0)

  const openModal = (id) => {
    const item = stockItems.find((i) => i.id === id)
    setActiveItem(item)
    setNewStock(item.stock)
  }

  const saveStock = () => {
    const val = Number(newStock)
    if (activeItem && !Number.isNaN(val) && val >= 0) {
      setStockItems((prev) => prev.map((i) => (i.id === activeItem.id ? { ...i, stock: val } : i)))
    }
    setActiveItem(null)
  }

  const criticalCount = stockItems.filter((i) => i.stock <= i.min).length

  const summary = [
    { value: stockItems.length, label: 'Total Jenis Bahan', iconCls: 'bg-char/5', color: 'text-char', icon: 'M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4' },
    { value: criticalCount, label: 'Stok Kritis', iconCls: 'bg-red-50', color: 'text-chili', icon: 'M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z' },
    { value: stockItems.length - criticalCount, label: 'Stok Aman', iconCls: 'bg-green-50', color: 'text-green-600', icon: 'M5 13l4 4L19 7' },
  ]

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {/* SUMMARY STRIP */}
      <div className="grid sm:grid-cols-3 gap-5">
        {summary.map((s) => (
          <div key={s.label} className="bg-white rounded-2xl p-6 border border-black/5 shadow-sm flex items-center gap-4">
            <span className={`w-11 h-11 rounded-xl ${s.iconCls} grid place-items-center shrink-0`}>
              <svg className={`w-5 h-5 ${s.color}`} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d={s.icon} /></svg>
            </span>
            <div>
              <p className="text-2xl font-display">{s.value}</p>
              <p className="text-xs text-char/50">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* STOCK TABLE */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-6 py-5 border-b border-black/5">
          <h2 className="font-bold">Daftar Bahan Baku</h2>
          <span className="text-xs text-char/50">Update terakhir: hari ini, 09.15</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[760px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Bahan Baku</th>
                <th className="px-6 py-3 font-bold">Kategori</th>
                <th className="px-6 py-3 font-bold">Sisa Stok</th>
                <th className="px-6 py-3 font-bold">Batas Minimum</th>
                <th className="px-6 py-3 font-bold">Status</th>
                <th className="px-6 py-3 font-bold text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {stockItems.map((item) => {
                const isCritical = item.stock <= item.min
                const pct = Math.min(100, Math.round((item.stock / (item.min * 2)) * 100))
                return (
                  <tr key={item.id} className="hover:bg-cream/60 transition-colors">
                    <td className="px-6 py-4 font-semibold">{item.name}</td>
                    <td className="px-6 py-4 text-char/60">{item.cat}</td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <span className="font-semibold w-16">{item.stock} {item.unit}</span>
                        <div className="w-20 h-1.5 bg-black/5 rounded-full overflow-hidden hidden sm:block">
                          <div className={`stock-bar-fill h-full ${isCritical ? 'bg-chili' : 'bg-green-500'}`} style={{ width: `${pct}%` }}></div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-char/60">{item.min} {item.unit}</td>
                    <td className="px-6 py-4">
                      {isCritical ? (
                        <span className="text-xs font-bold text-chili bg-red-50 px-2.5 py-1 rounded-full">Kritis</span>
                      ) : (
                        <span className="text-xs font-bold text-green-700 bg-green-50 px-2.5 py-1 rounded-full">Aman</span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <button onClick={() => openModal(item.id)} className="text-xs font-bold text-white bg-char hover:bg-char-soft px-4 py-2 rounded-full">Update Stok</button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* UPDATE STOCK MODAL */}
      {activeItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setActiveItem(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">Update Stok</h2>
            <p className="text-char/50 text-sm mb-6">{activeItem.name} — saat ini {activeItem.stock} {activeItem.unit}</p>

            <label htmlFor="newStockInput" className="block text-sm font-bold mb-1.5">Jumlah Stok Baru</label>
            <div className="flex items-center gap-2 mb-6">
              <input
                type="number"
                id="newStockInput"
                min="0"
                value={newStock}
                onChange={(e) => setNewStock(e.target.value)}
                className="flex-1 border border-black/15 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30 focus:border-chili"
              />
              <span className="text-sm font-bold text-char/50 w-14 shrink-0">{activeItem.unit}</span>
            </div>

            <div className="flex gap-3">
              <button onClick={() => setActiveItem(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={saveStock} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Simpan</button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
