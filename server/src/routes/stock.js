import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

// GET /api/stock — daftar bahan + status kritis
router.get('/', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, category, unit, qty, min_qty, is_active, updated_at FROM stock_items WHERE is_active = 1 ORDER BY category, name'
    );
    res.json(rows.map((r) => ({
      ...r,
      qty: Number(r.qty),
      min_qty: Number(r.min_qty),
      is_low: Number(r.qty) <= Number(r.min_qty),
    })));
  } catch (e) { next(e); }
});

// POST /api/stock — tambah bahan baru
router.post('/', async (req, res, next) => {
  try {
    const { name, category = 'Lain-lain', unit = 'pcs', qty = 0, min_qty = 0 } = req.body;
    if (!name) return res.status(400).json({ error: 'Nama bahan wajib diisi' });
    const [result] = await pool.query(
      'INSERT INTO stock_items (name, category, unit, qty, min_qty) VALUES (:name, :cat, :unit, :qty, :min)',
      { name, cat: category, unit, qty, min: min_qty }
    );
    if (Number(qty) > 0) {
      await pool.query(
        `INSERT INTO stock_movements (item_id, type, qty, note, created_by) VALUES (:item, 'in', :qty, 'Stok awal', :user)`,
        { item: result.insertId, qty, user: req.user?.id ?? null }
      );
    }
    res.status(201).json({ id: result.insertId, name, category, unit, qty: Number(qty), min_qty: Number(min_qty) });
  } catch (e) { next(e); }
});

// PATCH /api/stock/:id — ubah info bahan (nama/kategori/satuan/min)
router.patch('/:id', async (req, res, next) => {
  try {
    const allowed = ['name', 'category', 'unit', 'min_qty', 'is_active'];
    const sets = allowed.filter((f) => req.body[f] !== undefined);
    if (!sets.length) return res.status(400).json({ error: 'Tidak ada field yang diubah' });
    const params = { id: Number(req.params.id) };
    for (const f of sets) params[f] = req.body[f];
    const [result] = await pool.query(
      `UPDATE stock_items SET ${sets.map((f) => `${f} = :${f}`).join(', ')} WHERE id = :id`, params
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Bahan tidak ditemukan' });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// POST /api/stock/:id/move — barang masuk (in) / keluar (out) / set absolut (adjust)
router.post('/:id/move', async (req, res, next) => {
  try {
    const { type, qty, note = null } = req.body;
    const itemId = Number(req.params.id);
    const qtyNum = Number(qty);
    if (!['in', 'out', 'adjust'].includes(type)) {
      return res.status(400).json({ error: 'Type harus in, out, atau adjust' });
    }
    if (Number.isNaN(qtyNum) || qtyNum < 0) {
      return res.status(400).json({ error: 'Qty tidak valid' });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const [[item]] = await conn.query(
        'SELECT id, name, qty, unit FROM stock_items WHERE id = :id AND is_active = 1 FOR UPDATE',
        { id: itemId }
      );
      if (!item) { await conn.rollback(); return res.status(404).json({ error: 'Bahan tidak ditemukan' }); }

      let delta = 0;
      let newQty = Number(item.qty);
      if (type === 'in') { delta = qtyNum; newQty += qtyNum; }
      else if (type === 'out') { delta = -qtyNum; newQty -= qtyNum; }
      else { delta = qtyNum - Number(item.qty); newQty = qtyNum; }
      if (newQty < 0) { await conn.rollback(); return res.status(400).json({ error: 'Stok tidak cukup' }); }

      await conn.query('UPDATE stock_items SET qty = :q WHERE id = :id', { q: newQty, id: itemId });
      await conn.query(
        `INSERT INTO stock_movements (item_id, type, qty, note, created_by) VALUES (:item, :type, :qty, :note, :user)`,
        { item: itemId, type, qty: Math.abs(delta), note, user: req.user?.id ?? null }
      );
      await conn.commit();
      res.json({ id: itemId, name: item.name, unit: item.unit, qty: newQty });
    } catch (e) {
      await conn.rollback().catch(() => {});
      throw e;
    } finally {
      conn.release();
    }
  } catch (e) { next(e); }
});

// GET /api/stock/movements?item_id=&limit= — riwayat pergerakan
router.get('/movements', async (req, res, next) => {
  try {
    const cond = [];
    const params = { limit: Math.min(Number(req.query.limit || 15), 100) };
    if (req.query.item_id) { cond.push('m.item_id = :item'); params.item = Number(req.query.item_id); }
    const where = cond.length ? ` WHERE ${cond.join(' AND ')}` : '';
    const [rows] = await pool.query(
      `SELECT m.id, s.name AS item_name, m.type, m.qty, m.note, u.name AS by_name, m.created_at
       FROM stock_movements m
       JOIN stock_items s ON s.id = m.item_id
       LEFT JOIN users u ON u.id = m.created_by${where}
       ORDER BY m.created_at DESC, m.id DESC LIMIT :limit`, params
    );
    res.json(rows.map((r) => ({ ...r, qty: Number(r.qty) })));
  } catch (e) { next(e); }
});

// DELETE /api/stock/:id — soft delete
router.delete('/:id', async (req, res, next) => {
  try {
    const [result] = await pool.query('UPDATE stock_items SET is_active = 0 WHERE id = :id', {
      id: Number(req.params.id),
    });
    if (!result.affectedRows) return res.status(404).json({ error: 'Bahan tidak ditemukan' });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

export default router;
