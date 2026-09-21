import { Router } from 'express';
import { pool } from '../db.js';
import { requireRole } from '../auth.js';

const router = Router();

async function getSettings() {
  const [rows] = await pool.query('SELECT `key`, `value` FROM settings');
  const s = {};
  for (const r of rows) s[r.key] = r.value;
  return {
    tax_rate: Number(s.tax_rate ?? 0),
    service_rate: Number(s.service_rate ?? 0),
    store_name: s.store_name ?? 'Juragan Seblak',
    store_address: s.store_address ?? '',
    store_phone: s.store_phone ?? '',
    receipt_footer: s.receipt_footer ?? '',
  };
}

// Nomor pesanan: JS-YYYYMMDD-NNNN (urut per hari, tanggal lokal — bukan UTC
// agar tidak mundur sehari antara 00:00–07:00 WIB)
async function nextOrderNo(conn) {
  const d = new Date();
  const today = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
  const prefix = `JS-${today}-`;
  const [[row]] = await conn.query(
    'SELECT order_no FROM orders WHERE order_no LIKE :p ORDER BY order_no DESC LIMIT 1',
    { p: `${prefix}%` }
  );
  const next = row ? Number(row.order_no.slice(-4)) + 1 : 1;
  return prefix + String(next).padStart(4, '0');
}

// POST /api/orders — checkout POS.
// Body: { items: [{ product_id, qty, note? }], pay_method, paid_amount?,
//         customer_name?, table_no?, channel?, discount? }
// Harga/pajak/service SELALU dihitung ulang server-side dari DB.
router.post('/', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const { items, pay_method = 'cash', paid_amount = null, customer_name = null, table_no = null, channel = 'pos', discount = 0 } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Keranjang kosong' });
    }
    if (!['cash', 'qris', 'debit'].includes(pay_method)) {
      return res.status(400).json({ error: 'Metode bayar tidak valid' });
    }

    await conn.beginTransaction();

    // Ambil harga produk terbaru dari DB (+ mapping bahan untuk sinkron stok)
    const ids = items.map((i) => Number(i.product_id));
    const [products] = await conn.query(
      `SELECT id, name, price, stock_item_id, stock_qty_per_unit FROM products WHERE id IN (?) AND is_active = 1 AND is_available = 1`,
      [ids]
    );
    const byId = Object.fromEntries(products.map((p) => [p.id, p]));
    for (const it of items) {
      if (!byId[Number(it.product_id)]) {
        await conn.rollback();
        return res.status(400).json({ error: `Produk ${it.product_id} tidak tersedia` });
      }
    }

    const settings = await getSettings();
    const subtotal = items.reduce((sum, it) => sum + Number(byId[it.product_id].price) * it.qty, 0);
    const tax = Math.round(subtotal * settings.tax_rate);
    const service = Math.round(subtotal * settings.service_rate);
    const total = subtotal + tax + service - Number(discount);

    const orderNo = await nextOrderNo(conn);

    // Pesanan otomatis masuk shift aktif kasir (bila ada)
    const [[openShift]] = await conn.query(
      'SELECT id FROM shifts WHERE user_id = :u AND closed_at IS NULL ORDER BY id DESC LIMIT 1',
      { u: req.user?.id ?? 0 }
    );

    const [orderResult] = await conn.query(
      `INSERT INTO orders (order_no, channel, customer_name, table_no, subtotal,
        tax_amount, service_amount, discount, total, pay_method, paid_amount, status, cashier_id, shift_id)
       VALUES (:order_no, :channel, :customer, :table_no, :subtotal,
        :tax, :service, :discount, :total, :pay_method, :paid, 'paid', :cashier, :shift)`,
      { order_no: orderNo, channel, customer: customer_name, table_no, subtotal, tax, service, discount, total, pay_method, paid: paid_amount, cashier: req.user?.id ?? null, shift: openShift?.id ?? null }
    );
    const orderId = orderResult.insertId;

    const orderItems = [];
    for (const it of items) {
      const p = byId[it.product_id];
      await conn.query(
        'INSERT INTO order_items (order_id, product_id, qty, unit_price, note) VALUES (:o, :p, :q, :up, :n)',
        { o: orderId, p: p.id, q: it.qty, up: p.price, n: it.note || null }
      );
      orderItems.push({ product_id: p.id, name: p.name, qty: it.qty, unit_price: Number(p.price), note: it.note || null });

      // Kurangi bahan baku: pakai mapping stock_item_id bila diatur,
      // fallback ke bahan dengan nama sama. Qty mengikuti stock_qty_per_unit.
      const mappedId = p.stock_item_id ?? null;
      let stockId = mappedId;
      if (!stockId) {
        const [byName] = await conn.query(
          'SELECT id FROM stock_items WHERE name = :name AND is_active = 1 LIMIT 1', { name: p.name }
        );
        stockId = byName.length ? byName[0].id : null;
      }
      if (stockId) {
        const used = Number(p.stock_qty_per_unit || 1) * it.qty;
        await conn.query('UPDATE stock_items SET qty = GREATEST(qty - :used, 0) WHERE id = :id', { used, id: stockId });
        await conn.query(
          `INSERT INTO stock_movements (item_id, type, qty, note, created_by) VALUES (:item, 'out', :used, :note, :user)`,
          { item: stockId, used, note: `Penjualan ${orderNo}`, user: req.user?.id ?? null }
        );
      }
    }

    // Catat pemasukan otomatis
    await conn.query(
      `INSERT INTO transactions (type, category, amount, note, ref_order) VALUES ('income', 'penjualan', :total, :note, :ref)`,
      { total, note: `Penjualan ${orderNo}`, ref: orderId }
    );

    await conn.commit();

    res.status(201).json({
      id: orderId,
      order_no: orderNo,
      channel,
      customer_name,
      table_no,
      subtotal,
      tax_amount: tax,
      service_amount: service,
      discount: Number(discount),
      total,
      pay_method,
      paid_amount,
      status: 'paid',
      store_name: settings.store_name,
      store_address: settings.store_address,
      store_phone: settings.store_phone,
      receipt_footer: settings.receipt_footer,
      items: orderItems,
    });
  } catch (e) {
    await conn.rollback().catch(() => {});
    next(e);
  } finally {
    conn.release();
  }
});

