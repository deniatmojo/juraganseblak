import { jsPDF } from 'jspdf'

export const fmtRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

// Generator PDF laporan keuangan, gaya laporan laba rugi klasik:
// judul seksi rata kiri, item rincian menjorok, subtotal menonjol, tanpa garis border.
// blocks: [{ heading?, rows: [{ label, value, strong?, negative?, sub? }] }]
export function reportPdf({ title, subtitle, from, to, blocks, filename }) {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  const W = 210
  const RIGHT = W - 16
  let y = 0

  const header = () => {
    doc.setFillColor(22, 17, 15)
    doc.rect(0, 0, W, 24, 'F')
    doc.setTextColor(250, 243, 236)
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(14)
    doc.text('JURAGAN SEBLAK', 14, 11)
    doc.setFontSize(8)
    doc.setFont('helvetica', 'normal')
    doc.text('Laporan Keuangan', 14, 17)
    doc.setTextColor(249, 115, 22)
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(11)
    doc.text(title, W - 14, 11, { align: 'right' })
    doc.setTextColor(250, 243, 236)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(8)
    doc.text(`Periode: ${from.split('-').reverse().join('/')} s/d ${to.split('-').reverse().join('/')}`, W - 14, 17, { align: 'right' })
    y = 34
  }

  const newPageIfNeeded = (need = 8) => {
    if (y + need > 280) {
      doc.addPage()
      header()
    }
  }

  header()

  doc.setTextColor(22, 17, 15)
  for (const block of blocks) {
    if (block.heading) {
      newPageIfNeeded(16)
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(10)
      doc.setFillColor(250, 243, 236)
      doc.rect(14, y - 4, W - 28, 7.5, 'F')
      doc.text(block.heading, 16, y + 0.5)
      y += 11
    }
    for (const row of block.rows) {
      newPageIfNeeded(10)
      // Hierarki indent: normal 16mm, sub-item 24mm (menjorok dalam).
      const x = row.sub ? 24 : 16
      doc.setFont('helvetica', row.strong ? 'bold' : 'normal')
      doc.setFontSize(row.strong ? 10 : 9)
      if (row.negative) doc.setTextColor(200, 30, 15)
      else doc.setTextColor(22, 17, 15)
      doc.text(String(row.label), x, y)
      // jsPDF font standar (WinAnsi) tidak punya glyph U+2212 — wajib pakai minus ASCII.
      const val = (row.negative && row.value > 0 ? '- ' : '') + (typeof row.value === 'number' ? fmtRp(Math.abs(row.value)) : String(row.value ?? '-'))
      doc.text(val, RIGHT - (row.sub ? 6 : 0), y, { align: 'right' })
      y += row.strong ? 7 : 5.5
    }
    if (block.rule) {
      doc.setDrawColor(225)
      doc.setLineWidth(0.2)
      doc.line(14, y - 1.5, W - 14, y - 1.5)
      y += 2.5
    }
    y += 1.5
  }

  // Footer nomor halaman
  const pages = doc.getNumberOfPages()
  for (let i = 1; i <= pages; i++) {
    doc.setPage(i)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(7)
    doc.setTextColor(150)
    doc.text(`Dicetak ${new Date().toLocaleString('id-ID')} - Halaman ${i}/${pages}`, W / 2, 291, { align: 'center' })
  }

  doc.save(filename)
}
