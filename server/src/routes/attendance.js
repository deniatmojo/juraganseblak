import { Router } from 'express';
import { pool } from '../db.js';
import { requireRole } from '../auth.js';

const router = Router();
const LATE_HOUR = 10; // clock-in >= 10:00 dianggap terlambat

function today() {
  return new Date().toISOString().slice(0, 10);
}

// GET /api/attendance?date=YYYY-MM-DD (default hari ini)
// Satu baris per karyawan aktif + status absennya.
router.get('/', async (req, res, next) => {
  try {
    const date = req.query.date || today();
    const [rows] = await pool.query(
      `SELECT e.id AS employee_id, e.name, e.role AS posisi, e.user_id,
              a.clock_in, a.clock_out, a.status, a.note
       FROM employees e
       LEFT JOIN attendance a ON a.employee_id = e.id AND a.work_date = :date
       WHERE e.is_active = 1
       ORDER BY e.name`,
      { date }
    );
    res.json(rows);
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

// POST /api/attendance/clock-in
router.post('/clock-in', async (req, res, next) => {
  try {
    const empId = await resolveEmployee(req);
    if (!empId) return res.status(400).json({ error: 'Akun Anda belum terhubung ke data karyawan. Hubungi admin.' });

    const date = today();
    const now = new Date();
    const status = now.getHours() >= LATE_HOUR ? 'terlambat' : 'hadir';

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
router.patch('/status', requireRole('owner', 'admin'), async (req, res, next) => {
  try {
    const { employee_id, work_date, status, note = null } = req.body || {};
    if (!employee_id || !work_date || !['hadir', 'terlambat', 'izin', 'sakit', 'alpa'].includes(status)) {
      return res.status(400).json({ error: 'Data tidak lengkap atau status tidak valid' });
    }
    await pool.query(
      `INSERT INTO attendance (employee_id, work_date, status, note)
       VALUES (:e, :d, :s, :n)
       ON DUPLICATE KEY UPDATE status = :s, note = :n`,
      { e: Number(employee_id), d: work_date, s: status, n: note }
    );
    res.json({ ok: true });
  } catch (e) { next(e); }
});

export default router;
