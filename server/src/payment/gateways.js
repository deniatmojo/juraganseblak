import crypto from 'node:crypto';

// Adapter payment gateway untuk QRIS dinamis. Semua adapter menerima order yang
// SUDAH tersimpan dengan status 'pending' dan settings gateway dari tabel
// settings, lalu mengembalikan { provider, ref, checkout_url, qr_string }.
//
// API keys diambil dari settings:
//   payment_gateway    : 'tripay' | 'duitku' | 'midtrans'
//   gateway_mode       : 'sandbox' | 'production'
//   gateway_merchant_id: kode merchant (Tripay: merchant code, Duitku: merchantCode)
//   gateway_api_key    : Tripay: API key | Duitku: API key | Midtrans: server key
//   gateway_private_key: Tripay & Duitku: private key | Midtrans: tidak dipakai
//   gateway_callback_url: URL publik server (mis. https://pos.juraganseblak.id)
//                        — dipakai sebagai notify/callback URL webhook.

const SANDBOX_HOSTS = {
  tripay: 'https://tripay.co.id/api-sandbox',
  duitku: 'https://sandbox.duitku.com/webapi/api/merchant',
  midtrans: 'https://api.sandbox.midtrans.com/v2',
};
const PROD_HOSTS = {
  tripay: 'https://tripay.co.id/api',
  duitku: 'https://passport.duitku.com/webapi/api/merchant',
  midtrans: 'https://api.midtrans.com/v2',
};

function hosts(provider, mode) {
  return (mode === 'production' ? PROD_HOSTS : SANDBOX_HOSTS)[provider];
}

function requireSettings(settings, fields) {
  for (const f of fields) {
    if (!settings[f]) throw new Error(`Setting "${f}" belum diisi di halaman Pembayaran`);
  }
}

function callbackBase(settings) {
  const base = settings.gateway_callback_url?.replace(/\/+$/, '');
  if (!base) throw new Error('Setting "gateway_callback_url" belum diisi (URL publik server, mis. https://pos.example.com)');
  return base;
}

// ---------- TRIPAY ----------
async function createTripay(order, settings) {
  requireSettings(settings, ['gateway_merchant_id', 'gateway_api_key', 'gateway_private_key']);
  const method = 'QRIS';
  const sign = crypto
    .createHmac('sha256', settings.gateway_private_key)
    .update(`${settings.gateway_merchant_id}${order.order_no}${order.total}`)
    .digest('hex');
  const res = await fetch(`${hosts('tripay', settings.gateway_mode)}/v2/transaction/create`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${settings.gateway_api_key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      method,
      merchant_ref: order.order_no,
      amount: order.total,
      customer_name: order.customer_name || 'Pelanggan',
      customer_email: 'pos@juraganseblak.local',
      customer_phone: '',
      callback_url: `${callbackBase(settings)}/api/payments/webhook/tripay`,
      expired_time: Math.floor(Date.now() / 1000) + 30 * 60, // 30 menit
      signature: sign,
    }),
  });
  const data = await res.json();
  if (!data.success) throw new Error(`Tripay: ${data.message || 'gagal membuat transaksi'}`);
  const qr = data.data.qr_string || null;
  return {
    provider: 'tripay',
    ref: data.data.reference,
    checkout_url: data.data.checkout_url || null,
    qr_string: qr,
  };
}

// ---------- DUITKU ----------
async function createDuitku(order, settings) {
  requireSettings(settings, ['gateway_merchant_id', 'gateway_api_key']);
  const expiry = 30 * 60; // detik
  const sign = crypto
    .createHash('md5')
    .update(`${settings.gateway_merchant_id}${order.order_no}${order.total}${expiry}${settings.gateway_api_key}`)
    .digest('hex');
  const res = await fetch(`${hosts('duitku', settings.gateway_mode)}/createinvoice`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      merchantCode: settings.gateway_merchant_id,
      paymentAmount: order.total,
      paymentMethod: 'QC', // QC = QRIS
      merchantOrderId: order.order_no,
      productDetails: `Pesanan ${order.order_no}`,
      email: 'pos@juraganseblak.local',
      phoneNumber: '',
      callbackUrl: `${callbackBase(settings)}/api/payments/webhook/duitku`,
      expiryPeriod: expiry / 60,
      signature: sign,
    }),
  });
  const data = await res.json();
  if (!data.responseCode || data.responseCode !== '00') {
    throw new Error(`Duitku: ${data.responseMessage || 'gagal membuat transaksi'}`);
  }
  return {
    provider: 'duitku',
    ref: data.reference,
    checkout_url: data.paymentUrl || null,
    qr_string: data.qrString || null,
  };
}

