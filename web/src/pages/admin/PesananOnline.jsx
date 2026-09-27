import { useCallback, useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import QRCode from 'qrcode'
import { api } from '../../api'

const rupiah = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID')

const PROGRESS_LABEL = {
  queue: 'Antrian',
  processing: 'Diproses',
  ready: 'Siap/Diantar',
  done: 'Selesai',
}

const TYPE_LABEL = { dinein: 'Dine-In', delivery: 'Delivery', pickup: 'Ambil di Tempat' }

// Tombol tahap berikutnya sesuai alur: antrian > diproses > siap/diantar > selesai.
const NEXT_STEP = { queue: 'processing', processing: 'ready', ready: 'done' }
const NEXT_LABEL = {
  processing: 'Proses Dapur',
  ready: 'Siap/Diantar',
  done: 'Tandai Selesai',
}

function OrderCard({ order, onAcc, onCancel, onProgress, busy }) {
  const isPending = order.status === 'pending'
  const nextKey = NEXT_STEP[order.progress || 'queue']
  return (
    <div className="bg-white rounded-2xl border border-black/5 shadow-sm p-5 space-y-3">
      <div className="flex items-start justify-between gap-3 flex-wrap">
        <div className="min-w-0">
          <p className="font-display text-lg">{order.order_no}</p>
          <p className="text-xs text-char/50">
            {new Date(order.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
            {' · '}{TYPE_LABEL[order.order_type] || 'Online'}
            {order.progress && ` · ${PROGRESS_LABEL[order.progress]}`}
          </p>
          {order.table_no && (
            <p className="inline-block mt-1 bg-ember text-char text-[11px] font-bold px-2.5 py-0.5 rounded-full">🪑 Meja {order.table_no} — antar ke sini</p>
          )}
        </div>
        <span className={`font-bold text-sm shrink-0 ${isPending ? 'text-amber-600' : order.status === 'canceled' ? 'text-char/40 line-through' : 'text-chili'}`}>
          {rupiah(order.total)}
        </span>
      </div>

      <div className="text-sm space-y-0.5">
        <p><span className="font-semibold">{order.customer_name || '—'}</span> · {order.customer_phone || '—'}</p>
        {order.schedule_at && <p className="text-char/60 text-xs">📅 {new Date(order.schedule_at).toLocaleString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' })}</p>}
        {order.delivery_address && <p className="text-char/60 text-xs">📍 {order.delivery_address}</p>}
        {order.customer_note && <p className="text-char/60 text-xs">📝 {order.customer_note}</p>}
        <p className="text-char/70 text-xs pt-1">{order.items_preview || '-'}</p>
      </div>

      <div className="flex flex-wrap gap-2 pt-1">
        {isPending && (
          <>
            <button
              onClick={() => onAcc(order)}
              disabled={busy}
              className="flex-1 min-w-32 bg-chili hover:bg-chili-dark disabled:opacity-50 text-white font-bold text-sm py-2.5 rounded-xl transition-colors"
            >
              ACC Pembayaran
            </button>
            <button
              onClick={() => onCancel(order)}
              disabled={busy}
              className="border border-black/10 hover:border-chili hover:text-chili font-bold text-sm py-2.5 px-4 rounded-xl transition-colors"
            >
              Tolak
            </button>
          </>
        )}
        {order.status === 'paid' && nextKey && (
          <button
            onClick={() => onProgress(order, nextKey)}
            disabled={busy}
            className="flex-1 min-w-32 bg-char hover:bg-char-soft disabled:opacity-50 text-white font-bold text-sm py-2.5 rounded-xl transition-colors"
          >
            {NEXT_LABEL[nextKey] || 'Lanjut'}
          </button>
        )}
        {order.status === 'paid' && (
          <button
            onClick={() => onCancel(order)}
            disabled={busy}
            className="border border-black/10 hover:border-chili hover:text-chili font-bold text-sm py-2.5 px-4 rounded-xl transition-colors"
          >
            Batalkan
          </button>
        )}
      </div>
    </div>
  )
}

// Kartu QR satu meja (tampilan layar admin).
function TableQrCard({ table, qrUrl, busy, onRename, onToggle, onDelete }) {
  return (
    <div className={`bg-white rounded-2xl border border-black/5 shadow-sm p-5 flex flex-col items-center gap-3 text-center ${!table.is_active ? 'opacity-50' : ''}`}>
      {qrUrl && <img src={qrUrl} alt={`QR Meja ${table.label}`} className="w-36 h-36" />}
      <div>
        <p className="font-display text-xl">🪑 Meja {table.label}</p>
        {!table.is_active && <p className="text-xs text-chili font-bold mt-0.5">Nonaktif — QR tidak bisa dipakai</p>}
      </div>
      <div className="flex flex-wrap gap-2 justify-center">
        <button onClick={() => onRename(table)} disabled={busy} className="text-xs font-bold border border-black/10 rounded-lg px-3 py-1.5 hover:border-chili hover:text-chili transition-colors">Ganti Nama</button>
        <button onClick={() => onToggle(table)} disabled={busy} className="text-xs font-bold border border-black/10 rounded-lg px-3 py-1.5 hover:border-chili hover:text-chili transition-colors">{table.is_active ? 'Nonaktifkan' : 'Aktifkan'}</button>
        <button onClick={() => onDelete(table)} disabled={busy} className="text-xs font-bold border border-black/10 rounded-lg px-3 py-1.5 hover:border-chili hover:text-chili transition-colors">Hapus</button>
      </div>
    </div>
  )
}

// Lembar cetak: semua QR meja aktif, satu kartu per meja siap potong-tempel.
function TableQrPrintSheet({ tables, qrUrls }) {
  return (
    <div className="hidden print:block">
      <h1 className="font-display text-3xl text-center uppercase mb-1">Juragan Seblak</h1>
      <p className="text-center text-sm mb-6">Scan QR di bawah untuk memesan dari meja</p>
      <div className="grid grid-cols-2 gap-8">
        {tables.filter((t) => t.is_active).map((t) => (
          <div key={t.id} className="break-inside-avoid border-2 border-black rounded-2xl p-6 text-center">
            <p className="font-display text-2xl uppercase mb-3">🪑 Meja {t.label}</p>
            {qrUrls[t.id] && <img src={qrUrls[t.id]} alt={`QR Meja ${t.label}`} className="w-48 h-48 mx-auto" />}
            <p className="text-xs mt-3">1. Scan QR dengan kamera HP</p>
            <p className="text-xs">2. Pilih menu & kirim pesanan</p>
            <p className="text-xs">3. Bayar di meja — pesanan diantar ke meja {t.label}</p>
          </div>
        ))}
      </div>
    </div>
  )
}

// Tab QR Meja: kelola daftar meja + QR per meja untuk ditempel di meja.
function QrMejaView() {
  const [tables, setTables] = useState([])
  const [qrUrls, setQrUrls] = useState({})
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [newLabel, setNewLabel] = useState('')
  const [error, setError] = useState('')

  const load = useCallback(() => {
    return api.get('/online/tables')
      .then(setTables)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { load() }, [load])

  // QR dibuat client-side dari origin aktif — di lokal berisi localhost,
  // di produksi otomatis berisi domain produksi.
  useEffect(() => {
    let cancelled = false
    const base = window.location.origin
    Promise.all(tables.map(async (t) => {
      const url = `${base}/order?meja=${t.id}`
      const dataUrl = await QRCode.toDataURL(url, { width: 300, margin: 1 })
      return [t.id, dataUrl]
    }))
      .then((pairs) => { if (!cancelled) setQrUrls(Object.fromEntries(pairs)) })
      .catch(() => {})
    return () => { cancelled = true }
  }, [tables])

  const run = async (fn) => {
    setBusy(true)
    try {
      await fn()
      await load()
      setError('')
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(false)
    }
  }

  const add = (e) => {
    e.preventDefault()
    const label = newLabel.trim()
    if (!label) return
    return run(async () => {
      await api.post('/online/tables', { label })
      setNewLabel('')
    })
  }
  const rename = (t) => {
    const label = window.prompt(`Ganti nama meja "${t.label}" menjadi:`, t.label)
    if (!label || !label.trim() || label.trim() === t.label) return
    return run(() => api.patch(`/online/tables/${t.id}`, { label: label.trim() }))
  }
  const toggle = (t) => run(() => api.patch(`/online/tables/${t.id}`, { is_active: t.is_active ? 0 : 1 }))
  const remove = (t) => {
    if (!window.confirm(`Hapus Meja ${t.label}? QR yang sudah ditempel di meja akan tidak valid.`)) return
    return run(() => api.del(`/online/tables/${t.id}`))
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3 print:hidden">
        <p className="text-sm text-char/60">
          Setiap meja punya QR sendiri — tempel di meja, pembeli cukup scan, pesan, dan bayar di tempat.
          Pelayan melihat nomor meja di daftar pesanan.
        </p>
        <button
          onClick={() => window.print()}
          disabled={loading || tables.filter((t) => t.is_active).length === 0}
          className="bg-char hover:bg-char-soft text-white font-bold text-sm py-2.5 px-5 rounded-xl transition-colors disabled:opacity-50"
        >
          🖨️ Cetak Semua QR
        </button>
      </div>

      {error && <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm font-semibold print:hidden">{error}</div>}

      <form onSubmit={add} className="flex gap-3 print:hidden">
        <input
          type="text"
          value={newLabel}
          onChange={(e) => setNewLabel(e.target.value)}
          placeholder="Nama meja baru, mis. 9 / Teras-1 / VIP-2"
          className="flex-1 border border-black/15 rounded-xl px-4 py-3 text-sm"
        />
        <button type="submit" disabled={busy || !newLabel.trim()} className="bg-chili hover:bg-chili-dark disabled:opacity-50 text-white font-bold text-sm px-6 rounded-xl transition-colors">
          + Tambah Meja
        </button>
      </form>

      {loading ? (
        <p className="text-char/40 text-sm print:hidden">Memuat…</p>
      ) : tables.length === 0 ? (
        <p className="text-char/40 text-sm bg-white border border-black/5 rounded-2xl p-6 print:hidden">Belum ada meja. Tambahkan meja pertama di atas.</p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 print:hidden">
          {tables.map((t) => (
            <TableQrCard key={t.id} table={t} qrUrl={qrUrls[t.id]} busy={busy} onRename={rename} onToggle={toggle} onDelete={remove} />
          ))}
        </div>
      )}

      <TableQrPrintSheet tables={tables} qrUrls={qrUrls} />
    </div>
  )
}

export default function PesananOnline() {
  const { user } = useOutletContext()
  const [view, setView] = useState('orders') // 'orders' | 'tables'
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const load = useCallback(() => {
    return api.get('/orders')
      .then((rows) => {
        setOrders(rows.filter((r) => r.channel === 'online'))
        setError('')
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    load()
    // Daftar pesanan online menyala terus: refresh otomatis tiap 15 detik.
    const timer = setInterval(load, 15_000)
    return () => clearInterval(timer)
  }, [load])

  const run = async (fn) => {
    setBusy(true)
    try {
      await fn()
      await load()
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(false)
    }
  }

  const accPayment = (order) => run(() => api.post('/payments/confirm-manual', { order_id: order.id }))
  const setProgress = (order, progress) => run(() => api.patch('/online/progress', { order_id: order.id, progress }))
  const cancel = (order) => {
    const reason = window.prompt(`Alasan menolak/batalkan ${order.order_no}:`)
    if (!reason || !reason.trim()) return
    return run(() => api.post(`/orders/${order.id}/void`, { reason: reason.trim() }))
  }

  const pending = orders.filter((o) => o.status === 'pending')
  const inProgress = orders.filter((o) => o.status === 'paid' && o.progress !== 'done')
  const finished = orders.filter((o) => (o.status === 'paid' && o.progress === 'done') || o.status === 'canceled')

  const Section = ({ title, hint, count, accent, children }) => (
    <section className="space-y-4">
      <div className="flex items-baseline gap-3">
        <h2 className="font-display text-2xl uppercase">{title}</h2>
        <span className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${accent}`}>{count}</span>
        {hint && <span className="text-xs text-char/40 hidden sm:block">{hint}</span>}
      </div>
      {children}
    </section>
  )

  return (
    <div className="p-5 md:p-8 space-y-10">
      <div className="flex gap-2 print:hidden">
        {[
          { key: 'orders', label: '📋 Pesanan' },
          { key: 'tables', label: '🪑 QR Meja' },
        ].map((t) => (
          <button
            key={t.key}
            onClick={() => setView(t.key)}
            className={`font-bold text-sm px-5 py-2.5 rounded-full border transition-colors ${view === t.key ? 'bg-chili text-white border-chili' : 'bg-white text-char/60 border-black/10 hover:border-chili'}`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {view === 'tables' ? (
        <QrMejaView />
      ) : (
        <>
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm font-semibold">{error}</div>
      )}

      <Section title="Menunggu ACC" hint="cek rekening/QRIS, lalu ACC — otomatis masuk antrian" count={pending.length} accent="bg-amber-100 text-amber-700">
        {loading ? (
          <p className="text-char/40 text-sm">Memuat…</p>
        ) : pending.length === 0 ? (
          <p className="text-char/40 text-sm bg-white border border-black/5 rounded-2xl p-6">Tidak ada pesanan menunggu konfirmasi 👍</p>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {pending.map((o) => <OrderCard key={o.id} order={o} onAcc={accPayment} onCancel={cancel} onProgress={setProgress} busy={busy} />)}
          </div>
        )}
      </Section>

      <Section title="Antrian & Diproses" hint="update tahap pesanan sampai selesai" count={inProgress.length} accent="bg-chili/10 text-chili">
        {inProgress.length === 0 ? (
          <p className="text-char/40 text-sm bg-white border border-black/5 rounded-2xl p-6">Antrian kosong.</p>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {inProgress.map((o) => <OrderCard key={o.id} order={o} onAcc={accPayment} onCancel={cancel} onProgress={setProgress} busy={busy} />)}
          </div>
        )}
      </Section>

      <Section title="Selesai & Dibatalkan" count={finished.length} accent="bg-black/5 text-char/60">
        {finished.length === 0 ? (
          <p className="text-char/40 text-sm bg-white border border-black/5 rounded-2xl p-6">Belum ada riwayat.</p>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {finished.map((o) => <OrderCard key={o.id} order={o} onAcc={accPayment} onCancel={cancel} onProgress={setProgress} busy={busy} />)}
          </div>
        )}
      </Section>

      <p className="text-xs text-char/40">
        Login sebagai <strong>{user?.name}</strong> · daftar menyegarkan sendiri tiap 15 detik.
      </p>
        </>
      )}
    </div>
  )
}
