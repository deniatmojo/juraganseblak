// Filter rentang tanggal preset + custom (dipakai modul Keuangan).
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

export function rangePreset(kind) {
  const now = new Date()
  if (kind === 'today') return { from: iso(now), to: iso(now) }
  if (kind === 'week') {
    const from = new Date(now); from.setDate(now.getDate() - 6)
    return { from: iso(from), to: iso(now) }
  }
  if (kind === 'month') {
    const from = new Date(now.getFullYear(), now.getMonth(), 1)
    return { from: iso(from), to: iso(now) }
  }
  if (kind === 'lastmonth') {
    const from = new Date(now.getFullYear(), now.getMonth() - 1, 1)
    const to = new Date(now.getFullYear(), now.getMonth(), 0)
    return { from: iso(from), to: iso(to) }
  }
  if (kind === 'year') {
    const from = new Date(now.getFullYear(), 0, 1)
    return { from: iso(from), to: iso(now) }
  }
  return null
}

const PRESETS = [
  ['today', 'Hari Ini'],
  ['week', '7 Hari Terakhir'],
  ['month', 'Bulan Ini'],
  ['lastmonth', 'Bulan Lalu'],
  ['year', 'Tahun Ini'],
  ['custom', 'Rentang Custom'],
]

export default function RangeFilter({ preset, onPreset, from, to, onFrom, onTo }) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      {PRESETS.map(([k, label]) => (
        <button
          key={k}
          onClick={() => onPreset(k)}
          className={`text-xs font-bold px-3.5 py-2 rounded-full transition-colors ${preset === k ? 'bg-char text-white' : 'bg-cream text-char/60 hover:bg-cream/70'}`}
        >
          {label}
        </button>
      ))}
      {preset === 'custom' && (
        <span className="flex items-center gap-2">
          <input type="date" value={from} onChange={(e) => onFrom(e.target.value)} className="border border-black/15 rounded-full px-3 py-1.5 text-xs" />
          <span className="text-char/40 text-xs">s/d</span>
          <input type="date" value={to} onChange={(e) => onTo(e.target.value)} className="border border-black/15 rounded-full px-3 py-1.5 text-xs" />
        </span>
      )}
    </div>
  )
}
