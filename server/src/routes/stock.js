import { Router } from 'express';
import { pool } from '../db.js';
import { resolveBranch, branchCond, ensureStockRow, lockedBranchId } from '../branch.js';

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

// GET /api/stock?branch_id= — daftar bahan + status kritis untuk SATU cabang.
// Owner boleh branch_id=all → qty dijumlah semua cabang (min_qty = min bahan).
router.get('/', async (req, res, next) => {
  try {
    const branch = await resolveBranch(req, { allowAll: true });
    const sql = branch == null
      ? `SELECT s.id, s.name, s.category, s.unit, COALESCE(SUM(b.qty), 0) AS qty, s.min_qty,
                s.unit_cost, s.is_active, s.updated_at
         FROM stock_items s LEFT JOIN stock_branch_items b ON b.item_id = s.id
         WHERE s.is_active = 1 GROUP BY s.id ORDER BY s.category, s.name`
      : `SELECT s.id, s.name, s.category, s.unit, COALESCE(b.qty, 0) AS qty,
                COALESCE(b.min_qty, s.min_qty) AS min_qty, s.unit_cost, s.is_active, s.updated_at
         FROM stock_items s
         LEFT JOIN stock_branch_items b ON b.item_id = s.id AND b.branch_id = :branch
         WHERE s.is_active = 1 ORDER BY s.category, s.name`;
    const [rows] = await pool.query(sql, { branch });
    res.json(rows.map((r) => ({
      ...r,
      qty: Number(r.qty),
      min_qty: Number(r.min_qty),
      unit_cost: Number(r.unit_cost),
      is_low: Number(r.qty) <= Number(r.min_qty),
      branch_id: branch,
    })));
  } catch (e) { next(e); }
});

// GET /api/stock/overview — matriks bahan × cabang (stok semua cabang sekaligus)
router.get('/overview', async (req, res, next) => {
  try {
    const locked = await lockedBranchId(req.user);
    const [branches] = await pool.query(
      `SELECT id, name FROM branches WHERE is_active = 1 ${locked ? 'AND id = :locked' : ''} ORDER BY id`, { locked }
    );
    const [items] = await pool.query(
      'SELECT id, name, category, unit, min_qty FROM stock_items WHERE is_active = 1 ORDER BY category, name'
    );
    const [qtys] = await pool.query('SELECT item_id, branch_id, qty, min_qty FROM stock_branch_items');
    const map = new Map(qtys.map((q) => [`${q.item_id}:${q.branch_id}`, q]));
    res.json({
      branches,
      items: items.map((it) => ({
        id: it.id, name: it.name, category: it.category, unit: it.unit,
        per_branch: Object.fromEntries(branches.map((b) => {
          const q = map.get(`${it.id}:${b.id}`);
          const qty = q ? Number(q.qty) : 0;
          const min = q ? Number(q.min_qty) : Number(it.min_qty);
          return [b.id, { qty, min_qty: min, is_low: qty <= min }];
        })),
      })),
    });
  } catch (e) { next(e); }
});

// POST /api/stock — tambah bahan baru (katalog bersama semua cabang).
// Stok awal + min stok dicatat di cabang terpilih (branch_id); cabang lain 0.
// Stok awal BUKAN pembelian: hanya menetapkan persediaan awal bernilai.
router.post('/', async (req, res, next) => {
  try {
    const { name, category = 'Lain-lain', unit = 'pcs', qty = 0, min_qty = 0, unit_cost = 0 } = req.body;
    if (!name) return res.status(400).json({ error: 'Nama bahan wajib diisi' });
    const branch = await resolveBranch(req);
    const cost = Number(unit_cost) || 0;
    const [result] = await pool.query(
      'INSERT INTO stock_items (name, category, unit, qty, min_qty, unit_cost) VALUES (:name, :cat, :unit, 0, :min, :cost)',
      { name, cat: category, unit, min: min_qty, cost }
    );
    await pool.query(
      'INSERT INTO stock_branch_items (item_id, branch_id, qty, min_qty) VALUES (:i, :b, :qty, :min)',
      { i: result.insertId, b: branch, qty, min: min_qty }
    );
    if (Number(qty) > 0) {
      await pool.query(
        `INSERT INTO stock_movements (item_id, type, qty, unit_cost, note, created_by, branch_id) VALUES (:item, 'in', :qty, :cost, 'Stok awal', :user, :b)`,
        { item: result.insertId, qty, cost, user: req.user?.id ?? null, b: branch }
      );
    }
    res.status(201).json({ id: result.insertId, name, category, unit, qty: Number(qty), min_qty: Number(min_qty), unit_cost: cost, branch_id: branch });
  } catch (e) { next(e); }
});

