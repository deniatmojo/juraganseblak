import crypto from 'node:crypto';
import { Router } from 'express';
import { pool } from '../db.js';
import { requireAuth, requireRole } from '../auth.js';
import { nextOrderNo, parseOrderItems } from './orders.js';
import { resolveBranch, mainBranchId, branchIsOpen } from '../branch.js';
import { computeTotals } from '../pricing.js';

// Router pesanan online (publik — dipasang SEBELUM guard auth global di
// index.js). Endpoint pelanggan (menu, buat pesanan, lacak) terbuka tanpa
// login; endpoint kasir (update tahap pesanan) memakai requireAuth sendiri.

const router = Router();

const PROGRESS_STEPS = ['queue', 'processing', 'ready', 'done'];

// QRIS statis per cabang: kunci qris_static_image_b<id> / qris_static_merchant_b<id>;
// cabang tanpa QRIS sendiri memakai QRIS umum (qris_static_image / _merchant).
function qrisFor(s, branchId) {
  const b = branchId ? `_b${Number(branchId)}` : null;
  return {
    qris_static_image: (b && s[`qris_static_image${b}`]) || s.qris_static_image || null,
    qris_static_merchant: (b && s[`qris_static_merchant${b}`]) || s.qris_static_merchant || null,
  };
}

async function getSettings(branchId = null) {
  const [rows] = await pool.query('SELECT `key`, `value` FROM settings');
  const s = {};
  for (const r of rows) s[r.key] = r.value;
  return {
    store_name: s.store_name ?? 'Juragan Seblak',
    store_address: s.store_address ?? '',
    store_phone: s.store_phone ?? '',
    tax_rate: Number(s.tax_rate ?? 0),
    service_rate: Number(s.service_rate ?? 0),
    rounding_step: Number(s.rounding_step ?? 0),
    // QRIS statis ditampilkan ke pelanggan untuk dibayar manual;
    // acc pembayaran sementara manual oleh admin kasir sampai
    // payment gateway aktif (webhook akan otomatis melunasi nanti).
    ...qrisFor(s, branchId),
    payment_gateway: s.payment_gateway ?? 'none',
  };
}

// GET /api/online/store — info toko + QRIS statis untuk halaman publik.
// Hanya field aman yang dikirim (tidak ada kunci gateway).
router.get('/store', async (req, res, next) => {
  try {
    res.json(await getSettings(Number(req.query.branch_id) || null));
  } catch (e) { next(e); }
});

