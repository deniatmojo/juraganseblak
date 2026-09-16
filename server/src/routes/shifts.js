import { Router } from 'express';
import { pool } from '../db.js';
import { requireRole } from '../auth.js';

const router = Router();

async function shiftTotals(shiftId) {
  const [[t]] = await pool.query(
    `SELECT COUNT(*) AS order_count,
            COALESCE(SUM(total), 0) AS sales_total,
            COALESCE(SUM(CASE WHEN pay_method = 'cash' THEN total ELSE 0 END), 0) AS cash_total,
            COALESCE(SUM(CASE WHEN pay_method = 'qris' THEN total ELSE 0 END), 0) AS qris_total,
            COALESCE(SUM(CASE WHEN pay_method = 'debit' THEN total ELSE 0 END), 0) AS debit_total
     FROM orders WHERE shift_id = :id AND status = 'paid'`,
    { id: shiftId }
  );
  return {
    order_count: t.order_count,
    sales_total: Number(t.sales_total),
    cash_total: Number(t.cash_total),
    qris_total: Number(t.qris_total),
    debit_total: Number(t.debit_total),
  };
}

// GET /api/shifts — riwayat shift (owner/admin)
router.get('/', requireRole('owner', 'admin'), async (_req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT s.id, u.name AS cashier_name, s.opening_cash, s.closing_cash, s.expected_cash,
              s.opened_at, s.closed_at, s.note
       FROM shifts s JOIN users u ON u.id = s.user_id
       ORDER BY s.opened_at DESC LIMIT 100`
    );
    res.json(rows.map((r) => ({
      ...r,
      opening_cash: Number(r.opening_cash),
      closing_cash: r.closing_cash == null ? null : Number(r.closing_cash),
      expected_cash: r.expected_cash == null ? null : Number(r.expected_cash),
    })));
  } catch (e) { next(e); }
});

// GET /api/shifts/active — shift aktif milik user login (+ total live)
router.get('/active', async (req, res, next) => {
  try {
    const [[shift]] = await pool.query(
      'SELECT id, opening_cash, opened_at FROM shifts WHERE user_id = :u AND closed_at IS NULL ORDER BY id DESC LIMIT 1',
      { u: req.user.id }
    );
    if (!shift) return res.json(null);
    const totals = await shiftTotals(shift.id);
    res.json({ id: shift.id, opening_cash: Number(shift.opening_cash), opened_at: shift.opened_at, totals });
  } catch (e) { next(e); }
});

// POST /api/shifts — mulai shift { opening_cash, note? }
router.post('/', async (req, res, next) => {
  try {
    const [[open]] = await pool.query(
      'SELECT id FROM shifts WHERE user_id = :u AND closed_at IS NULL', { u: req.user.id }
    );
    if (open) return res.status(409).json({ error: 'Masih ada shift yang terbuka. Tutup dulu shift sebelumnya.' });
    const { opening_cash = 0, note = null } = req.body || {};
    const [result] = await pool.query(
      'INSERT INTO shifts (user_id, opening_cash, note) VALUES (:u, :cash, :note)',
      { u: req.user.id, cash: opening_cash, note }
    );
    res.status(201).json({ id: result.insertId, opening_cash: Number(opening_cash), opened_at: new Date(), totals: { order_count: 0, sales_total: 0, cash_total: 0, qris_total: 0, debit_total: 0 } });
  } catch (e) { next(e); }
});

// POST /api/shifts/:id/close — tutup shift { closing_cash, note? }
router.post('/:id/close', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const [[shift]] = await pool.query(
      'SELECT id, user_id, opening_cash, closed_at FROM shifts WHERE id = :id', { id }
    );
    if (!shift) return res.status(404).json({ error: 'Shift tidak ditemukan' });
    if (shift.closed_at) return res.status(409).json({ error: 'Shift sudah ditutup' });
    // Kasir hanya boleh menutup shift-nya sendiri; owner/admin bebas.
    if (req.user.role === 'kasir' && shift.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Anda hanya bisa menutup shift sendiri' });
    }

    const { closing_cash = 0, note = null } = req.body || {};
    const totals = await shiftTotals(id);
    const expected = Number(shift.opening_cash) + totals.cash_total;
    const selisih = Number(closing_cash) - expected;

    await pool.query(
      'UPDATE shifts SET closing_cash = :closing, expected_cash = :expected, closed_at = NOW(), note = COALESCE(:note, note) WHERE id = :id',
      { closing: closing_cash, expected, note, id }
    );
    res.json({ id, ...totals, opening_cash: Number(shift.opening_cash), expected_cash: expected, closing_cash: Number(closing_cash), selisih });
  } catch (e) { next(e); }
});

export default router;
