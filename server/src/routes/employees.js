import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

const SELECT_EMP = `
  SELECT e.id, e.name, e.role, e.phone, e.daily_rate, e.is_active, e.user_id,
         u.email AS account_email, u.role AS account_role,
         COALESCE((SELECT SUM(k.amount) FROM kasbon k WHERE k.employee_id = e.id AND k.is_settled = 0), 0) AS kasbon_open
  FROM employees e LEFT JOIN users u ON u.id = e.user_id`;

// GET /api/employees
router.get('/', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(`${SELECT_EMP} WHERE e.is_active = 1 ORDER BY e.name`);
    res.json(rows.map((r) => ({ ...r, daily_rate: Number(r.daily_rate), kasbon_open: Number(r.kasbon_open) })));
  } catch (e) { next(e); }
});

// Pastikan satu akun login hanya ter-link ke satu data karyawan.
async function assertUserFree(user_id, exceptEmployeeId = null) {
  if (!user_id) return;
  const [[dup]] = await pool.query(
    'SELECT id, name FROM employees WHERE user_id = :uid AND is_active = 1 AND id != :except',
    { uid: Number(user_id), except: exceptEmployeeId ?? 0 }
  );
  if (dup) {
    const err = new Error(`Akun sudah terhubung ke karyawan: ${dup.name}`);
    err.status = 409;
    throw err;
  }
}

// POST /api/employees — { name, role, phone?, daily_rate?, user_id? }
router.post('/', async (req, res, next) => {
  try {
    const { name, role = '', phone = null, daily_rate = 0, user_id = null } = req.body || {};
    if (!name) return res.status(400).json({ error: 'Nama karyawan wajib diisi' });
    await assertUserFree(user_id);
    const [result] = await pool.query(
      'INSERT INTO employees (name, role, phone, daily_rate, user_id) VALUES (:name, :role, :phone, :rate, :uid)',
      { name, role, phone, rate: daily_rate, uid: user_id }
    );
    res.status(201).json({ id: result.insertId, name, role, daily_rate: Number(daily_rate) });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ error: e.message });
    next(e);
  }
});

// PATCH /api/employees/:id
router.patch('/:id', async (req, res, next) => {
  try {
    const allowed = ['name', 'role', 'phone', 'daily_rate', 'user_id', 'is_active'];
    const sets = allowed.filter((f) => req.body[f] !== undefined);
    if (!sets.length) return res.status(400).json({ error: 'Tidak ada field yang diubah' });
    const id = Number(req.params.id);
    if (req.body.user_id !== undefined) await assertUserFree(req.body.user_id, id);
    const params = { id };
    for (const f of sets) params[f] = req.body[f];
    const [result] = await pool.query(
      `UPDATE employees SET ${sets.map((f) => `${f} = :${f}`).join(', ')} WHERE id = :id`, params
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Karyawan tidak ditemukan' });
    res.json({ ok: true });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ error: e.message });
    next(e);
  }
});

// DELETE /api/employees/:id — soft delete
router.delete('/:id', async (req, res, next) => {
  try {
    const [result] = await pool.query('UPDATE employees SET is_active = 0 WHERE id = :id', {
      id: Number(req.params.id),
    });
    if (!result.affectedRows) return res.status(404).json({ error: 'Karyawan tidak ditemukan' });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// GET /api/employees/:id/kasbon — riwayat kasbon
router.get('/:id/kasbon', async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, amount, note, is_settled, created_at, settled_at FROM kasbon WHERE employee_id = :id ORDER BY created_at DESC LIMIT 100',
      { id: Number(req.params.id) }
    );
    res.json(rows.map((r) => ({ ...r, amount: Number(r.amount) })));
  } catch (e) { next(e); }
});

// POST /api/employees/:id/kasbon — catat kasbon baru
router.post('/:id/kasbon', async (req, res, next) => {
  try {
    const { amount, note = null } = req.body || {};
    if (!amount || Number(amount) <= 0) return res.status(400).json({ error: 'Jumlah kasbon harus > 0' });
    const [result] = await pool.query(
      'INSERT INTO kasbon (employee_id, amount, note) VALUES (:id, :amount, :note)',
      { id: Number(req.params.id), amount, note }
    );
    res.status(201).json({ id: result.insertId, amount: Number(amount), note, is_settled: 0 });
  } catch (e) { next(e); }
});

export default router;