// PATCH /api/stock/:id — ubah info bahan (nama/kategori/satuan global; min_qty per cabang)
router.patch('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const allowed = ['name', 'category', 'unit', 'is_active'];
    const sets = allowed.filter((f) => req.body[f] !== undefined);
    if (!sets.length && req.body.min_qty === undefined) return res.status(400).json({ error: 'Tidak ada field yang diubah' });
    if (sets.length) {
      const params = { id };
      for (const f of sets) params[f] = req.body[f];
      const [result] = await pool.query(
        `UPDATE stock_items SET ${sets.map((f) => `${f} = :${f}`).join(', ')} WHERE id = :id`, params
      );
      if (!result.affectedRows) return res.status(404).json({ error: 'Bahan tidak ditemukan' });
    }
    if (req.body.min_qty !== undefined) {
      const branch = await resolveBranch(req);
      const conn = await pool.getConnection();
      try {
        await ensureStockRow(conn, id, branch);
        await conn.query('UPDATE stock_branch_items SET min_qty = :m WHERE item_id = :i AND branch_id = :b',
          { m: Number(req.body.min_qty) || 0, i: id, b: branch });
      } finally { conn.release(); }
    }
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// POST /api/stock/:id/move — barang masuk (in) / keluar (out) / set absolut (adjust)
// di SATU cabang (branch_id). Untuk 'in': sertakan unit_cost (harga beli per unit)
// → transaksi belanja bahan tercatat OTOMATIS di Keuangan cabang itu (qty × unit_cost).
// Harga bahan memakai HARGA RATA-RATA BERGERAK global: (stok semua cabang × harga
// lama + masuk × harga beli) ÷ total. 'Stok awal' menetapkan harga langsung.
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
    const branch = await resolveBranch(req);

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const [[item]] = await conn.query(
        'SELECT id, name, unit, unit_cost FROM stock_items WHERE id = :id AND is_active = 1 FOR UPDATE',
        { id: itemId }
      );
      if (!item) { await conn.rollback(); return res.status(404).json({ error: 'Bahan tidak ditemukan' }); }
      await ensureStockRow(conn, itemId, branch);
      const [[row]] = await conn.query(
        'SELECT qty FROM stock_branch_items WHERE item_id = :i AND branch_id = :b FOR UPDATE', { i: itemId, b: branch }
      );
      const [[tot]] = await conn.query('SELECT COALESCE(SUM(qty), 0) AS q FROM stock_branch_items WHERE item_id = :i', { i: itemId });
      const branchQty = Number(row.qty);
      const totalQty = Number(tot.q);

      let delta = 0;
      let newQty = branchQty;
      if (type === 'in') { delta = qtyNum; newQty += qtyNum; }
      else if (type === 'out') { delta = -qtyNum; newQty -= qtyNum; }
      else { delta = qtyNum - branchQty; newQty = qtyNum; }
      if (newQty < 0) { await conn.rollback(); return res.status(400).json({ error: 'Stok tidak cukup' }); }

      const oldCost = Number(item.unit_cost);
      const isStokAwal = (note || '') === 'Stok awal';
      const isPurchase = type === 'in' && cost > 0 && !isStokAwal;

      // Harga rata-rata bergerak (dihitung dari total stok semua cabang).
      let avgCost = oldCost;
      if (type === 'in' && cost > 0) {
        if (isStokAwal) {
          avgCost = cost; // stok awal menetapkan harga dasar
        } else if (totalQty + qtyNum > 0) {
          avgCost = (totalQty * oldCost + qtyNum * cost) / (totalQty + qtyNum);
        }
      }

      await conn.query('UPDATE stock_branch_items SET qty = :q WHERE item_id = :i AND branch_id = :b', { q: newQty, i: itemId, b: branch });
      await conn.query('UPDATE stock_items SET unit_cost = :c WHERE id = :id', { c: avgCost, id: itemId });
      await conn.query(
        `INSERT INTO stock_movements (item_id, type, qty, unit_cost, note, created_by, branch_id) VALUES (:item, :type, :qty, :cost, :note, :user, :b)`,
        { item: itemId, type, qty: Math.abs(delta), cost: isPurchase ? cost : 0, note, user: req.user?.id ?? null, b: branch }
      );
      if (isPurchase) {
        // Satu sumber kebenaran: pembelian tercatat sebagai transaksi belanja otomatis.
        await conn.query(
          `INSERT INTO transactions (type, category, amount, note, created_by, branch_id)
           VALUES ('expense', 'belanja', :amount, :note, :user, :b)`,
          {
            amount: Math.round(qtyNum * cost),
            note: `Pembelian ${item.name} ${qtyNum} ${item.unit} @${Math.round(cost).toLocaleString('id-ID')}`,
            user: req.user?.id ?? null,
            b: branch,
          }
        );
      }
      await conn.commit();
      res.json({ id: itemId, name: item.name, unit: item.unit, qty: newQty, branch_id: branch, unit_cost: Math.round(avgCost * 100) / 100, purchase_recorded: isPurchase ? Math.round(qtyNum * cost) : 0 });
    } catch (e) {
      await conn.rollback().catch(() => {});
      throw e;
    } finally {
      conn.release();
    }
  } catch (e) { next(e); }
});

