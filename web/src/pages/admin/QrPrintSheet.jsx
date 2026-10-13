import { createPortal } from 'react-dom'

// Lembar cetak QR meja, satu halaman A5 (148×210 mm) per meja. Di-render lewat
// portal ke <body> (id #qrPrintArea) supaya tidak ikut tersembunyi oleh aturan
// cetak struk termal; tampil hanya saat body.print-qr aktif (lihat index.css).
// Label meja sering sudah memuat nama cabang ("Juragan Seblak Prasmanan 2 - Meja A"):
// bagian terakhir jadi nama besar, sisanya jadi keterangan cabang.
function splitLabel(table) {
  const parts = String(table.label).split(/\s[-–—]\s/).map((p) => p.trim()).filter(Boolean)
  const main = parts.length ? parts[parts.length - 1] : String(table.label)
  const rest = parts.slice(0, -1).join(' · ')
  return {
    title: /^meja\b/i.test(main) ? main : `Meja ${main}`,
    sub: rest || table.branch_name || '',
  }
}

const STEPS = [
  ['Scan', 'QR dengan kamera HP'],
  ['Pilih', 'menu & kirim pesanan'],
  ['Bayar', 'di meja, kasir kami ACC'],
]

export default function QrPrintSheet({ tables, qrUrls }) {
  const host = typeof window !== 'undefined' ? window.location.host : ''
  return createPortal(
    <div id="qrPrintArea">
      {tables.map((t) => {
        const { title, sub } = splitLabel(t)
        return (
          <section key={t.id} className="qr-page">
            <div className="qr-band">
              <i className="qr-dot qr-dot-a" />
              <i className="qr-dot qr-dot-b" />
              <img className="qr-logo" src="/images/logo-juragan.png" alt="Juragan Seblak" />
              <p className="qr-brand">JURAGAN SEBLAK</p>
              <p className="qr-tag">Seblak Prasmanan • Racik Sendiri, Puas Sendiri</p>
            </div>

            <div className="qr-card">
              <p className="qr-scan">SCAN &amp; PESAN DARI MEJA</p>
              <div className="qr-frame">
                {qrUrls[t.id] && <img src={qrUrls[t.id]} alt={`QR ${title}`} />}
              </div>
              <p className="qr-table">{title}</p>
              {sub && <p className="qr-branch">{sub}</p>}
            </div>

            <ol className="qr-steps">
              {STEPS.map(([head, text], i) => (
                <li key={head}>
                  <b>{i + 1}</b>
                  <span><strong>{head}</strong> {text}</span>
                </li>
              ))}
            </ol>

            <p className="qr-foot">Terima kasih sudah makan di Juragan Seblak 🌶️ · {host}</p>
          </section>
        )
      })}
    </div>,
    document.body,
  )
}
