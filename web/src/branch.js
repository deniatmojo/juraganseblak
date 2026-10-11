// Cabang aktif (dipilih owner/admin tak terkunci di header). Disimpan per browser;
// nilai: id cabang (string) atau 'all' (hanya untuk melihat laporan gabungan).
const KEY = 'erp_branch'

export function getBranch() {
  try {
    return localStorage.getItem(KEY) || ''
  } catch {
    return ''
  }
}

export function setBranch(value) {
  try {
    if (value) localStorage.setItem(KEY, String(value))
    else localStorage.removeItem(KEY)
  } catch { /* storage diblokir: pilihan hanya berlaku sesi ini */ }
  window.dispatchEvent(new Event('branchchange'))
}
