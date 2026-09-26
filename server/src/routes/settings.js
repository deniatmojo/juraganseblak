import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

// Kunci sensitif: nilainya diganti '********' untuk non-owner, dan PATCH
// melewati nilai mask supaya menyalin ulang form tidak menimpa secret.
const SECRET_KEYS = ['gateway_api_key', 'gateway_private_key'];
const MASK = '********';

router.get('/', async (req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT `key`, `value` FROM settings');
    const obj = {};
    for (const r of rows) obj[r.key] = r.value;
    if (obj.tax_rate != null) obj.tax_rate = Number(obj.tax_rate);
    if (obj.service_rate != null) obj.service_rate = Number(obj.service_rate);
    // Owner boleh melihat nilai secret; role lain hanya tahu sudah terisi/belum.
    if (req.user?.role !== 'owner') {
      for (const k of SECRET_KEYS) {
        obj[`has_${k}`] = Boolean(obj[k]);
        if (obj[k]) obj[k] = MASK;
      }
    }
    res.json(obj);
  } catch (e) { next(e); }
});

router.patch('/', async (req, res, next) => {
  try {
    const entries = Object.entries(req.body || {}).filter(
      ([k, v]) => /^[a-z_]+$/.test(k) && !(SECRET_KEYS.includes(k) && v === MASK)
    );
    if (!entries.length) return res.status(400).json({ error: 'Tidak ada setting yang dikirim' });
    for (const [key, value] of entries) {
      await pool.query(
        'INSERT INTO settings (`key`, `value`) VALUES (:key, :value) ON DUPLICATE KEY UPDATE `value` = :value',
        { key, value: String(value) }
      );
    }
    res.json({ ok: true });
  } catch (e) { next(e); }
});

export default router;
