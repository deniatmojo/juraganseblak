import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

// GET /api/payroll?from=&to= — rekap gaji per karyawan
// Gaji = (hadir + terlambat) × tarif harian; dikurangi kasbon belum lunas.
router.get('/', async (req, res, next) => {
  try {
    const from = req.query.from;
    const to = req.query.to;
    if (!from || !to) return res.status(400).json({ error: 'Parameter from dan to wajib diisi' });

    const [rows] = await pool.query(
      `SELECT e.id, e.name, e.role AS posisi, e.daily_rate,
              COALESCE(SUM(a.status IN ('hadir', 'terlambat')), 0) AS days_present,
              COALESCE(SUM(a.status = 'terlambat'), 0) AS days_late,
              COALESCE(SUM(a.status IN ('izin', 'sakit')), 0) AS days_off,
              COALESCE((SELECT SUM(k.amount) FROM kasbon k WHERE k.employee_id = e.id AND k.is_settled = 0), 0) AS kasbon_open
       FROM employees e
       LEFT JOIN attendance a ON a.employee_id = e.id AND a.work_date BETWEEN :from AND :to
       WHERE e.is_active = 1
       GROUP BY e.id, e.name, e.role, e.daily_rate
       ORDER BY e.name`,
      { from, to }
    );
    res.json(rows.map((r) => {
      const days = Number(r.days_present);
      const rate = Number(r.daily_rate);
      const kasbon = Number(r.kasbon_open);
      const gaji = days * rate;
      return {
        ...r,
        days_present: days,
        days_late: Number(r.days_late),
        days_off: Number(r.days_off),
        daily_rate: rate,
        kasbon_open: kasbon,
        gaji,
        total: gaji - kasbon,
      };
    }));
  } catch (e) { next(e); }
});

// POST /api/payroll/pay — bayar gaji periode, lunaskan kasbon, catat pengeluaran
// { employee_id, from, to, amount }
router.post('/pay', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const { employee_id, from, to } = req.body || {};
    if (!employee_id || !from || !to) return res.status(400).json({ error: 'employee_id, from, to wajib diisi' });

    await conn.beginTransaction();
    const [[emp]] = await conn.query(
      'SELECT id, name, daily_rate FROM employees WHERE id = :id AND is_active = 1 FOR UPDATE',
      { id: Number(employee_id) }
    );
    if (!emp) { await conn.rollback(); return res.status(404).json({ error: 'Karyawan tidak ditemukan' }); }

    const [[agg]] = await conn.query(
      `SELECT COALESCE(SUM(a.status IN ('hadir','terlambat')), 0) AS days
       FROM attendance a WHERE a.employee_id = :id AND a.work_date BETWEEN :from AND :to`,
      { id: emp.id, from, to }
    );
    const [[kb]] = await conn.query(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM kasbon WHERE employee_id = :id AND is_settled = 0 FOR UPDATE',
      { id: emp.id }
    );
    const gaji = Number(agg.days) * Number(emp.daily_rate);
    const kasbon = Number(kb.total);
    const total = gaji - kasbon;

    if (gaji <= 0) { await conn.rollback(); return res.status(400).json({ error: 'Tidak ada hari hadir pada periode ini' }); }

    await conn.query(
      'UPDATE kasbon SET is_settled = 1, settled_at = NOW() WHERE employee_id = :id AND is_settled = 0',
      { id: emp.id }
    );
    await conn.query(
      `INSERT INTO transactions (type, category, amount, note, created_by)
       VALUES ('expense', 'gaji', :amount, :note, :by)`,
      { amount: total, note: `Gaji ${emp.name} periode ${from} s/d ${to} (${agg.days} hari)${kasbon > 0 ? ` − kasbon ${kasbon}` : ''}`, by: req.user.id }
    );
    await conn.commit();

    res.json({ ok: true, employee: emp.name, days: Number(agg.days), gaji, kasbon, total });
  } catch (e) {
    await conn.rollback().catch(() => {});
    next(e);
  } finally {
    conn.release();
  }
});

export default router;
