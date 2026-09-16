import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

router.get('/', async (_req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT `key`, `value` FROM settings');
    const obj = {};
    for (const r of rows) obj[r.key] = r.value;
    if (obj.tax_rate != null) obj.tax_rate = Number(obj.tax_rate);
    if (obj.service_rate != null) obj.service_rate = Number(obj.service_rate);
    res.json(obj);
  } catch (e) { next(e); }
});

router.patch('/', async (req, res, next) => {
  try {
    const entries = Object.entries(req.body || {}).filter(([k]) => /^[a-z_]+$/.test(k));
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
