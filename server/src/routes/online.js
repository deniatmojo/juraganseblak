import crypto from 'node:crypto';
import { Router } from 'express';
import { pool } from '../db.js';
import { requireAuth, requireRole } from '../auth.js';
import { nextOrderNo } from './orders.js';

// Router pesanan online (publik — dipasang SEBELUM guard auth global di
// index.js). Endpoint pelanggan (menu, buat pesanan, lacak) terbuka tanpa
// login; endpoint kasir (update tahap pesanan) memakai requireAuth sendiri.

const router = Router();

const PROGRESS_STEPS = ['queue', 'processing', 'ready', 'done'];

async function getSettings() {
  const [rows] = await pool.query('SELECT `key`, `value` FROM settings');
  const s = {};
  for (const r of rows) s[r.key] = r.value;
  return {
    store_name: s.store_name ?? 'Juragan Seblak',
    store_address: s.store_address ?? '',
    store_phone: s.store_phone ?? '',
    tax_rate: Number(s.tax_rate ?? 0),
    service_rate: Number(s.service_rate ?? 0),
    // QRIS statis ditampilkan ke pelanggan untuk dibayar manual;
    // acc pembayaran sementara manual oleh admin kasir sampai
    // payment gateway aktif (webhook akan otomatis melunasi nanti).
    qris_static_image: s.qris_static_image ?? null,
    qris_static_merchant: s.qris_static_merchant ?? null,
    payment_gateway: s.payment_gateway ?? 'none',
  };
}

// GET /api/online/store — info toko + QRIS statis untuk halaman publik.
// Hanya field aman yang dikirim (tidak ada kunci gateway).
router.get('/store', async (_req, res, next) => {
  try {
    res.json(await getSettings());
  } catch (e) { next(e); }
});

