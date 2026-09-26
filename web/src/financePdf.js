import { jsPDF } from 'jspdf'

export const fmtRp = (num) => 'Rp ' + Math.round(num).toLocaleString('id-ID')

// Generator PDF laporan keuangan. blocks: [{ heading?, rows: [{ label, value, strong?, negative?, sub? }] }]
export function reportPdf({ title, subtitle, from, to, blocks, filename }) {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  const W = 210
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
    if (subtitle) doc.text(subtitle, W - 14, 22, { align: 'right' })
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
      doc.text(block.heading, 14, y)
      y += 3
      doc.setDrawColor(200)
      doc.line(14, y, W - 14, y)
      y += 6
    }
    for (const row of block.rows) {
      newPageIfNeeded(10)
      const indent = row.sub ? 8 : 0
      doc.setFont('helvetica', row.strong ? 'bold' : 'normal')
      doc.setFontSize(row.strong ? 10 : 9)
      if (row.negative) doc.setTextColor(200, 30, 15)
      else doc.setTextColor(22, 17, 15)
      doc.text(String(row.label), 14 + indent, y)
      const val = (row.negative && row.value > 0 ? '− ' : '') + (typeof row.value === 'number' ? fmtRp(Math.abs(row.value)) : String(row.value ?? '—'))
      doc.text(val, W - 14 - indent, y, { align: 'right' })
      y += row.strong ? 7 : 5.5
    }
    if (block.rule) {
      doc.setDrawColor(160)
      doc.line(14, y - 2, W - 14, y - 2)
      y += 3
    }
    y += 2
  }

  // Footer nomor halaman
  const pages = doc.getNumberOfPages()
  for (let i = 1; i <= pages; i++) {
    doc.setPage(i)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(7)
    doc.setTextColor(150)
    doc.text(`Dicetak ${new Date().toLocaleString('id-ID')} · Halaman ${i}/${pages}`, W / 2, 291, { align: 'center' })
  }

  doc.save(filename)
}
