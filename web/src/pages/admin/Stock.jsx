import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { api } from '../../api'

const inputCls = 'w-full bg-white border border-black/15 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30 focus:border-chili'
const formatRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

const MOVE_BADGE = {
  in: ['Masuk', 'text-green-700 bg-green-50'],
  out: ['Keluar', 'text-chili bg-red-50'],
  adjust: ['Opname', 'text-ember bg-ember/10'],
  transfer_in: ['Transfer masuk', 'text-blue-700 bg-blue-50'],
  transfer_out: ['Transfer keluar', 'text-blue-700 bg-blue-50'],
}

export default function Stock() {
  const { user, branches = [], branch = '' } = useOutletContext() ?? {}
  // Admin yang dikunci ke satu cabang tidak boleh memilih cabang lain.
  const lockedBranch = user?.role === 'admin' && user?.branch_id ? String(user.branch_id) : ''
  const branchName = (id) => branches.find((b) => String(b.id) === String(id))?.name ?? '-'
  // Cabang bawaan untuk form: cabang aktif di header, bila 'semua' → cabang pertama.
  const defaultBranch = lockedBranch || (branch && branch !== 'all' ? branch : String(branches[0]?.id ?? ''))
  const [transferForm, setTransferForm] = useState(null) // { item, from, to, qty, note }
  const [overview, setOverview] = useState(null)         // matriks bahan × cabang
  const [stockItems, setStockItems] = useState([])
  const [movements, setMovements] = useState([])
  const [error, setError] = useState('')
  const [moveForm, setMoveForm] = useState(null)   // { item, type, qty, note }
  const [addForm, setAddForm] = useState(null)     // { name, category, unit, qty, min_qty }

  const load = () => {
    Promise.all([api.get('/stock'), api.get('/stock/movements?limit=10')])
      .then(([items, moves]) => {
        setStockItems(items)
        setMovements(moves)
      })
      .catch((e) => setError(e.message))
  }

  useEffect(load, [])

  const openMove = (item, type) => setMoveForm({ item, type, qty: '', note: '', unit_cost: '', branch_id: defaultBranch })
  const openAdd = () => setAddForm({ name: '', category: 'Protein', unit: 'kg', qty: '', min_qty: '', unit_cost: '', branch_id: defaultBranch })
  const openTransfer = (item) => {
    const from = defaultBranch
    const to = String(branches.find((b) => String(b.id) !== from)?.id ?? '')
    setTransferForm({ item, from, to, qty: '', note: '' })
  }
  const toggleOverview = () => {
    if (overview) { setOverview(null); return }
    api.get('/stock/overview').then(setOverview).catch((e) => setError(e.message))
  }

  const saveTransfer = async () => {
    try {
      await api.post('/stock/transfer', {
        item_id: transferForm.item.id,
        from_branch_id: Number(transferForm.from),
        to_branch_id: Number(transferForm.to),
        qty: Number(transferForm.qty),
        note: transferForm.note || null,
      })
      setTransferForm(null)
      setError('')
      load()
      if (overview) api.get('/stock/overview').then(setOverview).catch(() => {})
    } catch (e) {
      setError(e.message)
    }
  }

  const saveMove = async () => {
    try {
      await api.post(`/stock/${moveForm.item.id}/move`, {
        type: moveForm.type,
        qty: Number(moveForm.qty),
        note: moveForm.note || null,
        unit_cost: Number(moveForm.unit_cost || 0),
        branch_id: Number(moveForm.branch_id),
      })
      setMoveForm(null)
      load()
    } catch (e) {
      setError(e.message)
    }
  }

  const saveAdd = async () => {
    try {
      await api.post('/stock', {
        name: addForm.name,
        category: addForm.category,
        unit: addForm.unit,
        qty: Number(addForm.qty || 0),
        min_qty: Number(addForm.min_qty || 0),
        unit_cost: Number(addForm.unit_cost || 0),
        branch_id: Number(addForm.branch_id),
      })
      setAddForm(null)
      load()
    } catch (e) {
      setError(e.message)
    }
  }

  const criticalCount = stockItems.filter((i) => i.is_low).length

  const summary = [
    { value: stockItems.length, label: 'Total Jenis Bahan', iconCls: 'bg-char/5', color: 'text-char', icon: 'M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4' },
    { value: criticalCount, label: 'Stok Kritis', iconCls: 'bg-red-50', color: 'text-chili', icon: 'M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z' },
    { value: stockItems.length - criticalCount, label: 'Stok Aman', iconCls: 'bg-green-50', color: 'text-green-600', icon: 'M5 13l4 4L19 7' },
  ]

  const moveTitle = { in: 'Barang Masuk (Restock)', out: 'Barang Keluar (Waste/Pakai)', adjust: 'Set Stok (Stok Opname)' }

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {error && <p className="text-xs font-bold text-chili bg-red-50 rounded-xl px-4 py-3">{error}</p>}

      <div className="flex flex-wrap items-center gap-3 bg-white rounded-2xl border border-black/5 px-5 py-3.5">
        <span className="text-xs font-bold text-char/50 uppercase">Stok cabang</span>
        <span className="font-bold">{branch === 'all' || !branch ? 'Semua cabang (total gabungan)' : branchName(branch || lockedBranch)}</span>
        {(branch === 'all' || !branch) && !lockedBranch && (
          <span className="text-xs text-char/50">Tampilan total. Saat mencatat stok, pilih cabang tujuan di form.</span>
        )}
        {branches.length > 1 && (
          <button onClick={toggleOverview} className="ml-auto text-xs font-bold border border-black/15 hover:border-char px-4 py-2 rounded-full">
            {overview ? 'Sembunyikan' : 'Lihat'} stok semua cabang
          </button>
        )}
      </div>

      {overview && (
        <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
          <div className="px-6 py-5 border-b border-black/5"><h2 className="font-bold">Stok per Cabang</h2></div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                  <th className="px-6 py-3 font-bold">Bahan</th>
                  {overview.branches.map((b) => <th key={b.id} className="px-6 py-3 font-bold">{b.name}</th>)}
                </tr>
              </thead>
              <tbody className="divide-y divide-black/5">
                {overview.items.map((it) => (
                  <tr key={it.id}>
                    <td className="px-6 py-3 font-semibold">{it.name}</td>
                    {overview.branches.map((b) => {
                      const c = it.per_branch[b.id]
                      return (
                        <td key={b.id} className={`px-6 py-3 ${c.is_low ? 'text-chili font-bold' : ''}`}>{c.qty} {it.unit}</td>
                      )
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

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
          <button onClick={openAdd} className="text-xs font-bold text-white bg-chili hover:bg-chili-dark px-5 py-2.5 rounded-full">+ Bahan Baru</button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[900px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Bahan Baku</th>
                <th className="px-6 py-3 font-bold">Kategori</th>
                <th className="px-6 py-3 font-bold">Sisa Stok</th>
                <th className="px-6 py-3 font-bold">Batas Minimum</th>
                <th className="px-6 py-3 font-bold">Harga Rata-rata</th>
                <th className="px-6 py-3 font-bold">Status</th>
                <th className="px-6 py-3 font-bold text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {stockItems.length === 0 && (
                <tr><td colSpan={7} className="px-6 py-8 text-center text-char/40">Belum ada bahan.</td></tr>
              )}
              {stockItems.map((item) => {
                const pct = Math.min(100, Math.round((item.qty / Math.max(item.min_qty * 2, 0.001)) * 100))
                return (
                  <tr key={item.id} className="hover:bg-cream/60 transition-colors">
                    <td className="px-6 py-4 font-semibold">{item.name}</td>
                    <td className="px-6 py-4 text-char/60">{item.category}</td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <span className="font-semibold w-20">{item.qty} {item.unit}</span>
                        <div className="w-20 h-1.5 bg-black/5 rounded-full overflow-hidden hidden sm:block">
                          <div className={`stock-bar-fill h-full ${item.is_low ? 'bg-chili' : 'bg-green-500'}`} style={{ width: `${pct}%` }}></div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-char/60">{item.min_qty} {item.unit}</td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {item.unit_cost > 0 ? (
                        <span className="font-semibold">{formatRp(item.unit_cost)}<span className="text-char/40 font-normal">/{item.unit}</span></span>
                      ) : (
                        <span className="text-char/30">belum diatur</span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      {item.is_low ? (
                        <span className="text-xs font-bold text-chili bg-red-50 px-2.5 py-1 rounded-full">Kritis</span>
                      ) : (
                        <span className="text-xs font-bold text-green-700 bg-green-50 px-2.5 py-1 rounded-full">Aman</span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-right space-x-2 whitespace-nowrap">
                      <button onClick={() => openMove(item, 'in')} className="text-xs font-bold text-white bg-char hover:bg-char-soft px-4 py-2 rounded-full">+ Masuk</button>
                      <button onClick={() => openMove(item, 'out')} className="text-xs font-bold text-chili bg-red-50 hover:bg-red-100 px-4 py-2 rounded-full">− Keluar</button>
                      <button onClick={() => openMove(item, 'adjust')} className="text-xs font-bold text-char/70 hover:text-char underline">Opname</button>
                      {branches.length > 1 && (
                        <button onClick={() => openTransfer(item)} className="text-xs font-bold text-blue-700 bg-blue-50 hover:bg-blue-100 px-4 py-2 rounded-full">⇄ Transfer</button>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* RIWAYAT PERGERAKAN */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="px-6 py-5 border-b border-black/5">
          <h2 className="font-bold">Pergerakan Terakhir</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[640px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Waktu</th>
                <th className="px-6 py-3 font-bold">Bahan</th>
                <th className="px-6 py-3 font-bold">Cabang</th>
                <th className="px-6 py-3 font-bold">Tipe</th>
                <th className="px-6 py-3 font-bold">Qty</th>
                <th className="px-6 py-3 font-bold">Catatan</th>
                <th className="px-6 py-3 font-bold">Oleh</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {movements.length === 0 && (
                <tr><td colSpan={7} className="px-6 py-8 text-center text-char/40">Belum ada pergerakan stok.</td></tr>
              )}
              {movements.map((m) => (
                <tr key={m.id} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4 text-char/60 whitespace-nowrap">{new Date(m.created_at).toLocaleString('id-ID', { dateStyle: 'short', timeStyle: 'short' })}</td>
                  <td className="px-6 py-4 font-semibold">{m.item_name}</td>
                  <td className="px-6 py-4 text-char/60">{m.branch_name || '-'}</td>
                  <td className="px-6 py-4">
                    {MOVE_BADGE[m.type] && <span className={`text-xs font-bold px-2.5 py-1 rounded-full whitespace-nowrap ${MOVE_BADGE[m.type][1]}`}>{MOVE_BADGE[m.type][0]}</span>}
                  </td>
                  <td className="px-6 py-4 font-semibold">{m.qty}</td>
                  <td className="px-6 py-4 text-char/60">{m.note || '-'}</td>
                  <td className="px-6 py-4 text-char/60">{m.by_name || 'Sistem'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL MUTASI (masuk/keluar/opname) */}
      {moveForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setMoveForm(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">{moveTitle[moveForm.type]}</h2>
            <p className="text-char/50 text-sm mb-6">{moveForm.item.name}{branch && branch !== 'all' ? ` — saat ini ${moveForm.item.qty} ${moveForm.item.unit}` : ''}</p>

            <label className="block text-sm font-bold mb-1.5">Cabang {moveForm.type === 'in' ? '(dialokasikan ke)' : ''}</label>
            <select
              value={moveForm.branch_id}
              disabled={Boolean(lockedBranch)}
              onChange={(e) => setMoveForm({ ...moveForm, branch_id: e.target.value })}
              className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-4 bg-white focus:outline-none focus:ring-2 focus:ring-chili/30"
            >
              {branches.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
            </select>

            <label className="block text-sm font-bold mb-1.5">
              {moveForm.type === 'adjust' ? 'Jumlah Stok Hasil Opname' : moveForm.type === 'in' ? 'Jumlah Masuk' : 'Jumlah Keluar'}
            </label>
            <div className="flex items-center gap-2 mb-4">
              <input
                type="number"
                min="0"
                step="0.01"
                value={moveForm.qty}
                onChange={(e) => setMoveForm({ ...moveForm, qty: e.target.value })}
                className="flex-1 border border-black/15 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30"
              />
              <span className="text-sm font-bold text-char/50 w-14 shrink-0">{moveForm.item.unit}</span>
            </div>

            {moveForm.type === 'in' && (
              <>
                <label className="block text-sm font-bold mb-1.5">Harga Beli per {moveForm.item.unit} <span className="font-normal text-chili">*</span></label>
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-sm font-bold text-char/50 shrink-0">Rp</span>
                  <input
                    type="number"
                    min="0"
                    step="1"
                    placeholder="mis. 35000"
                    value={moveForm.unit_cost}
                    onChange={(e) => setMoveForm({ ...moveForm, unit_cost: e.target.value })}
                    className="flex-1 border border-black/15 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-chili/30"
                  />
                </div>
                {Number(moveForm.qty) > 0 && Number(moveForm.unit_cost) > 0 && (
                  <p className="text-xs font-bold text-ember mb-2">
                    Total pembelian: {formatRp(Number(moveForm.qty) * Number(moveForm.unit_cost))} — otomatis tercatat di Keuangan sebagai belanja bahan.
                  </p>
                )}
              </>
            )}

            <label className="block text-sm font-bold mb-1.5">Catatan <span className="font-normal text-char/40">(opsional)</span></label>
            <input
              type="text"
              placeholder={moveForm.type === 'in' ? 'Belanja dari supplier...' : ''}
              value={moveForm.note}
              onChange={(e) => setMoveForm({ ...moveForm, note: e.target.value })}
              className="w-full border border-black/15 rounded-xl px-4 py-3 text-sm mb-6 focus:outline-none focus:ring-2 focus:ring-chili/30"
            />

            <div className="flex gap-3">
              <button onClick={() => setMoveForm(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={saveMove} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Simpan</button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL TRANSFER ANTAR CABANG */}
      {transferForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setTransferForm(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-1">Transfer Stok</h2>
            <p className="text-char/50 text-sm mb-6">{transferForm.item.name} — pindahkan stok antar cabang</p>
            <label className="block text-sm font-bold mb-1.5">Dari cabang</label>
            <select value={transferForm.from} disabled={Boolean(lockedBranch)} onChange={(e) => setTransferForm({ ...transferForm, from: e.target.value })} className={`${inputCls} mb-4`}>
              {branches.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
            </select>
            <label className="block text-sm font-bold mb-1.5">Ke cabang</label>
            <select value={transferForm.to} onChange={(e) => setTransferForm({ ...transferForm, to: e.target.value })} className={`${inputCls} mb-4`}>
              {branches.filter((b) => String(b.id) !== transferForm.from).map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
            </select>
            <label className="block text-sm font-bold mb-1.5">Jumlah ({transferForm.item.unit})</label>
            <input type="number" min="0" step="0.01" value={transferForm.qty} onChange={(e) => setTransferForm({ ...transferForm, qty: e.target.value })} className={`${inputCls} mb-4`} />
            <label className="block text-sm font-bold mb-1.5">Catatan <span className="font-normal text-char/40">(opsional)</span></label>
            <input type="text" value={transferForm.note} onChange={(e) => setTransferForm({ ...transferForm, note: e.target.value })} className={`${inputCls} mb-2`} />
            <p className="text-xs text-char/40 mb-6">Transfer tidak dihitung sebagai pembelian maupun pemakaian — tidak memengaruhi kas atau HPP.</p>
            <div className="flex gap-3">
              <button onClick={() => setTransferForm(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={saveTransfer} disabled={!transferForm.to || !(Number(transferForm.qty) > 0)} className="flex-1 bg-chili hover:bg-chili-dark disabled:opacity-40 text-white font-bold py-3 rounded-full text-sm">Transfer</button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL BAHAN BARU */}
      {addForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-char/70 backdrop-blur-sm" onClick={() => setAddForm(null)}></div>
          <div className="relative bg-white rounded-2xl w-full max-w-sm p-7">
            <h2 className="font-display text-xl uppercase mb-6">Bahan Baru</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold mb-1.5">Stok awal untuk cabang</label>
                <select value={addForm.branch_id} disabled={Boolean(lockedBranch)} onChange={(e) => setAddForm({ ...addForm, branch_id: e.target.value })} className={inputCls}>
                  {branches.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1.5">Nama Bahan</label>
                <input type="text" value={addForm.name} onChange={(e) => setAddForm({ ...addForm, name: e.target.value })} className={inputCls} />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-bold mb-1.5">Kategori</label>
                  <select value={addForm.category} onChange={(e) => setAddForm({ ...addForm, category: e.target.value })} className={inputCls}>
                    {['Protein', 'Bumbu', 'Pokok', 'Pelengkap', 'Lain-lain'].map((c) => <option key={c}>{c}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-bold mb-1.5">Satuan</label>
                  <select value={addForm.unit} onChange={(e) => setAddForm({ ...addForm, unit: e.target.value })} className={inputCls}>
                    {['kg', 'gram', 'liter', 'ml', 'pcs', 'pack'].map((u) => <option key={u}>{u}</option>)}
                  </select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-bold mb-1.5">Stok Awal</label>
                  <input type="number" min="0" step="0.01" value={addForm.qty} onChange={(e) => setAddForm({ ...addForm, qty: e.target.value })} className={inputCls} />
                </div>
                <div>
                  <label className="block text-sm font-bold mb-1.5">Harga per {addForm.unit}</label>
                  <input type="number" min="0" step="1" placeholder="Rp" value={addForm.unit_cost} onChange={(e) => setAddForm({ ...addForm, unit_cost: e.target.value })} className={inputCls} />
                </div>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1.5">Batas Minimum</label>
                <input type="number" min="0" step="0.01" value={addForm.min_qty} onChange={(e) => setAddForm({ ...addForm, min_qty: e.target.value })} className={inputCls} />
              </div>
              <p className="text-xs text-char/40">Harga per unit dipakai untuk menilai persediaan &amp; menghitung HPP di laporan Laba Rugi. Stok awal tidak dihitung sebagai pembelian.</p>
            </div>
            <div className="flex gap-3 mt-7">
              <button onClick={() => setAddForm(null)} className="flex-1 border border-black/15 text-char font-bold py-3 rounded-full text-sm">Batal</button>
              <button onClick={saveAdd} className="flex-1 bg-chili hover:bg-chili-dark text-white font-bold py-3 rounded-full text-sm">Simpan</button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