// POST /api/stock/transfer — pindahkan stok antar cabang
// { item_id, from_branch_id, to_branch_id, qty, note? }. Mengurangi cabang asal,
// menambah cabang tujuan (dua pergerakan transfer_out/transfer_in). Bukan pembelian
// maupun pemakaian: tidak memengaruhi HPP / kas / harga rata-rata.
router.post('/transfer', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const itemId = Number(req.body.item_id);
    const from = Number(req.body.from_branch_id);
    const to = Number(req.body.to_branch_id);
    const qtyNum = Number(req.body.qty);
    const note = req.body.note ? String(req.body.note).slice(0, 120) : null;
    if (!itemId || !from || !to) return res.status(400).json({ error: 'Bahan, cabang asal, dan cabang tujuan wajib diisi' });
    if (from === to) return res.status(400).json({ error: 'Cabang asal dan tujuan harus berbeda' });
    if (!(qtyNum > 0)) return res.status(400).json({ error: 'Qty transfer harus lebih dari 0' });
    const locked = await lockedBranchId(req.user);
    if (locked && locked !== from) return res.status(403).json({ error: 'Anda hanya bisa mentransfer dari cabang Anda sendiri' });

    const [branches] = await conn.query('SELECT id, name FROM branches WHERE id IN (:a, :b) AND is_active = 1', { a: from, b: to });
    if (branches.length !== 2) return res.status(400).json({ error: 'Cabang tidak valid' });
    const nameOf = Object.fromEntries(branches.map((b) => [b.id, b.name]));

    await conn.beginTransaction();
    const [[item]] = await conn.query('SELECT id, name, unit FROM stock_items WHERE id = :id AND is_active = 1', { id: itemId });
    if (!item) { await conn.rollback(); return res.status(404).json({ error: 'Bahan tidak ditemukan' }); }
    await ensureStockRow(conn, itemId, from);
    await ensureStockRow(conn, itemId, to);
    // Kunci dua baris dengan urutan branch_id konsisten (hindari deadlock).
    const [locks] = await conn.query(
      'SELECT branch_id, qty FROM stock_branch_items WHERE item_id = :i AND branch_id IN (:a, :b) ORDER BY branch_id FOR UPDATE',
      { i: itemId, a: from, b: to }
    );
    const fromRow = locks.find((r) => r.branch_id === from);
    if (Number(fromRow.qty) < qtyNum) {
      await conn.rollback();
      return res.status(400).json({ error: `Stok ${item.name} di ${nameOf[from]} tidak cukup (tersedia ${Number(fromRow.qty)} ${item.unit})` });
    }
    await conn.query('UPDATE stock_branch_items SET qty = qty - :q WHERE item_id = :i AND branch_id = :b', { q: qtyNum, i: itemId, b: from });
    await conn.query('UPDATE stock_branch_items SET qty = qty + :q WHERE item_id = :i AND branch_id = :b', { q: qtyNum, i: itemId, b: to });
    const suffix = note ? ` — ${note}` : '';
    await conn.query(
      `INSERT INTO stock_movements (item_id, type, qty, note, created_by, branch_id) VALUES
        (:i, 'transfer_out', :q, :n1, :u, :from), (:i, 'transfer_in', :q, :n2, :u, :to)`,
      { i: itemId, q: qtyNum, n1: `Transfer ke ${nameOf[to]}${suffix}`, n2: `Transfer dari ${nameOf[from]}${suffix}`, u: req.user?.id ?? null, from, to }
    );
    await conn.commit();
    res.status(201).json({ ok: true, item_id: itemId, qty: qtyNum, from_branch_id: from, to_branch_id: to });
  } catch (e) {
    await conn.rollback().catch(() => {});
    next(e);
  } finally {
    conn.release();
  }
});

// GET /api/stock/movements?item_id=&limit=&branch_id= — riwayat pergerakan
router.get('/movements', async (req, res, next) => {
  try {
    const branch = await resolveBranch(req, { allowAll: true });
    const params = { limit: Math.min(Number(req.query.limit || 15), 100) };
    let where = ' WHERE 1=1';
    if (req.query.item_id) { where += ' AND m.item_id = :item'; params.item = Number(req.query.item_id); }
    where += branchCond('m.branch_id', branch, params);
    const [rows] = await pool.query(
      `SELECT m.id, s.name AS item_name, m.type, m.qty, m.unit_cost, m.note, u.name AS by_name,
              m.branch_id, br.name AS branch_name, m.created_at
       FROM stock_movements m
       JOIN stock_items s ON s.id = m.item_id
       LEFT JOIN users u ON u.id = m.created_by
       LEFT JOIN branches br ON br.id = m.branch_id${where}
       ORDER BY m.created_at DESC, m.id DESC LIMIT :limit`, params
    );
    res.json(rows.map((r) => ({ ...r, qty: Number(r.qty) })));
  } catch (e) { next(e); }
});

// DELETE /api/stock/:id — soft delete (katalog bersama, berlaku semua cabang)
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