// ---------- MIDTRANS (Snap QRIS) ----------
async function createMidtrans(order, settings) {
  requireSettings(settings, ['gateway_api_key']);
  const auth = Buffer.from(`${settings.gateway_api_key}:`).toString('base64');
  const res = await fetch(`${hosts('midtrans', settings.gateway_mode)}/${order.order_no}`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      transaction_details: { order_id: order.order_no, gross_amount: order.total },
      payment_type: 'qris',
      qris: { acquirer: 'gopay' },
      customer_details: { first_name: order.customer_name || 'Pelanggan' },
      callbacks: { finish: `${callbackBase(settings)}/erp/pos` },
    }),
  });
  const data = await res.json();
  if (data.status_code !== '201') {
    throw new Error(`Midtrans: ${data.status_message || 'gagal membuat transaksi'}`);
  }
  const qrAction = (data.actions || []).find((a) => a.name === 'generate-qr-code');
  return {
    provider: 'midtrans',
    ref: data.transaction_id,
    checkout_url: data.redirect_url || null,
    qr_string: null, // Midtrans memberi URL gambar QR, bukan string — tampilkan via checkout_url/qr_url
    qr_url: qrAction?.url || null,
  };
}

const creators = { tripay: createTripay, duitku: createDuitku, midtrans: createMidtrans };

export async function createGatewayPayment(order, settings) {
  const provider = settings.payment_gateway;
  const create = creators[provider];
  if (!create) throw new Error(`Gateway "${provider}" tidak dikenal (pilih tripay / duitku / midtrans)`);
  return create(order, settings);
}

// ---------- Verifikasi signature webhook ----------
// Return { valid, paid, message } untuk event pembayaran yang masuk.
export function verifyWebhook(provider, settings, req) {
  const body = req.body || {};
  if (provider === 'tripay') {
    requireSettings(settings, ['gateway_private_key']);
    const raw = typeof req.rawBody === 'string' ? req.rawBody : JSON.stringify(body);
    const expected = crypto.createHmac('sha256', settings.gateway_private_key).update(raw).digest('hex');
    const received = req.headers['x-callback-signature'] || '';
    const paid = body.status === 'PAID';
    return { valid: received === expected, paid, ref: body.merchant_ref, message: body.status || 'unknown' };
  }
  if (provider === 'duitku') {
    requireSettings(settings, ['gateway_merchant_id', 'gateway_api_key']);
    const expected = crypto
      .createHash('md5')
      .update(`${settings.gateway_merchant_id}${body.merchantOrderId}${body.resultCode}${settings.gateway_api_key}`)
      .digest('hex');
    const valid = (req.headers['x-duitku-signature'] || '') === expected || expected === body.signature;
    return { valid, paid: body.resultCode === '00', ref: body.merchantOrderId, message: body.resultMessage || 'unknown' };
  }
  if (provider === 'midtrans') {
    requireSettings(settings, ['gateway_api_key']);
    const expected = crypto
      .createHash('sha512')
      .update(`${body.order_id}${body.status_code}${body.gross_amount}${settings.gateway_api_key}`)
      .digest('hex');
    const paid = ['settlement', 'capture'].includes(body.transaction_status);
    return { valid: (body.signature_key || '') === expected, paid, ref: body.order_id, message: body.transaction_status || 'unknown' };
  }
  return { valid: false, paid: false, ref: null, message: 'provider tidak dikenal' };
}
