import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

// Migrasi ringan: tabel relasi menu↔bahan (bisa lebih dari satu bahan per menu).
// Data link lama (products.stock_item_id) dimigrasikan sekali ke tabel baru.
(async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS product_stock_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        product_id INT UNSIGNED NOT NULL,
        stock_item_id INT UNSIGNED NOT NULL,
        qty_per_unit DECIMAL(12,3) NOT NULL DEFAULT 1,
        UNIQUE KEY uniq_pair (product_id, stock_item_id),
        INDEX idx_product (product_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
    await pool.query(
      `INSERT IGNORE INTO product_stock_items (product_id, stock_item_id, qty_per_unit)
       SELECT id, stock_item_id, stock_qty_per_unit FROM products
       WHERE stock_item_id IS NOT NULL AND stock_qty_per_unit > 0`
    );
  } catch (e) {
    console.error('Migrasi product_stock_items gagal:', e.message);
  }
})();

// Ambil semua bahan terhubung per menu (dipakai pemakaian stok & tampilan).
export async function linksForProducts(productIds) {
  if (!productIds.length) return new Map();
  const [rows] = await pool.query(
    `SELECT psi.product_id, psi.stock_item_id, psi.qty_per_unit, s.name AS stock_item_name
     FROM product_stock_items psi JOIN stock_items s ON s.id = psi.stock_item_id
     WHERE psi.product_id IN (?) ORDER BY psi.id`,
    [productIds]
  );
  const map = new Map();
  for (const r of rows) {
    const list = map.get(r.product_id) || [];
    list.push({ stock_item_id: r.stock_item_id, qty_per_unit: Number(r.qty_per_unit), stock_item_name: r.stock_item_name });
    map.set(r.product_id, list);
  }
  return map;
}

async function replaceLinks(conn, productId, links) {
  await conn.query('DELETE FROM product_stock_items WHERE product_id = :id', { id: productId });
  for (const l of links) {
    if (!l.stock_item_id || !(Number(l.qty_per_unit) > 0)) continue;
    await conn.query(
      'INSERT INTO product_stock_items (product_id, stock_item_id, qty_per_unit) VALUES (:p, :s, :q)',
      { p: productId, s: Number(l.stock_item_id), q: Number(l.qty_per_unit) }
    );
  }
  // Simpan bahan pertama ke kolom lama untuk kompatibilitas aplikasi lama.
  const first = links.find((l) => l.stock_item_id && Number(l.qty_per_unit) > 0);
  await conn.query(
    'UPDATE products SET stock_item_id = :s, stock_qty_per_unit = :q WHERE id = :id',
    { s: first ? Number(first.stock_item_id) : null, q: first ? Number(first.qty_per_unit) : 1, id: productId }
  );
}

const SELECT_PRODUCT = `
  SELECT p.id, p.name, p.category_id, c.\`key\` AS category, c.label AS category_label,
         p.price, p.hpp, p.image_url, p.is_active, p.is_available,
         p.stock_item_id, p.stock_qty_per_unit, s.name AS stock_item_name
  FROM products p
  JOIN categories c ON c.id = p.category_id
  LEFT JOIN stock_items s ON s.id = p.stock_item_id`;

async function attachLinks(rows) {
  const map = await linksForProducts(rows.map((r) => r.id));
  return rows.map((r) => ({
    ...r,
    price: Number(r.price), hpp: Number(r.hpp), stock_qty_per_unit: Number(r.stock_qty_per_unit),
    stock_links: map.get(r.id) || [],
  }));
}

router.get('/', async (req, res, next) => {
  try {
    const cond = [];
    const params = {};
    if (req.query.category) { cond.push('c.`key` = :category'); params.category = req.query.category; }
    if (req.query.includeInactive !== '1') cond.push('p.is_active = 1');
    const where = cond.length ? ` WHERE ${cond.join(' AND ')}` : '';
    const [rows] = await pool.query(`${SELECT_PRODUCT}${where} ORDER BY c.sort_order, p.name`, params);
    res.json(await attachLinks(rows));
  } catch (e) { next(e); }
});

router.post('/', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const { name, category_id, price, hpp = 0, image_url = null, stock_item_id = null, stock_qty_per_unit = 1, stock_links = null } = req.body;
    if (!name || !category_id || price == null) {
      return res.status(400).json({ error: 'name, category_id, dan price wajib diisi' });
    }
    await conn.beginTransaction();
    const [result] = await conn.query(
      `INSERT INTO products (name, category_id, price, hpp, image_url, stock_item_id, stock_qty_per_unit)
       VALUES (:name, :cat, :price, :hpp, :img, :stock, :stock_qty)`,
      { name, cat: category_id, price, hpp, img: image_url, stock: stock_item_id, stock_qty: stock_qty_per_unit }
    );
    // Terima format baru stock_links [{stock_item_id, qty_per_unit}]; fallback ke link tunggal lama.
    const links = Array.isArray(stock_links)
      ? stock_links
      : (stock_item_id ? [{ stock_item_id, qty_per_unit: stock_qty_per_unit }] : []);
    await replaceLinks(conn, result.insertId, links);
    await conn.commit();
    const [rows] = await pool.query(`${SELECT_PRODUCT} WHERE p.id = :id`, { id: result.insertId });
    res.status(201).json((await attachLinks(rows))[0]);
  } catch (e) {
    await conn.rollback().catch(() => {});
    next(e);
  } finally { conn.release(); }
});

router.patch('/:id', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const id = Number(req.params.id);
    const allowed = ['name', 'category_id', 'price', 'hpp', 'image_url', 'is_active', 'is_available', 'stock_item_id', 'stock_qty_per_unit'];
    const sets = allowed.filter((f) => req.body[f] !== undefined);
    await conn.beginTransaction();
    if (sets.length) {
      const params = { id };
      for (const f of sets) params[f] = req.body[f];
      await conn.query(`UPDATE products SET ${sets.map((f) => `${f} = :${f}`).join(', ')} WHERE id = :id`, params);
    }
    if (Array.isArray(req.body.stock_links)) {
      await replaceLinks(conn, id, req.body.stock_links);
    }
    await conn.commit();
    const [rows] = await pool.query(`${SELECT_PRODUCT} WHERE p.id = :id`, { id });
    if (!rows.length) return res.status(404).json({ error: 'Produk tidak ditemukan' });
    res.json((await attachLinks(rows))[0]);
  } catch (e) {
    await conn.rollback().catch(() => {});
    next(e);
  } finally { conn.release(); }
});

router.delete('/:id', async (req, res, next) => {
  // Soft delete: produk sudah pernah masuk order_items tidak boleh dihapus permanen.
  const [result] = await pool.query('UPDATE products SET is_active = 0 WHERE id = :id', {
    id: Number(req.params.id),
  });
  if (!result.affectedRows) return res.status(404).json({ error: 'Produk tidak ditemukan' });
  res.json({ ok: true });
});

export default router;
