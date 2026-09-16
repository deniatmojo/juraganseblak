import { useEffect, useMemo, useState } from 'react'
import { api, getToken } from '../../api'

const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

const EMPTY_FORM = {
  id: null,
  name: '',
  category_id: '',
  price: '',
  hpp: '',
  image_url: '',
  stock_item_id: '',
  stock_qty_per_unit: '1',
  is_available: true,
  is_active: true,
}

const inputCls = 'w-full bg-white border border-black/15 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30 focus:border-chili'

export default function Menu() {
  const [products, setProducts] = useState([])
  const [categories, setCategories] = useState([])
  const [stockItems, setStockItems] = useState([])
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [activeCat, setActiveCat] = useState('semua')
  const [form, setForm] = useState(null)
  const [newCatLabel, setNewCatLabel] = useState('')
  const [uploading, setUploading] = useState(false)

  const uploadPhoto = async (file) => {
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
      setForm((f) => ({ ...f, image_url: data.url }))
      setError('')
    } catch (e) {
      setError(e.message)
    } finally {
      setUploading(false)
    }
  }

  const load = () => {
    Promise.all([api.get('/products?includeInactive=1'), api.get('/categories'), api.get('/stock')])
      .then(([p, c, s]) => {
        setProducts(p)
        setCategories(c)
        setStockItems(s)
      })
      .catch((e) => setError(e.message))
  }

  useEffect(load, [])

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    return products.filter(
      (p) => (activeCat === 'semua' || p.category === activeCat) && p.name.toLowerCase().includes(term)
    )
  }, [products, search, activeCat])

  const summary = [
    { value: products.length, label: 'Total Menu', iconCls: 'bg-char/5', color: 'text-char', icon: 'M4 6h16M4 6v12a2 2 0 002 2h12a2 2 0 002-2V6M4 6l2-4h12l2 4M9 11h6' },
    { value: products.filter((p) => p.is_active && p.is_available).length, label: 'Tersedia', iconCls: 'bg-green-50', color: 'text-green-600', icon: 'M5 13l4 4L19 7' },
    { value: products.filter((p) => !p.is_available).length, label: 'Habis / Nonaktif', iconCls: 'bg-red-50', color: 'text-chili', icon: 'M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z' },
  ]

  const openCreate = () => setForm({ ...EMPTY_FORM, category_id: categories[0]?.id ?? '' })
  const openEdit = (p) =>
    setForm({
      id: p.id,
      name: p.name,
      category_id: p.category_id,
      price: p.price,
      hpp: p.hpp,
      image_url: p.image_url || '',
      stock_item_id: p.stock_item_id || '',
      stock_qty_per_unit: p.stock_qty_per_unit ?? 1,
      is_available: Boolean(p.is_available),
      is_active: Boolean(p.is_active),
    })

  const saveProduct = async () => {
    try {
      const body = {
        name: form.name,
        category_id: Number(form.category_id),
        price: Number(form.price),
        hpp: Number(form.hpp || 0),
        image_url: form.image_url || null,
        stock_item_id: form.stock_item_id ? Number(form.stock_item_id) : null,
        stock_qty_per_unit: Number(form.stock_qty_per_unit || 1),
        is_available: form.is_available,
        is_active: form.is_active,
      }
      if (form.id) await api.patch(`/products/${form.id}`, body)
      else await api.post('/products', body)
      setForm(null)
      load()
    } catch (e) {
      setError(e.message)
    }
  }

  const toggleAvailable = async (p) => {
    try {
      await api.patch(`/products/${p.id}`, { is_available: p.is_available ? 0 : 1 })
      load()
    } catch (e) { setError(e.message) }
  }

  const deactivate = async (p) => {
    if (!window.confirm(`Nonaktifkan "${p.name}"? Menu tidak akan tampil di POS.`)) return
    try {
      await api.del(`/products/${p.id}`)
      load()
    } catch (e) { setError(e.message) }
  }

  const addCategory = async () => {
    const label = newCatLabel.trim()
    if (!label) return
    try {
      await api.post('/categories', { key: label.toLowerCase().replace(/\s+/g, '-'), label })
      setNewCatLabel('')
      load()
    } catch (e) { setError(e.message) }
  }

  const removeCategory = async (c) => {
    if (!window.confirm(`Hapus kategori "${c.label}"?`)) return
    try {
      await api.del(`/categories/${c.id}`)
      load()
    } catch (e) { setError(e.message) }
  }

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      {/* SUMMARY */}
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

      {/* KATEGORI */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm px-6 py-5 flex flex-wrap items-center gap-3">
        <h2 className="font-bold mr-2">Kategori</h2>
        {categories.map((c) => (
          <span key={c.id} className="inline-flex items-center gap-2 bg-cream border border-black/10 rounded-full pl-4 pr-2 py-1.5 text-xs font-bold">
            {c.label}
            <button onClick={() => removeCategory(c)} className="w-5 h-5 rounded-full bg-black/5 hover:bg-chili hover:text-white grid place-items-center" title="Hapus kategori">×</button>
          </span>
        ))}
        <div className="flex items-center gap-2 ml-auto">
          <input
            type="text"
            placeholder="Kategori baru..."
            value={newCatLabel}
            onChange={(e) => setNewCatLabel(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && addCategory()}
            className="bg-white border border-black/15 rounded-full px-4 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-chili/30"
          />
          <button onClick={addCategory} className="text-xs font-bold text-white bg-char hover:bg-char-soft px-4 py-2 rounded-full">Tambah</button>
        </div>
      </div>

      {/* TABEL MENU */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-3 px-6 py-5 border-b border-black/5">
          <h2 className="font-bold">Daftar Menu</h2>
          <div className="flex items-center gap-3">
            <input
              type="search"
              placeholder="Cari menu..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="bg-white border border-black/10 rounded-full px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30"
            />
            <button onClick={openCreate} className="text-xs font-bold text-white bg-chili hover:bg-chili-dark px-5 py-2.5 rounded-full">+ Menu Baru</button>
          </div>
        </div>

        <div className="flex gap-2 px-6 py-4 overflow-x-auto border-b border-black/5">
          {[{ key: 'semua', label: 'Semua' }, ...categories.map((c) => ({ key: c.key, label: c.label }))].map((cat) => (
            <button
              key={cat.key}
              onClick={() => setActiveCat(cat.key)}
              className={`cat-btn shrink-0 px-4 py-2 rounded-full text-xs font-bold bg-white border border-black/10 ${activeCat === cat.key ? 'active' : 'text-char/60'}`}
            >
              {cat.label}
            </button>
          ))}
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[860px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Menu</th>
                <th className="px-6 py-3 font-bold">Kategori</th>
                <th className="px-6 py-3 font-bold">Harga</th>
                <th className="px-6 py-3 font-bold">HPP</th>
                <th className="px-6 py-3 font-bold">Bahan</th>
                <th className="px-6 py-3 font-bold">Status</th>
                <th className="px-6 py-3 font-bold text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {filtered.length === 0 && (
                <tr><td colSpan={7} className="px-6 py-8 text-center text-char/40">Menu tidak ditemukan.</td></tr>
              )}
              {filtered.map((p) => (
                <tr key={p.id} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      {p.image_url ? (
                        <img src={p.image_url} alt={p.name} className="w-10 h-10 rounded-lg object-cover shrink-0" />
                      ) : (
                        <span className="w-10 h-10 rounded-lg bg-cream grid place-items-center shrink-0">🍽️</span>
                      )}
                      <span className="font-semibold">{p.name}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 text-char/60">{p.category_label}</td>
                  <td className="px-6 py-4 font-semibold">{formatRp(p.price)}</td>
                  <td className="px-6 py-4 text-char/60">{p.hpp ? formatRp(p.hpp) : '-'}</td>
                  <td className="px-6 py-4 text-char/60">
                    {p.stock_item_name ? `${p.stock_item_name} (${p.stock_qty_per_unit})` : <span className="text-char/30">tidak terhubung</span>}
                  </td>
                  <td className="px-6 py-4 space-x-1.5 whitespace-nowrap">
                    {!p.is_active ? (
                      <span className="text-xs font-bold text-char/50 bg-black/5 px-2.5 py-1 rounded-full">Nonaktif</span>
                    ) : p.is_available ? (
                      <span className="text-xs font-bold text-green-700 bg-green-50 px-2.5 py-1 rounded-full">Tersedia</span>
                    ) : (
                      <span className="text-xs font-bold text-chili bg-red-50 px-2.5 py-1 rounded-full">Habis</span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-right space-x-2 whitespace-nowrap">
                    {p.is_active === 1 && (
                      <button onClick={() => toggleAvailable(p)} className="text-xs font-bold text-char/70 hover:text-chili">
                        {p.is_available ? 'Set Habis' : 'Set Tersedia'}
                      </button>
                    )}
                    <button onClick={() => openEdit(p)} className="text-xs font-bold text-white bg-char hover:bg-char-soft px-4 py-2 rounded-full">Edit</button>
                    {p.is_active === 1 && (
                      <button onClick={() => deactivate(p)} className="text-xs font-bold text-chili hover:underline">Hapus</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL TAMBAH/EDIT */}
      {form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setForm(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-md p-7 max-h-[90vh] overflow-y-auto">
            <h2 className="font-display text-xl uppercase mb-6">{form.id ? 'Edit Menu' : 'Menu Baru'}</h2>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold mb-1.5">Nama Menu</label>
                <input type="text" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputCls} />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-bold mb-1.5">Kategori</label>
                  <select value={form.category_id} onChange={(e) => setForm({ ...form, category_id: e.target.value })} className={inputCls}>
                    {categories.map((c) => <option key={c.id} value={c.id}>{c.label}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-bold mb-1.5">URL Foto</label>
                  <input type="text" placeholder="/images/..." value={form.image_url} onChange={(e) => setForm({ ...form, image_url: e.target.value })} className={inputCls} />
                </div>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1.5">atau Upload Foto <span className="font-normal text-char/40">(maks 2MB, jpg/png/webp)</span></label>
                <div className="flex items-center gap-3">
                  <input type="file" accept="image/jpeg,image/png,image/webp,image/gif" onChange={(e) => uploadPhoto(e.target.files?.[0])} className="text-xs border border-black/15 rounded-xl px-4 py-2.5 bg-white w-full file:mr-3 file:py-1.5 file:px-4 file:rounded-full file:border-0 file:bg-char file:text-white file:text-xs file:font-bold" />
                  {uploading && <span className="text-xs text-char/50 shrink-0">Mengunggah...</span>}
                  {form.image_url && <img src={form.image_url} alt="Preview" className="w-10 h-10 rounded-lg object-cover border border-black/10 shrink-0" />}
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-bold mb-1.5">Harga Jual</label>
                  <input type="number" min="0" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} className={inputCls} />
                </div>
                <div>
                  <label className="block text-sm font-bold mb-1.5">HPP (modal)</label>
                  <input type="number" min="0" value={form.hpp} onChange={(e) => setForm({ ...form, hpp: e.target.value })} className={inputCls} />
                </div>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1.5">Bahan Stok Terhubung <span className="font-normal text-char/40">(opsional)</span></label>
                <div className="grid grid-cols-3 gap-3">
                  <select value={form.stock_item_id} onChange={(e) => setForm({ ...form, stock_item_id: e.target.value })} className={`${inputCls} col-span-2`}>
                    <option value="">— tidak terhubung —</option>
                    {stockItems.map((s) => <option key={s.id} value={s.id}>{s.name} ({s.unit})</option>)}
                  </select>
                  <input type="number" step="0.01" min="0" title="Pemakaian bahan per 1 unit" value={form.stock_qty_per_unit} onChange={(e) => setForm({ ...form, stock_qty_per_unit: e.target.value })} className={inputCls} />
                </div>
                <p className="text-xs text-char/40 mt-1">Kolom kanan = jumlah bahan terpakai per 1 porsi (mis. 0.15 kg beras).</p>
              </div>
              <div className="flex gap-5">
                <label className="flex items-center gap-2 text-sm font-semibold">
                  <input type="checkbox" checked={form.is_available} onChange={(e) => setForm({ ...form, is_available: e.target.checked })} className="accent-chili w-4 h-4" />
                  Tersedia hari ini
                </label>
                <label className="flex items-center gap-2 text-sm font-semibold">
                  <input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} className="accent-chili w-4 h-4" />
                  Aktif
                </label>
              </div>
            </div>

            <div className="flex gap-3 mt-7">
              <button onClick={() => setForm(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={saveProduct} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Simpan</button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
