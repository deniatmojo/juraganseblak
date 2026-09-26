// Helper waktu WIB (UTC+7) — penanggalan bisnis (work_date, nomor order,
// ambang terlambat) harus mengikuti jam Indonesia Barat, bukan zona waktu
// mesin server (server produksi berjalan di UTC).

// getTime() sudah epoch absolut (UTC) — jam dinding WIB = UTC + 7 jam,
// tanpa memedulikan zona waktu mesin server.
function wibMs(d = new Date()) {
  return d.getTime() + 7 * 3_600_000;
}

const pad = (n) => String(n).padStart(2, '0');

// Tanggal hari ini versi WIB, 'YYYY-MM-DD'
export function todayWib(d = new Date()) {
  const w = new Date(wibMs(d));
  return `${w.getUTCFullYear()}-${pad(w.getUTCMonth() + 1)}-${pad(w.getUTCDate())}`;
}

// Tanggal tanpa pemisah versi WIB, 'YYYYMMDD' (untuk nomor pesanan)
export function dateCompactWib(d = new Date()) {
  return todayWib(d).replace(/-/g, '');
}

// Tahun WIB (untuk rekap payroll)
export function yearWib(d = new Date()) {
  return new Date(wibMs(d)).getUTCFullYear();
}

// Jam:menit WIB — untuk ambang "terlambat" (shift_start)
export function wibMinutes(d = new Date()) {
  const w = new Date(wibMs(d));
  return w.getUTCHours() * 60 + w.getUTCMinutes();
}
