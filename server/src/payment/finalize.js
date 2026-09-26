import { pool } from '../db.js';
import { linksForProducts } from '../routes/products.js';

// Finalisasi pesanan pending menjadi 'paid': potong stok bahan, catat pemasukan,
// set status + paid_at. Dipanggil dari webhook gateway, polling manual kasir
// (confirm-manual), dan (di masa depan) proses lain yang melunaskan pesanan.
// Idempoten: bila sudah 'paid', tidak melakukan apa-apa.
export async function markOrderPaid(orderId, { provider = 'manual', ref = null, confirmedBy = null } = {}) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [[order]] = await conn.query('SELECT * FROM orders WHERE id = :id FOR UPDATE', { id: orderId });
    if (!order) throw new Error('Pesanan tidak ditemukan');
    if (order.status === 'paid') {
      await conn.commit();
      return { ok: true, already: true, order_no: order.order_no };
    }
    if (order.status === 'canceled') throw new Error('Pesanan sudah dibatalkan, tidak bisa dilunasi');

    const [items] = await conn.query(
      'SELECT oi.product_id, oi.qty, p.name, p.stock_qty_per_unit FROM order_items oi JOIN products p ON p.id = oi.product_id WHERE oi.order_id = :id',
      { id: orderId }
    );
    const productLinks = await linksForProducts(items.map((i) => i.product_id));

    for (const it of items) {
      // Pola fallback sama dengan POST /orders: link multi-bahan, atau bahan
      // bernama sama dengan menu bila menu belum punya link sama sekali.
      let links = productLinks.get(it.product_id) || [];
      if (!links.length) {
        const [byName] = await conn.query(
          'SELECT id FROM stock_items WHERE name = :name AND is_active = 1 LIMIT 1',
          { name: it.name }
        );
        if (byName.length) links = [{ stock_item_id: byName[0].id, qty_per_unit: Number(it.stock_qty_per_unit || 1) }];
      }
      for (const l of links) {
        const used = Number(l.qty_per_unit) * it.qty;
        if (!(used > 0)) continue;
        await conn.query('UPDATE stock_items SET qty = GREATEST(qty - :used, 0) WHERE id = :id', { used, id: l.stock_item_id });
        await conn.query(
          "INSERT INTO stock_movements (item_id, type, qty, note, created_by) VALUES (:item, 'out', :used, :note, :user)",
          { item: l.stock_item_id, used, note: `Penjualan ${order.order_no}`, user: confirmedBy }
        );
      }
    }

    await conn.query(
      `INSERT INTO transactions (type, category, amount, note, ref_order, created_by)
       VALUES ('income', 'penjualan', :total, :note, :ref, :by)`,
      { total: order.total, note: `Penjualan ${order.order_no}`, ref: order.id, by: confirmedBy }
    );
    await conn.query(
      `UPDATE orders SET status = 'paid', paid_at = NOW(), payment_provider = :provider,
        payment_ref = COALESCE(payment_ref, :ref), payment_confirmed_by = :by, paid_amount = total
       WHERE id = :id`,
      { provider, ref, by: confirmedBy, id: orderId }
    );

    await conn.commit();
    return { ok: true, already: false, order_no: order.order_no };
  } catch (e) {
    await conn.rollback().catch(() => {});
    throw e;
  } finally {
    conn.release();
  }
}