// GET /api/online/branches — cabang aktif (publik) untuk memilih cabang pada
// pesanan delivery/pickup/reservasi di halaman /order.
router.get('/branches', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT b.id, b.name, b.address,
              EXISTS (SELECT 1 FROM shifts s WHERE s.branch_id = b.id AND s.closed_at IS NULL) AS is_open
       FROM branches b WHERE b.is_active = 1 ORDER BY b.id`
    );
    res.json(rows.map((r) => ({ ...r, is_open: Boolean(r.is_open) })));
  } catch (e) { next(e); }
});

// GET /api/online/menu — daftar menu aktif & tersedia untuk dipesan online.
// category_key dipakai halaman pemesanan membedakan porsi prasmanan
// (kuah/topping) dari item biasa (minuman).
router.get('/menu', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT p.id, p.name, p.price, p.image_url, c.label AS category, c.\`key\` AS category_key
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
    res.json(await pool.query(
      `SELECT t.id, t.label, t.is_active, t.branch_id, b.name AS branch_name
       FROM dining_tables t LEFT JOIN branches b ON b.id = t.branch_id ORDER BY t.id`
    ).then(([rows]) => rows));
  } catch (e) { next(e); }
});

// GET /api/online/tables/:id — validasi satu meja (publik, dari QR di meja).
router.get('/tables/:id', async (req, res, next) => {
  try {
    const [[row]] = await pool.query(
      `SELECT t.id, t.label, t.is_active, t.branch_id, b.name AS branch_name
       FROM dining_tables t LEFT JOIN branches b ON b.id = t.branch_id WHERE t.id = :id`,
      { id: Number(req.params.id) }
    );
    if (!row || !row.is_active) return res.status(404).json({ error: 'Meja tidak ditemukan' });
    res.json({ ...row, is_open: await branchIsOpen(row.branch_id ?? await mainBranchId()) });
  } catch (e) { next(e); }
});

// POST /api/online/tables — tambah meja (owner/admin).
router.post('/tables', requireAuth, requireRole('owner', 'admin'), async (req, res, next) => {
  try {
    const label = String(req.body?.label || '').trim();
    if (!label) return res.status(400).json({ error: 'Nama/label meja wajib diisi' });
    const branch = await resolveBranch(req);
    const [[dup]] = await pool.query('SELECT id FROM dining_tables WHERE label = :l AND branch_id = :b', { l: label, b: branch });
    if (dup) return res.status(409).json({ error: `Meja "${label}" sudah ada di cabang ini` });
    const [result] = await pool.query('INSERT INTO dining_tables (label, branch_id) VALUES (:l, :b)', { l: label, b: branch });
    res.status(201).json({ id: result.insertId, label, is_active: 1, branch_id: branch });
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
    if (req.body?.branch_id != null && req.user.role === 'owner') {
      const b = Number(req.body.branch_id);
      const [[br]] = await pool.query('SELECT id FROM branches WHERE id = :b AND is_active = 1', { b });
      if (!br) return res.status(400).json({ error: 'Cabang tidak valid' });
      updates.push('branch_id = :branch');
      params.branch = b;
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
      const [[t]] = await conn.query('SELECT id, label, branch_id FROM dining_tables WHERE id = :id AND is_active = 1', { id: Number(table_id) });
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
    // Cabang pesanan: meja QR membawa cabangnya sendiri; delivery/pickup/reservasi
    // dipilih pelanggan (otomatis bila hanya ada satu cabang aktif).
    let branchId = table ? (table.branch_id ?? await mainBranchId(conn)) : null;
    if (!branchId) {
      const [active] = await conn.query('SELECT id FROM branches WHERE is_active = 1');
      const wanted = Number(req.body?.branch_id);
      if (wanted && active.some((b) => b.id === wanted)) branchId = wanted;
      else if (active.length === 1) branchId = active[0].id;
      else return res.status(400).json({ error: 'Pilih cabang tujuan pesanan' });
    }
    if (!(await branchIsOpen(branchId, conn))) {
      return res.status(409).json({ error: 'Maaf, cabang ini sedang tutup dan belum menerima pesanan. Silakan coba lagi saat buka.', code: 'BRANCH_CLOSED' });
    }
    const effectiveType = table ? 'dinein' : order_type;
    if (!['dinein', 'delivery', 'pickup'].includes(effectiveType)) {
      return res.status(400).json({ error: 'Tipe pesanan tidak valid' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Keranjang kosong' });
    }
    const parsed = parseOrderItems(items);
    if (parsed.error) return res.status(400).json({ error: parsed.error });
    const lines = parsed.lines;
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

    // Harga + kategori produk terbaru dari DB (validasi peran kuah/topping).
    const [products] = await conn.query(
      `SELECT p.id, p.name, p.price, c.\`key\` AS category_key
       FROM products p JOIN categories c ON c.id = p.category_id
       WHERE p.id IN (?) AND p.is_active = 1 AND p.is_available = 1`,
      [lines.map((l) => l.product_id)]
    );
    const byId = Object.fromEntries(products.map((p) => [p.id, p]));
    for (const l of lines) {
      const p = byId[l.product_id];
      if (!p) {
        await conn.rollback();
        return res.status(400).json({ error: 'Ada menu yang tidak tersedia, muat ulang halaman' });
      }
      if (l.item_role === 'kuah' && p.category_key !== 'kuah') {
        await conn.rollback();
        return res.status(400).json({ error: 'Jenis kuah tidak valid — pilih dari daftar Jenis Kuah' });
      }
      if (l.item_role === 'topping' && p.category_key !== 'topping') {
        await conn.rollback();
        return res.status(400).json({ error: 'Topping tidak valid — pilih dari daftar Topping Seblak' });
      }
    }

    const settings = await getSettings();
    const subtotal = lines.reduce((sum, l) => sum + Number(byId[l.product_id].price) * l.qty, 0);
    if (!(subtotal > 0)) {
      await conn.rollback();
      return res.status(400).json({ error: 'Jumlah pesanan tidak valid' });
    }
    const { tax, service, rounding, total } = computeTotals(subtotal, settings);

    const orderNo = await nextOrderNo(conn);
    const trackCode = crypto.randomBytes(4).toString('hex'); // 8 karakter acak

    const [orderResult] = await conn.query(
      `INSERT INTO orders (order_no, channel, customer_name, customer_phone, order_type,
        schedule_at, table_no, delivery_address, customer_note, subtotal,
        tax_amount, service_amount, rounding_amount, total, pay_method, status, track_code, branch_id)
       VALUES (:order_no, 'online', :customer, :phone, :order_type,
        :schedule_at, :table_no, :address, :note, :subtotal,
        :tax, :service, :rounding, :total, 'qris', 'pending', :track_code, :branch)`,
      {
        order_no: orderNo, customer: ordererName, phone: phone || null,
        order_type: effectiveType, schedule_at: scheduleAt, table_no: table?.label ?? null,
        address: delivery_address?.trim() || null,
        note: note?.trim() || null, subtotal, tax, service, rounding, total, track_code: trackCode, branch: branchId,
      }
    );
    const orderId = orderResult.insertId;

    const orderItems = [];
    for (const l of lines) {
      const p = byId[l.product_id];
      await conn.query(
        'INSERT INTO order_items (order_id, product_id, qty, unit_price, note, porsi_no, item_role) VALUES (:o, :p, :q, :up, :n, :porsi, :role)',
        { o: orderId, p: p.id, q: l.qty, up: p.price, n: l.note, porsi: l.porsi_no, role: l.item_role }
      );
      orderItems.push({ product_id: p.id, name: p.name, qty: l.qty, unit_price: Number(p.price), note: l.note, porsi_no: l.porsi_no, item_role: l.item_role });
    }

    await conn.commit();
    res.status(201).json({
      id: orderId,
      order_no: orderNo,
      track_code: trackCode,
      order_type: effectiveType,
      table_no: table?.label ?? null,
      customer_name,
      subtotal, tax_amount: tax, service_amount: service, rounding_amount: rounding, total,
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

// GET /api/online/track-code/:code — cari nomor pesanan dari KODE PELACAKAN saja
// (pelanggan yang tab-nya tertutup/HP-nya refresh cukup menempel kodenya).
// Hanya mengembalikan order_no; detail tetap lewat /track/:orderNo?code=.
router.get('/track-code/:code', async (req, res, next) => {
  try {
    const code = String(req.params.code || '').trim().toLowerCase();
    if (!/^[0-9a-f]{8}$/.test(code)) return res.status(404).json({ error: 'Kode pelacakan tidak ditemukan' });
    const [[row]] = await pool.query(
      "SELECT order_no FROM orders WHERE channel = 'online' AND track_code = :c LIMIT 1", { c: code }
    );
    if (!row) return res.status(404).json({ error: 'Kode pelacakan tidak ditemukan. Periksa lagi kodenya.' });
    res.json({ order_no: row.order_no, code });
  } catch (e) { next(e); }
});

// GET /api/online/track/:orderNo?code=xx atau ?phone=08xxx — lacak pesanan
// dari halaman publik. Akses diterima bila kode pelacakan cocok ATAU nomor HP
// cocok (dipakai pelanggan yang kehilangan kode pelacakannya).
router.get('/track/:orderNo', async (req, res, next) => {
  try {
    const code = String(req.query.code || '');
    const phone = String(req.query.phone || '').replace(/\D/g, '');
    // Tanpa kode & HP → tampilan RINGKAS (hanya nomor pesanan): status & item tanpa
    // data pribadi, karena nomor pesanan berurutan dan mudah ditebak.
    const limited = !code && phone.length < 4;
    const [[order]] = await pool.query(
      `SELECT id, order_no, channel, customer_name, customer_phone, order_type,
              schedule_at, table_no, delivery_address, customer_note,
              subtotal, tax_amount, service_amount, rounding_amount, total, pay_method, status,
              progress, progress_updated_at, paid_at, created_at, track_code, branch_id
       FROM orders WHERE order_no = :no`,
      { no: req.params.orderNo }
    );
    if (!order || order.channel !== 'online') {
      return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    }
    const codeOk = order.track_code && code && code === order.track_code;
    const phoneOk = phone.length >= 4 && order.customer_phone?.replace(/\D/g, '').endsWith(phone);
    if (!limited && !codeOk && !phoneOk) {
      return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    }
    if (limited) {
      const first = String(order.customer_name || '').trim().split(/\s+/)[0] || '';
      order.customer_name = first ? `${first.charAt(0)}${'*'.repeat(Math.min(first.length - 1, 5))}` : 'Pelanggan';
      order.customer_phone = null;
      order.delivery_address = null;
      order.customer_note = null;
      order.track_code = null;
    }
    const [items] = await pool.query(
      'SELECT oi.product_id, p.name, oi.qty, oi.unit_price, oi.note, oi.porsi_no, oi.item_role FROM order_items oi JOIN products p ON p.id = oi.product_id WHERE oi.order_id = :id ORDER BY oi.id',
      { id: order.id }
    );
    const { qris_static_image, qris_static_merchant } = await getSettings(order.branch_id);
    res.json({
      ...order,
      qris_static_image, qris_static_merchant,
      limited,
      subtotal: Number(order.subtotal), tax_amount: Number(order.tax_amount),
      service_amount: Number(order.service_amount), rounding_amount: Number(order.rounding_amount), total: Number(order.total),
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
