import { Router } from 'express';
import { pool } from '../db.js';
import { requireRole } from '../auth.js';

const router = Router();

function today() {
  // Tanggal lokal (bukan toISOString — itu UTC, melenceng setelah tengah malam
  // di zona UTC+7).
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// Auto clock-out: tutup otomatis absensi yang sudah melewati durasi kerja.
// clock_out diset = clock_in + work_hours (dari setting jadwal karyawan).
// Dipanggil setiap kali daftar absensi dibaca dan tiap menit dari index.js
// agar tetap tercatat walau tidak ada yang membuka halamannya.
export async function autoClockOut() {
  const [result] = await pool.query(
    `UPDATE attendance a JOIN employees e ON e.id = a.employee_id
       SET a.clock_out = DATE_ADD(a.clock_in, INTERVAL e.work_hours HOUR),
           a.note = CONCAT_WS(' | ', a.note, 'auto clock-out')
     WHERE a.clock_out IS NULL
       AND a.clock_in IS NOT NULL
       AND a.status IN ('hadir', 'terlambat')
       AND DATE_ADD(a.clock_in, INTERVAL e.work_hours HOUR) <= NOW()`
  );
  return result.affectedRows;
}

// GET /api/attendance?date=YYYY-MM-DD (default hari ini)
// Owner/admin: satu baris per karyawan aktif + status absennya.
// Role lain (kasir/koki): hanya baris miliknya sendiri.
router.get('/', async (req, res, next) => {
  try {
    await autoClockOut();
    const date = req.query.date || today();
    const isBoss = ['owner', 'admin'].includes(req.user.role);
    const [rows] = await pool.query(
      `SELECT e.id AS employee_id, e.name, e.role AS posisi, e.user_id,
              DATE_FORMAT(e.shift_start, '%H:%i') AS shift_start, e.work_hours,
              a.clock_in, a.clock_out, a.status, a.note,
              CASE
                WHEN a.clock_in IS NOT NULL
                  THEN DATE_FORMAT(DATE_ADD(a.clock_in, INTERVAL e.work_hours HOUR), '%H:%i')
                WHEN e.shift_start IS NOT NULL AND a.status IN ('hadir', 'terlambat')
                  THEN DATE_FORMAT(DATE_ADD(CONCAT(a.work_date, ' ', e.shift_start), INTERVAL e.work_hours HOUR), '%H:%i')
                ELSE NULL
              END AS est_clock_out
       FROM employees e
       LEFT JOIN attendance a ON a.employee_id = e.id AND a.work_date = :date
       WHERE e.is_active = 1 ${isBoss ? '' : 'AND e.user_id = :uid'}
       ORDER BY e.name`,
      { date, uid: req.user.id }
    );
    res.json(rows.map((r) => ({ ...r, work_hours: Number(r.work_hours) })));
  } catch (e) { next(e); }
});

// Cari employee milik user login (atau pakai employee_id eksplisit oleh admin)
async function resolveEmployee(req) {
  if (req.body?.employee_id && ['owner', 'admin'].includes(req.user.role)) {
    return Number(req.body.employee_id);
  }
  const [[emp]] = await pool.query(
    'SELECT id FROM employees WHERE user_id = :u AND is_active = 1 LIMIT 1', { u: req.user.id }
  );
  return emp?.id ?? null;
}

// Terlambat bila jam clock-in melewati jam masuk terjadwal (shift_start).
// Karyawan tanpa jadwal memakai batas lama 10:00.
async function lateStatus(empId, now) {
  const [[emp]] = await pool.query(
    'SELECT shift_start FROM employees WHERE id = :id', { id: empId }
  );
  const limit = emp?.shift_start ?? '10:00:00';
  const [lh, lm] = String(limit).split(':').map(Number);
  const minutes = now.getHours() * 60 + now.getMinutes();
  return minutes > lh * 60 + lm ? 'terlambat' : 'hadir';
}

// POST /api/attendance/clock-in
router.post('/clock-in', async (req, res, next) => {
  try {
    const empId = await resolveEmployee(req);
    if (!empId) return res.status(400).json({ error: 'Akun Anda belum terhubung ke data karyawan. Hubungi admin.' });

    const date = today();
    const now = new Date();
    const status = await lateStatus(empId, now);

    const [[existing]] = await pool.query(
      'SELECT id, clock_in FROM attendance WHERE employee_id = :e AND work_date = :d', { e: empId, d: date }
    );
    if (existing?.clock_in) return res.status(409).json({ error: 'Sudah absen masuk hari ini' });

    if (existing) {
      // Sudah ada baris (mis. izin yang diset admin) — isi jam masuk saja
      await pool.query('UPDATE attendance SET clock_in = NOW(), status = :s WHERE id = :id', { s: status, id: existing.id });
    } else {
      await pool.query(
        'INSERT INTO attendance (employee_id, work_date, clock_in, status) VALUES (:e, :d, NOW(), :s)',
        { e: empId, d: date, s: status }
      );
    }
    res.status(201).json({ ok: true, clock_in: now.toISOString(), status });
  } catch (e) { next(e); }
});

// POST /api/attendance/clock-out
router.post('/clock-out', async (req, res, next) => {
  try {
    const empId = await resolveEmployee(req);
    if (!empId) return res.status(400).json({ error: 'Akun Anda belum terhubung ke data karyawan. Hubungi admin.' });

    const date = today();
    const [[att]] = await pool.query(
      'SELECT id, clock_in, clock_out FROM attendance WHERE employee_id = :e AND work_date = :d', { e: empId, d: date }
    );
    if (!att?.clock_in) return res.status(400).json({ error: 'Belum absen masuk hari ini' });
    if (att.clock_out) return res.status(409).json({ error: 'Sudah absen keluar hari ini' });

    await pool.query('UPDATE attendance SET clock_out = NOW() WHERE id = :id', { id: att.id });
    res.json({ ok: true, clock_out: new Date().toISOString() });
  } catch (e) { next(e); }
});

// PATCH /api/attendance/status — admin set izin/sakit/alpa/hadir
// { employee_id, work_date, status, note? }
// 'hadir' manual memakai jam masuk terjadwal sebagai clock_in (bila belum ada),
// sehingga auto clock-out tetap jalan berdasarkan durasi kerja.
router.patch('/status', requireRole('owner', 'admin'), async (req, res, next) => {
  try {
    const { employee_id, work_date, status, note = null } = req.body || {};
    if (!employee_id || !work_date || !['hadir', 'terlambat', 'izin', 'sakit', 'alpa'].includes(status)) {
      return res.status(400).json({ error: 'Data tidak lengkap atau status tidak valid' });
    }
    let clockIn = null;
    if (status === 'hadir') {
      const [[emp]] = await pool.query(
        'SELECT shift_start FROM employees WHERE id = :id', { id: Number(employee_id) }
      );
      if (emp?.shift_start) clockIn = `${work_date} ${emp.shift_start}`;
    }
    await pool.query(
      `INSERT INTO attendance (employee_id, work_date, clock_in, status, note)
       VALUES (:e, :d, :ci, :s, :n)
       ON DUPLICATE KEY UPDATE status = :s, note = :n, clock_in = COALESCE(attendance.clock_in, VALUES(clock_in))`,
      { e: Number(employee_id), d: work_date, ci: clockIn, s: status, n: note }
    );
    res.json({ ok: true });
  } catch (e) { next(e); }
});

export default router;
