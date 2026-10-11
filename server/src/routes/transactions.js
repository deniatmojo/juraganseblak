import { Router } from 'express';
import { pool } from '../db.js';
import { resolveBranch } from '../branch.js';

const router = Router();

// GET /api/transactions?from=&to=&type=
router.get('/', async (req, res, next) => {
  try {
    const cond = [];
    const params = {};
    const branch = await resolveBranch(req, { allowAll: true });
    if (branch != null) { cond.push('t.branch_id = :branch'); params.branch = branch; }
    if (req.query.from) { cond.push('t.created_at >= :from'); params.from = `${req.query.from} 00:00:00`; }
    if (req.query.to) { cond.push('t.created_at <= :to'); params.to = `${req.query.to} 23:59:59`; }
    if (req.query.type) { cond.push('t.type = :type'); params.type = req.query.type; }
    const where = cond.length ? ` WHERE ${cond.join(' AND ')}` : '';
    const [rows] = await pool.query(
      `SELECT t.id, t.type, t.category, t.amount, t.note, t.ref_order, u.name AS by_name, t.created_at, t.branch_id, b.name AS branch_name
       FROM transactions t LEFT JOIN users u ON u.id = t.created_by
       LEFT JOIN branches b ON b.id = t.branch_id${where}
       ORDER BY t.created_at DESC LIMIT 500`, params
    );
    res.json(rows.map((r) => ({ ...r, amount: Number(r.amount) })));
  } catch (e) { next(e); }
});

// POST /api/transactions — catat pemasukan/pengeluaran manual
router.post('/', async (req, res, next) => {
  try {
    const { type, category, amount, note = null } = req.body || {};
    if (!['income', 'expense'].includes(type)) return res.status(400).json({ error: 'Type harus income atau expense' });
    if (!category || !amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Kategori dan jumlah (> 0) wajib diisi' });
    }
    const branch = await resolveBranch(req);
    const [result] = await pool.query(
      'INSERT INTO transactions (type, category, amount, note, created_by, branch_id) VALUES (:type, :cat, :amount, :note, :user, :b)',
      { type, cat: category, amount, note, user: req.user?.id ?? null, b: branch }
    );
    res.status(201).json({ id: result.insertId, branch_id: branch, type, category, amount: Number(amount), note });
  } catch (e) { next(e); }
});

export default router;
