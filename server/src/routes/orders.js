import { Router } from 'express';
import { pool } from '../db.js';
import { linksForProducts } from './products.js';
import { requireRole } from '../auth.js';
import { dateCompactWib } from '../wib.js';
import { resolveBranch, deductStock } from '../branch.js';
import { computeTotals } from '../pricing.js';

const router = Router();

async function getSettings() {
  const [rows] = await pool.query('SELECT `key`, `value` FROM settings');
  const s = {};
  for (const r of rows) s[r.key] = r.value;
  return {
    tax_rate: Number(s.tax_rate ?? 0),
    service_rate: Number(s.service_rate ?? 0),
    rounding_step: Number(s.rounding_step ?? 0),
    store_name: s.store_name ?? 'Juragan Seblak',
    store_address: s.store_address ?? '',
    store_phone: s.store_phone ?? '',
    receipt_footer: s.receipt_footer ?? '',
    payment_gateway: s.payment_gateway ?? 'none',
  };
}

// Nomor pesanan: JS-YYYYMMDD-NNNN (urut per hari, tanggal WIB eksplisit —
// mesin server produksi berjalan UTC, agar tidak mundur sehari antara
// 00:00–07:00 WIB)
export async function nextOrderNo(conn) {
  const today = dateCompactWib();
  const prefix = `JS-${today}-`;
  const [[row]] = await conn.query(
    'SELECT order_no FROM orders WHERE order_no LIKE :p ORDER BY order_no DESC LIMIT 1',
    { p: `${prefix}%` }
  );
  const next = row ? Number(row.order_no.slice(-4)) + 1 : 1;
  return prefix + String(next).padStart(4, '0');
}

// Ubah payload `items` (campuran item biasa & porsi prasmanan) menjadi daftar
// baris order_items flat. Porsi prasmanan: { kuah_id, qty, note?, toppings?:
// [{ product_id, qty? }] } — kuah WAJIB (Nyemek/Sedang/Full Kuah); qty tiap
// topping dikali qty porsi. Item biasa (minuman dll): { product_id, qty, note? }.
// Dipakai bersama POST /api/orders dan POST /api/online/orders.
export function parseOrderItems(items) {
  const lines = [];
  let porsiNo = 0;
  for (const it of items) {
    const isPortion = it.kuah_id != null || Array.isArray(it.toppings);
    const qty = Math.max(1, Math.floor(Number(it.qty || 1)));
    if (!isPortion) {
      lines.push({ product_id: Number(it.product_id), qty, note: it.note || null, porsi_no: null, item_role: null });
      continue;
    }
    const kuahId = Number(it.kuah_id);
    if (!kuahId) {
      return { error: 'Setiap porsi wajib memilih jenis kuah (Nyemek, Sedang, atau Full Kuah)' };
    }
    porsiNo += 1;
    lines.push({ product_id: kuahId, qty, note: it.note || null, porsi_no: porsiNo, item_role: 'kuah' });
    // Topping ganda (produk sama) digabung lalu dikali jumlah porsi.
    const merged = new Map();
    for (const t of it.toppings || []) {
      const pid = Number(t.product_id);
      if (!pid) return { error: 'Ada topping yang tidak valid pada porsi' };
      merged.set(pid, (merged.get(pid) || 0) + Math.max(1, Math.floor(Number(t.qty || 1))));
    }
    for (const [pid, toppingQty] of merged) {
      lines.push({ product_id: pid, qty: toppingQty * qty, note: null, porsi_no: porsiNo, item_role: 'topping' });
    }
  }
  return { lines };
}

