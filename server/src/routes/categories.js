import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

router.get('/', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, `key`, label, sort_order, is_active FROM categories ORDER BY sort_order, label'
    );
    res.json(rows);
  } catch (e) { next(e); }
});

router.post('/', async (req, res, next) => {
  try {
    const { key, label, sort_order = 0 } = req.body;
    if (!key || !label) return res.status(400).json({ error: 'key dan label wajib diisi' });
    const [result] = await pool.query(
      'INSERT INTO categories (`key`, label, sort_order) VALUES (:key, :label, :sort)',
      { key: String(key).toLowerCase().replace(/\s+/g, '-'), label, sort: sort_order }
    );
    res.status(201).json({ id: result.insertId, key, label, sort_order, is_active: 1 });
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Kategori dengan key tersebut sudah ada' });
    next(e);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const [[{ total }]] = await pool.query(
      'SELECT COUNT(*) AS total FROM products WHERE category_id = :id AND is_active = 1', { id }
    );
    if (total > 0) return res.status(409).json({ error: 'Kategori masih dipakai produk aktif' });
    await pool.query('DELETE FROM categories WHERE id = :id', { id });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

export default router;
