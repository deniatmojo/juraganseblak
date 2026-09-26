import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

// Migrasi ringan (akuntansi persediaan): simpan harga beli per unit agar
// pembelian & persediaan bisa dinilai dalam rupiah untuk perhitungan HPP.
(async () => {
  try {
    for (const [table, after] of [['stock_items', 'unit'], ['stock_movements', 'qty']]) {
      const [[col]] = await pool.query(
        `SELECT COUNT(*) c FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :t AND COLUMN_NAME = 'unit_cost'`,
        { t: table }
      );
      if (!col.c) {
        await pool.query(`ALTER TABLE ${table} ADD COLUMN unit_cost DECIMAL(14,2) NOT NULL DEFAULT 0 AFTER ${after}`);
      }
    }
  } catch (e) {
    console.error('Migrasi unit_cost stok gagal:', e.message);
  }
})();

// GET /api/stock — daftar bahan + status kritis
router.get('/', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, category, unit, qty, min_qty, unit_cost, is_active, updated_at FROM stock_items WHERE is_active = 1 ORDER BY category, name'
    );
    res.json(rows.map((r) => ({
      ...r,
      qty: Number(r.qty),
      min_qty: Number(r.min_qty),
      unit_cost: Number(r.unit_cost),
      is_low: Number(r.qty) <= Number(r.min_qty),
    })));
  } catch (e) { next(e); }
});

// POST /api/stock — tambah bahan baru (stok awal + harga beli per unit)
// Stok awal BUKAN pembelian: hanya menetapkan persediaan awal bernilai.
router.post('/', async (req, res, next) => {
  try {
    const { name, category = 'Lain-lain', unit = 'pcs', qty = 0, min_qty = 0, unit_cost = 0 } = req.body;
    if (!name) return res.status(400).json({ error: 'Nama bahan wajib diisi' });
    const cost = Number(unit_cost) || 0;
    const [result] = await pool.query(
      'INSERT INTO stock_items (name, category, unit, qty, min_qty, unit_cost) VALUES (:name, :cat, :unit, :qty, :min, :cost)',
      { name, cat: category, unit, qty, min: min_qty, cost }
    );
    if (Number(qty) > 0) {
      await pool.query(
        `INSERT INTO stock_movements (item_id, type, qty, unit_cost, note, created_by) VALUES (:item, 'in', :qty, :cost, 'Stok awal', :user)`,
        { item: result.insertId, qty, cost, user: req.user?.id ?? null }
      );
    }
    res.status(201).json({ id: result.insertId, name, category, unit, qty: Number(qty), min_qty: Number(min_qty), unit_cost: cost });
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
// Untuk 'in': sertakan unit_cost (harga beli per unit) → transaksi belanja bahan
// tercatat OTOMATIS di Keuangan (qty × unit_cost). Harga stok memakai
// HARGA RATA-RATA BERGERAK: (stok sisa × harga lama + masuk × harga beli) ÷ total.
// 'Stok awal' menetapkan harga langsung dan tidak dianggap pembelian.
router.post('/:id/move', async (req, res, next) => {
  try {
    const { type, qty, note = null, unit_cost = 0 } = req.body;
    const itemId = Number(req.params.id);
    const qtyNum = Number(qty);
    const cost = Number(unit_cost) || 0;
    if (!['in', 'out', 'adjust'].includes(type)) {
      return res.status(400).json({ error: 'Type harus in, out, atau adjust' });
    }
    if (Number.isNaN(qtyNum) || qtyNum < 0) {
      return res.status(400).json({ error: 'Qty tidak valid' });
    }
    if (type === 'in' && cost <= 0 && (note || '') !== 'Stok awal') {
      return res.status(400).json({ error: 'Harga beli per unit wajib diisi untuk pencatatan pembelian' });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const [[item]] = await conn.query(
        'SELECT id, name, qty, unit, unit_cost FROM stock_items WHERE id = :id AND is_active = 1 FOR UPDATE',
        { id: itemId }
      );
      if (!item) { await conn.rollback(); return res.status(404).json({ error: 'Bahan tidak ditemukan' }); }

      let delta = 0;
      let newQty = Number(item.qty);
      if (type === 'in') { delta = qtyNum; newQty += qtyNum; }
      else if (type === 'out') { delta = -qtyNum; newQty -= qtyNum; }
      else { delta = qtyNum - Number(item.qty); newQty = qtyNum; }
      if (newQty < 0) { await conn.rollback(); return res.status(400).json({ error: 'Stok tidak cukup' }); }

      const oldCost = Number(item.unit_cost);
      const isStokAwal = (note || '') === 'Stok awal';
      const isPurchase = type === 'in' && cost > 0 && !isStokAwal;

      // Harga rata-rata bergerak: hanya stok yang masih ada yang dicampur.
      let avgCost = oldCost;
      if (type === 'in' && cost > 0) {
        if (isStokAwal) {
          avgCost = cost; // stok awal menetapkan harga dasar
        } else if (newQty > 0) {
          avgCost = (Number(item.qty) * oldCost + qtyNum * cost) / newQty;
        }
      }

      await conn.query('UPDATE stock_items SET qty = :q, unit_cost = :c WHERE id = :id', { q: newQty, c: avgCost, id: itemId });
      await conn.query(
        `INSERT INTO stock_movements (item_id, type, qty, unit_cost, note, created_by) VALUES (:item, :type, :qty, :cost, :note, :user)`,
        { item: itemId, type, qty: Math.abs(delta), cost: isPurchase ? cost : 0, note, user: req.user?.id ?? null }
      );
      if (isPurchase) {
        // Satu sumber kebenaran: pembelian tercatat sebagai transaksi belanja otomatis.
        await conn.query(
          `INSERT INTO transactions (type, category, amount, note, created_by)
           VALUES ('expense', 'belanja', :amount, :note, :user)`,
          {
            amount: Math.round(qtyNum * cost),
            note: `Pembelian ${item.name} ${qtyNum} ${item.unit} @${Math.round(cost).toLocaleString('id-ID')}`,
            user: req.user?.id ?? null,
          }
        );
      }
      await conn.commit();
      res.json({ id: itemId, name: item.name, unit: item.unit, qty: newQty, unit_cost: Math.round(avgCost * 100) / 100, purchase_recorded: isPurchase ? Math.round(qtyNum * cost) : 0 });
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
      `SELECT m.id, s.name AS item_name, m.type, m.qty, m.unit_cost, m.note, u.name AS by_name, m.created_at
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