// POST /api/orders — checkout POS.
// Body: { items: [{ product_id, qty, note? } | { kuah_id, qty, note?,
//         toppings: [{ product_id, qty? }] }], pay_method, paid_amount?,
//         customer_name?, table_no?, channel?, discount?, pending? }
// Harga/pajak/service SELALU dihitung ulang server-side dari DB.
// pending=true (QRIS dinamis via gateway): pesanan disimpan 'pending', stok &
// pemasukan dicatat baru saat webhook gateway / konfirmasi manual melunaskan.
router.post('/', async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const { items, pay_method = 'cash', paid_amount = null, customer_name = null, table_no = null, channel = 'pos', discount = 0, pending = false } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Keranjang kosong' });
    }
    if (!['cash', 'qris', 'debit'].includes(pay_method)) {
      return res.status(400).json({ error: 'Metode bayar tidak valid' });
    }
    const parsed = parseOrderItems(items);
    if (parsed.error) return res.status(400).json({ error: parsed.error });
    const lines = parsed.lines;

    await conn.beginTransaction();

    // Ambil harga + kategori produk terbaru dari DB (validasi peran & sinkron stok)
    const ids = lines.map((l) => l.product_id);
    const [products] = await conn.query(
      `SELECT p.id, p.name, p.price, p.stock_item_id, p.stock_qty_per_unit, c.\`key\` AS category_key
       FROM products p JOIN categories c ON c.id = p.category_id
       WHERE p.id IN (?) AND p.is_active = 1 AND p.is_available = 1`,
      [ids]
    );
    const byId = Object.fromEntries(products.map((p) => [p.id, p]));
    for (const l of lines) {
      const p = byId[l.product_id];
      if (!p) {
        await conn.rollback();
        return res.status(400).json({ error: `Menu ${l.product_id} tidak tersedia, muat ulang halaman` });
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
    // Relasi menu↔bahan (multi-bahan per menu) untuk pemotongan stok.
    const productLinks = await linksForProducts(ids);

    const settings = await getSettings();
    // QRIS dinamis via gateway hanya kalau gateway aktif & kasir minta pending.
    const isPending = pending === true && pay_method === 'qris' && settings.payment_gateway && settings.payment_gateway !== 'none';
    const subtotal = lines.reduce((sum, l) => sum + Number(byId[l.product_id].price) * l.qty, 0);
    const { tax, service, rounding, total } = computeTotals(subtotal, settings, discount);

    const orderNo = await nextOrderNo(conn);

    // Pesanan otomatis masuk shift aktif kasir (bila ada)
    const [[openShift]] = await conn.query(
      'SELECT id, branch_id FROM shifts WHERE user_id = :u AND closed_at IS NULL ORDER BY id DESC LIMIT 1',
      { u: req.user?.id ?? 0 }
    );
    // Cabang transaksi: cabang shift yang sedang terbuka (kasir wajib per cabang);
    // tanpa shift → ditentukan dari akun / body.branch_id.
    const branchId = openShift?.branch_id ?? await resolveBranch(req, { conn });

    const [orderResult] = await conn.query(
      `INSERT INTO orders (order_no, channel, customer_name, table_no, subtotal,
        tax_amount, service_amount, discount, rounding_amount, total, pay_method, paid_amount, status, cashier_id, shift_id, branch_id)
       VALUES (:order_no, :channel, :customer, :table_no, :subtotal,
        :tax, :service, :discount, :rounding, :total, :pay_method, :paid, :status, :cashier, :shift, :branch)`,
      { order_no: orderNo, channel, customer: customer_name, table_no, subtotal, tax, service, discount, rounding, total, pay_method, paid: paid_amount, status: isPending ? 'pending' : 'paid', cashier: req.user?.id ?? null, shift: openShift?.id ?? null, branch: branchId }
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

      if (isPending) continue; // stok dipotong saat pesanan dilunaskan (finalize.js)

      // Kurangi SEMUA bahan baku terhubung ke menu ini (bisa lebih dari satu —
      // mis. bumbu kuah + kerupuk + telur). Bahan pertama tersimpan juga di
      // kolom lama products.stock_item_id; fallback ke bahan bernama sama bila
      // menu belum punya link sama sekali.
      let links = productLinks.get(p.id) || [];
      if (!links.length) {
        const [byName] = await conn.query(
          'SELECT id FROM stock_items WHERE name = :name AND is_active = 1 LIMIT 1', { name: p.name }
        );
        if (byName.length) {
          links = [{ stock_item_id: byName[0].id, qty_per_unit: Number(p.stock_qty_per_unit || 1) }];
        }
      }
      for (const link of links) {
        const used = Number(link.qty_per_unit) * l.qty;
        if (!(used > 0)) continue;
        await deductStock(conn, { itemId: link.stock_item_id, branchId, used, note: `Penjualan ${orderNo}`, userId: req.user?.id ?? null });
      }
    }

    // Catat pemasukan otomatis (pesanan pending: dicatat saat dilunaskan)
    if (!isPending) {
      await conn.query(
        `INSERT INTO transactions (type, category, amount, note, ref_order, branch_id) VALUES ('income', 'penjualan', :total, :note, :ref, :branch)`,
        { total, note: `Penjualan ${orderNo}`, ref: orderId, branch: branchId }
      );
    }

    await conn.commit();

    res.status(201).json({
      id: orderId,
      order_no: orderNo,
      branch_id: branchId,
      channel,
      customer_name,
      table_no,
      subtotal,
      tax_amount: tax,
      service_amount: service,
      discount: Number(discount),
      rounding_amount: rounding,
      total,
      pay_method,
      paid_amount,
      status: isPending ? 'pending' : 'paid',
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
    const branch = await resolveBranch(req, { allowAll: true });
    if (branch != null) { cond.push('o.branch_id = :branch'); params.branch = branch; }
    if (req.query.from) { cond.push('o.created_at >= :from'); params.from = `${req.query.from} 00:00:00`; }
    if (req.query.to) { cond.push('o.created_at <= :to'); params.to = `${req.query.to} 23:59:59`; }
    if (req.query.status) { cond.push('o.status = :status'); params.status = req.query.status; }
    const where = cond.length ? ` WHERE ${cond.join(' AND ')}` : '';
    const [rows] = await pool.query(
      `SELECT o.id, o.order_no, o.channel, o.customer_name, o.table_no, o.subtotal,
              o.tax_amount, o.service_amount, o.discount, o.rounding_amount, o.total, o.pay_method,
              o.paid_amount, o.status, o.void_reason, o.voided_at,
              o.customer_phone, o.order_type, o.schedule_at, o.delivery_address,
              o.customer_note, o.progress, o.progress_updated_at,
              u.name AS cashier_name, o.created_at, o.branch_id, br.name AS branch_name,
              (SELECT GROUP_CONCAT(
                 CASE WHEN oi.item_role = 'kuah'
                      THEN CONCAT('Porsi ', oi.porsi_no, ': ', oi.qty, 'x ', p.name)
                      WHEN oi.item_role = 'topping'
                      THEN CONCAT('+ ', oi.qty, 'x ', p.name, ' (Porsi ', oi.porsi_no, ')')
                      ELSE CONCAT(oi.qty, 'x ', p.name) END
                 ORDER BY oi.id SEPARATOR ', ')
                 FROM order_items oi JOIN products p ON p.id = oi.product_id
                WHERE oi.order_id = o.id) AS items_preview
       FROM orders o LEFT JOIN users u ON u.id = o.cashier_id
       LEFT JOIN branches br ON br.id = o.branch_id${where}
       ORDER BY o.created_at DESC LIMIT 500`, params
    );
    res.json(rows.map((r) => ({
      ...r,
      subtotal: Number(r.subtotal), tax_amount: Number(r.tax_amount),
      service_amount: Number(r.service_amount), discount: Number(r.discount), rounding_amount: Number(r.rounding_amount),
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
      'SELECT oi.product_id, p.name, oi.qty, oi.unit_price, oi.note, oi.porsi_no, oi.item_role FROM order_items oi JOIN products p ON p.id = oi.product_id WHERE oi.order_id = :id ORDER BY oi.id',
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
      'SELECT id, order_no, total, status, branch_id FROM orders WHERE id = :id FOR UPDATE', { id }
    );
    if (!order) { await conn.rollback(); return res.status(404).json({ error: 'Pesanan tidak ditemukan' }); }
    if (order.status === 'canceled') { await conn.rollback(); return res.status(409).json({ error: 'Pesanan sudah dibatalkan' }); }

    await conn.query(
      `UPDATE orders SET status = 'canceled', void_reason = :reason, voided_at = NOW(), voided_by = :by WHERE id = :id`,
      { reason, by: req.user.id, id }
    );
    await conn.query(
      `INSERT INTO transactions (type, category, amount, note, ref_order, created_by, branch_id)
       VALUES ('expense', 'void', :total, :note, :ref, :by, :branch)`,
      { total: order.total, note: `Void ${order.order_no}: ${reason}`, ref: id, by: req.user.id, branch: order.branch_id }
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