// GET /api/orders?from=YYYY-MM-DD&to=YYYY-MM-DD&status=
router.get('/', async (req, res, next) => {
  try {
    const cond = [];
    const params = {};
    if (req.query.from) { cond.push('o.created_at >= :from'); params.from = `${req.query.from} 00:00:00`; }
    if (req.query.to) { cond.push('o.created_at <= :to'); params.to = `${req.query.to} 23:59:59`; }
    if (req.query.status) { cond.push('o.status = :status'); params.status = req.query.status; }
    const where = cond.length ? ` WHERE ${cond.join(' AND ')}` : '';
    const [rows] = await pool.query(
      `SELECT o.id, o.order_no, o.channel, o.customer_name, o.table_no, o.subtotal,
              o.tax_amount, o.service_amount, o.discount, o.total, o.pay_method,
              o.paid_amount, o.status, o.void_reason, o.voided_at,
              u.name AS cashier_name, o.created_at
       FROM orders o LEFT JOIN users u ON u.id = o.cashier_id${where}
       ORDER BY o.created_at DESC LIMIT 500`, params
    );
    res.json(rows.map((r) => ({
      ...r,
      subtotal: Number(r.subtotal), tax_amount: Number(r.tax_amount),
      service_amount: Number(r.service_amount), discount: Number(r.discount),
      total: Number(r.total), paid_amount: r.paid_amount == null ? null : Number(r.paid_amount),
    })));
  } catch (e) { next(e); }
});

// GET /api/orders/:id — detail + item (untuk struk ulang / void nanti)
router.get('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const [[order]] = await pool.query(
      `SELECT o.*, u.name AS cashier_name FROM orders o LEFT JOIN users u ON u.id = o.cashier_id WHERE o.id = :id`,
      { id }
    );
    if (!order) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    const [items] = await pool.query(
      'SELECT oi.product_id, p.name, oi.qty, oi.unit_price, oi.note FROM order_items oi JOIN products p ON p.id = oi.product_id WHERE oi.order_id = :id',
      { id }
    );
    res.json({
      ...order,
      subtotal: Number(order.subtotal), tax_amount: Number(order.tax_amount),
      service_amount: Number(order.service_amount), discount: Number(order.discount),
      total: Number(order.total),
      items: items.map((i) => ({ ...i, unit_price: Number(i.unit_price) })),
    });
  } catch (e) { next(e); }
});

// POST /api/orders/:id/void — batalkan pesanan (owner/admin).
// Membatalkan omzet: status jadi canceled + transaksi penjualan dibalik
// dengan catatan pengeluaran kategori 'void'. Stok tidak dikembalikan otomatis.
router.post('/:id/void', requireRole('owner', 'admin'), async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const id = Number(req.params.id);
    const { reason } = req.body || {};
    if (!reason || !String(reason).trim()) {
      return res.status(400).json({ error: 'Alasan void wajib diisi' });
    }

    await conn.beginTransaction();
    const [[order]] = await conn.query(
      'SELECT id, order_no, total, status FROM orders WHERE id = :id FOR UPDATE', { id }
    );
    if (!order) { await conn.rollback(); return res.status(404).json({ error: 'Pesanan tidak ditemukan' }); }
    if (order.status === 'canceled') { await conn.rollback(); return res.status(409).json({ error: 'Pesanan sudah dibatalkan' }); }

    await conn.query(
      `UPDATE orders SET status = 'canceled', void_reason = :reason, voided_at = NOW(), voided_by = :by WHERE id = :id`,
      { reason, by: req.user.id, id }
    );
    await conn.query(
      `INSERT INTO transactions (type, category, amount, note, ref_order, created_by)
       VALUES ('expense', 'void', :total, :note, :ref, :by)`,
      { total: order.total, note: `Void ${order.order_no}: ${reason}`, ref: id, by: req.user.id }
    );
    await conn.commit();

    res.json({ ok: true, id, status: 'canceled' });
  } catch (e) {
    await conn.rollback().catch(() => {});
    next(e);
  } finally {
    conn.release();
  }
});

export default router;