// GET /api/online/menu — daftar menu aktif & tersedia untuk dipesan online.
router.get('/menu', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT p.id, p.name, p.price, p.image_url, c.label AS category
       FROM products p JOIN categories c ON c.id = p.category_id
       WHERE p.is_active = 1 AND p.is_available = 1
       ORDER BY c.sort_order, p.id`
    );
    res.json(rows.map((r) => ({ ...r, price: Number(r.price) })));
  } catch (e) { next(e); }
});

// GET /api/online/tables — daftar meja dine-in (publik: dipakai halaman
// /order?meja=ID untuk menampilkan label meja & admin untuk kelola + QR).
router.get('/tables', async (_req, res, next) => {
  try {
    res.json(await pool.query('SELECT id, label, is_active FROM dining_tables ORDER BY id').then(([rows]) => rows));
  } catch (e) { next(e); }
});

// GET /api/online/tables/:id — validasi satu meja (publik, dari QR di meja).
router.get('/tables/:id', async (req, res, next) => {
  try {
    const [[row]] = await pool.query('SELECT id, label, is_active FROM dining_tables WHERE id = :id', { id: Number(req.params.id) });
    if (!row || !row.is_active) return res.status(404).json({ error: 'Meja tidak ditemukan' });
    res.json(row);
  } catch (e) { next(e); }
});

// POST /api/online/tables — tambah meja (owner/admin).
router.post('/tables', requireAuth, requireRole('owner', 'admin'), async (req, res, next) => {
  try {
    const label = String(req.body?.label || '').trim();
    if (!label) return res.status(400).json({ error: 'Nama/label meja wajib diisi' });
    const [[dup]] = await pool.query('SELECT id FROM dining_tables WHERE label = :l', { l: label });
    if (dup) return res.status(409).json({ error: `Meja "${label}" sudah ada` });
    const [result] = await pool.query('INSERT INTO dining_tables (label) VALUES (:l)', { l: label });
    res.status(201).json({ id: result.insertId, label, is_active: 1 });
  } catch (e) { next(e); }
});

// PATCH /api/online/tables/:id — ubah label / aktifkan-nonaktifkan meja.
router.patch('/tables/:id', requireAuth, requireRole('owner', 'admin'), async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const [[row]] = await pool.query('SELECT id FROM dining_tables WHERE id = :id', { id });
    if (!row) return res.status(404).json({ error: 'Meja tidak ditemukan' });
    const updates = [];
    const params = { id };
    if (req.body?.label != null) {
      const label = String(req.body.label).trim();
      if (!label) return res.status(400).json({ error: 'Nama/label meja tidak boleh kosong' });
      updates.push('label = :label');
      params.label = label;
    }
    if (req.body?.is_active != null) {
      updates.push('is_active = :act');
      params.act = req.body.is_active ? 1 : 0;
    }
    if (updates.length) await pool.query(`UPDATE dining_tables SET ${updates.join(', ')} WHERE id = :id`, params);
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// DELETE /api/online/tables/:id — hapus meja (QR lama di meja jadi tidak valid).
router.delete('/tables/:id', requireAuth, requireRole('owner', 'admin'), async (req, res, next) => {
  try {
    const [result] = await pool.query('DELETE FROM dining_tables WHERE id = :id', { id: Number(req.params.id) });
    if (!result.affectedRows) return res.status(404).json({ error: 'Meja tidak ditemukan' });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// POST /api/online/orders — pesanan baru dari pelanggan (tanpa login).
// Body: { customer_name, customer_phone, order_type, items:[{product_id, qty, note?}],
//         schedule_date?, schedule_time?, delivery_address?, note? }
// Pesanan tersimpan channel='online', status='pending', pay_method='qris';
// harga/pajak/service dihitung ulang server-side, stok dipotong saat
// pembayaran dilunaskan (markOrderPaid).
router.post('/orders', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const {
      customer_name, customer_phone, order_type,
      items, schedule_date = null, schedule_time = null,
      delivery_address = null, note = null, table_id = null,
    } = req.body || {};

    // Pesanan dari QR meja: meja adalah identitasnya — nama/HP opsional,
    // tipe paksa dine-in, table_no terisi otomatis (pelayan antar ke meja),
    // pembayaran langsung di meja lalu kasir meng-ACC.
    let table = null;
    if (table_id != null) {
      const [[t]] = await conn.query('SELECT id, label FROM dining_tables WHERE id = :id AND is_active = 1', { id: Number(table_id) });
      if (!t) {
        return res.status(400).json({ error: 'QR meja tidak valid' });
      }
      table = t;
    }

    let ordererName = customer_name ? String(customer_name).trim() : null;
    if (!table && !ordererName) {
      return res.status(400).json({ error: 'Nama wajib diisi' });
    }
    if (table) {
      ordererName = ordererName || `Tamu Meja ${table.label}`;
    }
    const phone = String(customer_phone || '').replace(/[^\d+]/g, '');
    if (!table && phone.replace(/\D/g, '').length < 8) {
      return res.status(400).json({ error: 'Nomor HP/WhatsApp tidak valid' });
    }
    const effectiveType = table ? 'dinein' : order_type;
    if (!['dinein', 'delivery', 'pickup'].includes(effectiveType)) {
      return res.status(400).json({ error: 'Tipe pesanan tidak valid' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Keranjang kosong' });
    }
    if (effectiveType === 'delivery' && !delivery_address?.trim()) {
      return res.status(400).json({ error: 'Alamat pengiriman wajib diisi' });
    }
    let scheduleAt = null;
    if (effectiveType === 'dinein' && !table) {
      if (!schedule_date || !schedule_time) {
        return res.status(400).json({ error: 'Tanggal & jam kedatangan wajib diisi' });
      }
      scheduleAt = `${schedule_date} ${schedule_time}:00`;
    }

    await conn.beginTransaction();

    const ids = items.map((i) => Number(i.product_id));
    const [products] = await conn.query(
      `SELECT id, name, price FROM products WHERE id IN (?) AND is_active = 1 AND is_available = 1`,
      [ids]
    );
    const byId = Object.fromEntries(products.map((p) => [p.id, p]));
    for (const it of items) {
      if (!byId[Number(it.product_id)]) {
        await conn.rollback();
        return res.status(400).json({ error: 'Ada menu yang tidak tersedia, muat ulang halaman' });
      }
    }

    const settings = await getSettings();
    const subtotal = items.reduce((sum, it) => sum + Number(byId[Number(it.product_id)].price) * Number(it.qty || 0), 0);
    if (!(subtotal > 0)) {
      await conn.rollback();
      return res.status(400).json({ error: 'Jumlah pesanan tidak valid' });
    }
    const tax = Math.round(subtotal * settings.tax_rate);
    const service = Math.round(subtotal * settings.service_rate);
    const total = subtotal + tax + service;

    const orderNo = await nextOrderNo(conn);
    const trackCode = crypto.randomBytes(4).toString('hex'); // 8 karakter acak

    const [orderResult] = await conn.query(
      `INSERT INTO orders (order_no, channel, customer_name, customer_phone, order_type,
        schedule_at, table_no, delivery_address, customer_note, subtotal,
        tax_amount, service_amount, total, pay_method, status, track_code)
       VALUES (:order_no, 'online', :customer, :phone, :order_type,
        :schedule_at, :table_no, :address, :note, :subtotal,
        :tax, :service, :total, 'qris', 'pending', :track_code)`,
      {
        order_no: orderNo, customer: ordererName, phone: phone || null,
        order_type: effectiveType, schedule_at: scheduleAt, table_no: table?.label ?? null,
        address: delivery_address?.trim() || null,
        note: note?.trim() || null, subtotal, tax, service, total, track_code: trackCode,
      }
    );
    const orderId = orderResult.insertId;

    const orderItems = [];
    for (const it of items) {
      const p = byId[Number(it.product_id)];
      const qty = Math.max(1, Math.floor(Number(it.qty || 1)));
      await conn.query(
        'INSERT INTO order_items (order_id, product_id, qty, unit_price, note) VALUES (:o, :p, :q, :up, :n)',
        { o: orderId, p: p.id, q: qty, up: p.price, n: it.note || null }
      );
      orderItems.push({ product_id: p.id, name: p.name, qty, unit_price: Number(p.price) });
    }

    await conn.commit();
    res.status(201).json({
      id: orderId,
      order_no: orderNo,
      track_code: trackCode,
      order_type: effectiveType,
      table_no: table?.label ?? null,
      customer_name,
      subtotal, tax_amount: tax, service_amount: service, total,
      status: 'pending',
      store_name: settings.store_name,
      items: orderItems,
    });
  } catch (e) {
    await conn.rollback().catch(() => {});
    next(e);
  } finally {
    conn.release();
  }
});

// GET /api/online/track/:orderNo?code=xx atau ?phone=08xxx — lacak pesanan
// dari halaman publik. Akses diterima bila kode pelacakan cocok ATAU nomor HP
// cocok (dipakai pelanggan yang kehilangan kode pelacakannya).
router.get('/track/:orderNo', async (req, res, next) => {
  try {
    const code = String(req.query.code || '');
    const phone = String(req.query.phone || '').replace(/\D/g, '');
    if (!code && phone.length < 4) {
      return res.status(400).json({ error: 'Kode pelacakan atau nomor HP wajib diisi' });
    }
    const [[order]] = await pool.query(
      `SELECT id, order_no, channel, customer_name, customer_phone, order_type,
              schedule_at, table_no, delivery_address, customer_note,
              subtotal, tax_amount, service_amount, total, pay_method, status,
              progress, progress_updated_at, paid_at, created_at, track_code
       FROM orders WHERE order_no = :no`,
      { no: req.params.orderNo }
    );
    if (!order || order.channel !== 'online') {
      return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    }
    const codeOk = order.track_code && code && code === order.track_code;
    const phoneOk = phone.length >= 4 && order.customer_phone?.replace(/\D/g, '').endsWith(phone);
    if (!codeOk && !phoneOk) {
      return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    }
    const [items] = await pool.query(
      'SELECT oi.product_id, p.name, oi.qty, oi.unit_price, oi.note FROM order_items oi JOIN products p ON p.id = oi.product_id WHERE oi.order_id = :id',
      { id: order.id }
    );
    res.json({
      ...order,
      subtotal: Number(order.subtotal), tax_amount: Number(order.tax_amount),
      service_amount: Number(order.service_amount), total: Number(order.total),
      items: items.map((i) => ({ ...i, unit_price: Number(i.unit_price) })),
    });
  } catch (e) { next(e); }
});

// PATCH /api/online/progress — admin kasir memperbarui tahap pesanan online
// (antrian > diproses > siap/diantar > selesai). Terbuka untuk kasir juga.
router.patch('/progress', requireAuth, requireRole('owner', 'admin', 'kasir'), async (req, res, next) => {
  try {
    const orderId = Number(req.body?.order_id);
    const progress = req.body?.progress;
    if (!PROGRESS_STEPS.includes(progress)) {
      return res.status(400).json({ error: 'Tahap pesanan tidak valid' });
    }
    const [[order]] = await pool.query('SELECT id, channel, status FROM orders WHERE id = :id', { id: orderId });
    if (!order) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    if (order.channel !== 'online') return res.status(409).json({ error: 'Bukan pesanan online' });
    if (order.status === 'pending') return res.status(409).json({ error: 'Pembayaran belum di-ACC' });
    if (order.status === 'canceled') return res.status(409).json({ error: 'Pesanan sudah dibatalkan' });
    await pool.query(
      'UPDATE orders SET progress = :p, progress_updated_at = NOW() WHERE id = :id',
      { p: progress, id: orderId }
    );
    res.json({ ok: true, id: orderId, progress });
  } catch (e) { next(e); }
});

export default router;
