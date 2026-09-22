import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

// Migrasi ringan: tabel riwayat pembayaran gaji + penanda kehadiran sudah dibayar.
// Dijalankan sekali saat modul dimuat; aman dipanggil berulang.
(async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS payroll_payments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        employee_id INT NOT NULL,
        from_date DATE NOT NULL,
        to_date DATE NOT NULL,
        days INT NOT NULL DEFAULT 0,
        gaji BIGINT NOT NULL DEFAULT 0,
        kasbon BIGINT NOT NULL DEFAULT 0,
        total BIGINT NOT NULL DEFAULT 0,
        paid_by INT NULL,
        paid_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_emp_date (employee_id, from_date, to_date)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
    const [[col]] = await pool.query(
      `SELECT COUNT(*) AS c FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attendance' AND COLUMN_NAME = 'paid'`
    );
    if (!col.c) {
      await pool.query('ALTER TABLE attendance ADD COLUMN paid TINYINT(1) NOT NULL DEFAULT 0');
    }
  } catch (e) {
    console.error('Migrasi payroll gagal:', e.message);
  }
})();

// GET /api/payroll?from=&to= — rekap gaji per karyawan untuk periode.
// Hanya menghitung kehadiran yang BELUM dibayar → "pending bayar".
// Gaji = hadir × tarif harian; dikurangi kasbon belum lunas dan pembayaran periode sama.
router.get('/', async (req, res, next) => {
  try {
    const from = req.query.from;
    const to = req.query.to;
    if (!from || !to) return res.status(400).json({ error: 'Parameter from dan to wajib diisi' });

    const [rows] = await pool.query(
      `SELECT e.id, e.name, e.role AS posisi, e.daily_rate,
              COALESCE(SUM(a.status IN ('hadir', 'terlambat') AND a.paid = 0), 0) AS days_present,
              COALESCE(SUM(a.status = 'terlambat' AND a.paid = 0), 0) AS days_late,
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
      const pending = gaji - kasbon;
      return {
        ...r,
        days_present: days,
        days_late: Number(r.days_late),
        days_off: Number(r.days_off),
        daily_rate: rate,
        kasbon_open: kasbon,
        gaji,
        pending,
        total: pending, // alias kompatibel untuk aplikasi lama
      };
    }));
  } catch (e) { next(e); }
});

// GET /api/payroll/history?year=&month=&employee_id= — riwayat pembayaran (rekap).
// month opsional: tanpa month = rekap setahun penuh.
router.get('/history', async (req, res, next) => {
  try {
    const year = Number(req.query.year) || new Date().getFullYear();
    const month = req.query.month ? Number(req.query.month) : null;
    const employeeId = req.query.employee_id ? Number(req.query.employee_id) : null;
    if (month && (month < 1 || month > 12)) return res.status(400).json({ error: 'Month 1-12' });

    const params = { year };
    let where = 'YEAR(p.paid_at) = :year';
    if (month) { params.month = month; where += ' AND MONTH(p.paid_at) = :month'; }
    if (employeeId) { params.employeeId = employeeId; where += ' AND p.employee_id = :employeeId'; }

    const [rows] = await pool.query(
      `SELECT p.id, p.employee_id, e.name, e.role AS posisi,
              DATE_FORMAT(p.from_date, '%d/%m/%Y') AS periode_from,
              DATE_FORMAT(p.to_date, '%d/%m/%Y') AS periode_to,
              p.days, p.gaji, p.kasbon, p.total,
              DATE_FORMAT(p.paid_at, '%d/%m/%Y %H:%i') AS paid_at
       FROM payroll_payments p
       JOIN employees e ON e.id = p.employee_id
       WHERE ${where}
       ORDER BY p.paid_at DESC, e.name`,
      params
    );
    res.json(rows.map((r) => ({ ...r, days: Number(r.days), gaji: Number(r.gaji), kasbon: Number(r.kasbon), total: Number(r.total) })));
  } catch (e) { next(e); }
});

// POST /api/payroll/pay — bayar gaji periode (yang belum dibayar saja), lunaskan
// kasbon, tandai kehadiran sebagai paid, catat pengeluaran + riwayat pembayaran.
// { employee_id, from, to }
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
      `SELECT COALESCE(SUM(a.status IN ('hadir','terlambat') AND a.paid = 0), 0) AS days
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

    if (gaji <= 0) { await conn.rollback(); return res.status(400).json({ error: 'Tidak ada gaji pending pada periode ini (sudah dibayar atau belum ada kehadiran)' }); }
    if (total < 0) { await conn.rollback(); return res.status(400).json({ error: 'Kasbon melebihi gaji periode ini — lunaskan kasbon terlebih dahulu atau kecilkan periode' }); }

    await conn.query(
      `UPDATE attendance SET paid = 1
       WHERE employee_id = :id AND work_date BETWEEN :from AND :to AND status IN ('hadir','terlambat') AND paid = 0`,
      { id: emp.id, from, to }
    );
    await conn.query(
      'UPDATE kasbon SET is_settled = 1, settled_at = NOW() WHERE employee_id = :id AND is_settled = 0',
      { id: emp.id }
    );
    await conn.query(
      `INSERT INTO transactions (type, category, amount, note, created_by)
       VALUES ('expense', 'gaji', :amount, :note, :by)`,
      { amount: total, note: `Gaji ${emp.name} periode ${from} s/d ${to} (${agg.days} hari)${kasbon > 0 ? ` − kasbon ${kasbon}` : ''}`, by: req.user.id }
    );
    const [payRes] = await conn.query(
      `INSERT INTO payroll_payments (employee_id, from_date, to_date, days, gaji, kasbon, total, paid_by)
       VALUES (:id, :from, :to, :days, :gaji, :kasbon, :total, :by)`,
      { id: emp.id, from, to, days: Number(agg.days), gaji, kasbon, total, by: req.user.id }
    );
    await conn.commit();

    res.json({
      ok: true, payment_id: payRes.insertId, employee: emp.name, employee_id: emp.id,
      from, to, days: Number(agg.days), daily_rate: Number(emp.daily_rate), gaji, kasbon, total,
    });
  } catch (e) {
    await conn.rollback().catch(() => {});
    next(e);
  } finally {
    conn.release();
  }
});

export default router;
