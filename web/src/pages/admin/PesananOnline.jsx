import { useCallback, useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
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

export default function PesananOnline() {
  const { user } = useOutletContext()
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
    </div>
  )
}
