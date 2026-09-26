import { Router } from 'express';
import { pool } from '../db.js';
import { requireAuth } from '../auth.js';
import { createGatewayPayment, verifyWebhook } from '../payment/gateways.js';
import { markOrderPaid } from '../payment/finalize.js';

// Router pembayaran. Dipasang SEBELUM guard auth global di index.js —
// endpoint webhook HARUS publik (dipanggil server gateway), sisanya memakai
// requireAuth sendiri.

const router = Router();

async function getSettings() {
  const [rows] = await pool.query('SELECT `key`, `value` FROM settings');
  const s = {};
  for (const r of rows) s[r.key] = r.value;
  return s;
}

// POST /api/payments/create — buat transaksi QRIS dinamis di gateway untuk
// pesanan yang sudah tersimpan dengan status 'pending'.
router.post('/create', requireAuth, async (req, res, next) => {
  try {
    const orderId = Number(req.body?.order_id);
    const [[order]] = await pool.query('SELECT * FROM orders WHERE id = :id', { id: orderId });
    if (!order) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    if (order.status !== 'pending') return res.status(409).json({ error: `Pesanan sudah berstatus ${order.status}` });

    const settings = await getSettings();
    const payment = await createGatewayPayment(order, settings);

    await pool.query(
      `UPDATE orders SET payment_provider = :provider, payment_ref = :ref,
        payment_url = :url, payment_qr = :qr WHERE id = :id`,
      { provider: payment.provider, ref: payment.ref, url: payment.checkout_url, qr: payment.qr_string, id: orderId }
    );
    res.json({
      order_id: orderId,
      order_no: order.order_no,
      total: Number(order.total),
      provider: payment.provider,
      reference: payment.ref,
      checkout_url: payment.checkout_url,
      qr_string: payment.qr_string,
      qr_url: payment.qr_url || null,
    });
  } catch (e) {
    // Pesan gateway diteruskan apa adanya supaya kasir tahu apa yang salah.
    res.status(502).json({ error: e.message || 'Gagal membuat transaksi di gateway' });
    return;
  }
});

// GET /api/payments/status/:orderNo — polling kasir: apakah pesanan sudah lunas.
router.get('/status/:orderNo', requireAuth, async (req, res, next) => {
  try {
    const [[order]] = await pool.query(
      'SELECT order_no, status, payment_provider, payment_ref, payment_url, payment_qr, total FROM orders WHERE order_no = :no',
      { no: req.params.orderNo }
    );
    if (!order) return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
    res.json({ ...order, total: Number(order.total) });
  } catch (e) { next(e); }
});

// POST /api/payments/confirm-manual — kasir melunaskan pesanan manual
// (QRIS statis terverifikasi di HP kasir, atau fallback bila webhook macet).
router.post('/confirm-manual', requireAuth, async (req, res, next) => {
  try {
    const orderId = Number(req.body?.order_id);
    const result = await markOrderPaid(orderId, { provider: 'manual', confirmedBy: req.user.id });
    res.json(result);
  } catch (e) {
    res.status(400).json({ error: e.message || 'Gagal melunaskan pesanan' });
  }
});

// POST /api/payments/webhook/:provider — notifikasi dari gateway (PUBLIK).
// Signature diverifikasi sebelum pesanan dilunaskan.
router.post('/webhook/:provider', async (req, res) => {
  const provider = req.params.provider;
  const settings = await getSettings();
  let check;
  try {
    check = verifyWebhook(provider, settings, req);
  } catch {
    // Gateway belum dikonfigurasi / kunci hilang — tandai tidak valid.
    return res.status(401).json({ error: 'Webhook tidak dapat diverifikasi' });
  }
  if (!check.valid) {
    return res.status(401).json({ error: 'Signature webhook tidak valid' });
  }
  if (check.paid && check.ref) {
    try {
      const [[order]] = await pool.query('SELECT id, status FROM orders WHERE order_no = :no', { no: check.ref });
      if (order && order.status === 'pending') {
        await markOrderPaid(order.id, { provider, ref: check.ref });
      }
    } catch (e) {
      console.error(`Webhook ${provider} gagal finalisasi ${check.ref}:`, e);
      return res.status(500).json({ error: 'Gagal memproses webhook' });
    }
  }
  res.json({ ok: true });
});

export default router;
