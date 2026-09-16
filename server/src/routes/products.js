import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();
const SELECT_PRODUCT = `
  SELECT p.id, p.name, p.category_id, c.\`key\` AS category, c.label AS category_label,
         p.price, p.hpp, p.image_url, p.is_active, p.is_available,
         p.stock_item_id, p.stock_qty_per_unit, s.name AS stock_item_name
  FROM products p
  JOIN categories c ON c.id = p.category_id
  LEFT JOIN stock_items s ON s.id = p.stock_item_id`;

router.get('/', async (req, res, next) => {
  try {
    const cond = [];
    const params = {};
    if (req.query.category) { cond.push('c.`key` = :category'); params.category = req.query.category; }
    if (req.query.includeInactive !== '1') cond.push('p.is_active = 1');
    const where = cond.length ? ` WHERE ${cond.join(' AND ')}` : '';
    const [rows] = await pool.query(`${SELECT_PRODUCT}${where} ORDER BY c.sort_order, p.name`, params);
    res.json(rows.map((r) => ({ ...r, price: Number(r.price), hpp: Number(r.hpp), stock_qty_per_unit: Number(r.stock_qty_per_unit) })));
  } catch (e) { next(e); }
});

router.post('/', async (req, res, next) => {
  try {
    const { name, category_id, price, hpp = 0, image_url = null, stock_item_id = null, stock_qty_per_unit = 1 } = req.body;
    if (!name || !category_id || price == null) {
      return res.status(400).json({ error: 'name, category_id, dan price wajib diisi' });
    }
    const [result] = await pool.query(
      `INSERT INTO products (name, category_id, price, hpp, image_url, stock_item_id, stock_qty_per_unit)
       VALUES (:name, :cat, :price, :hpp, :img, :stock, :stock_qty)`,
      { name, cat: category_id, price, hpp, img: image_url, stock: stock_item_id, stock_qty: stock_qty_per_unit }
    );
    const [rows] = await pool.query(`${SELECT_PRODUCT} WHERE p.id = :id`, { id: result.insertId });
    res.status(201).json({ ...rows[0], price: Number(rows[0].price), hpp: Number(rows[0].hpp), stock_qty_per_unit: Number(rows[0].stock_qty_per_unit) });
  } catch (e) { next(e); }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const allowed = ['name', 'category_id', 'price', 'hpp', 'image_url', 'is_active', 'is_available', 'stock_item_id', 'stock_qty_per_unit'];
    const sets = allowed.filter((f) => req.body[f] !== undefined);
    if (!sets.length) return res.status(400).json({ error: 'Tidak ada field yang diubah' });
    const params = { id: Number(req.params.id) };
    for (const f of sets) params[f] = req.body[f];
    const [result] = await pool.query(
      `UPDATE products SET ${sets.map((f) => `${f} = :${f}`).join(', ')} WHERE id = :id`, params
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Produk tidak ditemukan' });
    const [rows] = await pool.query(`${SELECT_PRODUCT} WHERE p.id = :id`, { id: params.id });
    res.json({ ...rows[0], price: Number(rows[0].price), hpp: Number(rows[0].hpp), stock_qty_per_unit: Number(rows[0].stock_qty_per_unit) });
  } catch (e) { next(e); }
});

router.delete('/:id', async (req, res, next) => {
  try {
    // Soft delete: produk sudah pernah masuk order_items tidak boleh dihapus permanen.
    const [result] = await pool.query('UPDATE products SET is_active = 0 WHERE id = :id', {
      id: Number(req.params.id),
    });
    if (!result.affectedRows) return res.status(404).json({ error: 'Produk tidak ditemukan' });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

export default router;
