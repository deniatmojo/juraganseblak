import { Router } from 'express';
import { pool } from '../db.js';

const router = Router();

const SELECT_BRANCH = `
  SELECT b.id, b.name, b.address, b.lat, b.lng, b.radius_m, b.is_active, b.created_at,
         (SELECT COUNT(*) FROM employees e WHERE e.branch_id = b.id AND e.is_active = 1) AS employee_count
  FROM branches b`;

// Validasi angka koordinat & radius
function coordParams(body, params, partial = false) {
  const err = (m) => Object.assign(new Error(m), { status: 400 });
  if (body.lat !== undefined || !partial) {
    const n = Number(body.lat);
    if (!Number.isFinite(n) || n < -90 || n > 90) throw err('Latitude harus angka -90..90');
    params.lat = n;
  }
  if (body.lng !== undefined || !partial) {
    const n = Number(body.lng);
    if (!Number.isFinite(n) || n < -180 || n > 180) throw err('Longitude harus angka -180..180');
    params.lng = n;
  }
  if (body.radius_m !== undefined) {
    const n = Number(body.radius_m);
    if (!Number.isInteger(n) || n < 10 || n > 10_000) throw err('Radius harus bilangan bulat 10–10000 meter');
    params.radius_m = n;
  }
}

// GET /api/branches — daftar cabang (termasuk nonaktif, untuk kelola penugasan)
router.get('/', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(`${SELECT_BRANCH} ORDER BY b.name`);
    res.json(rows.map((r) => ({ ...r, lat: Number(r.lat), lng: Number(r.lng), radius_m: Number(r.radius_m), employee_count: Number(r.employee_count) })));
  } catch (e) { next(e); }
});

// POST /api/branches — { name, address?, lat, lng, radius_m? }
router.post('/', async (req, res, next) => {
  try {
    const { name, address = null } = req.body || {};
    if (!name) return res.status(400).json({ error: 'Nama cabang wajib diisi' });
    const params = { name, address };
    coordParams(req.body || {}, params);
    const [result] = await pool.query(
      'INSERT INTO branches (name, address, lat, lng, radius_m) VALUES (:name, :address, :lat, :lng, :radius_m)',
      params
    );
    res.status(201).json({ id: result.insertId, name, lat: Number(params.lat), lng: Number(params.lng), radius_m: Number(params.radius_m ?? 100) });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ error: e.message });
    next(e);
  }
});

// PATCH /api/branches/:id
router.patch('/:id', async (req, res, next) => {
  try {
    const params = { id: Number(req.params.id) };
    const sets = ['name', 'address', 'is_active'].filter((f) => req.body?.[f] !== undefined);
    for (const f of sets) params[f] = req.body[f];
    coordParams(req.body || {}, params, true);
    sets.push(...['lat', 'lng', 'radius_m'].filter((f) => params[f] !== undefined));
    if (!sets.length) return res.status(400).json({ error: 'Tidak ada field yang diubah' });
    const [result] = await pool.query(
      `UPDATE branches SET ${sets.map((f) => `${f} = :${f}`).join(', ')} WHERE id = :id`, params
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Cabang tidak ditemukan' });
    res.json({ ok: true });
  } catch (e) {
    if (e.status) return res.status(e.status).json({ error: e.message });
    next(e);
  }
});

// DELETE /api/branches/:id — nonaktifkan (soft delete). Penugasan karyawan
// lama tetap tersimpan supaya riwayat absensi tidak yatim.
router.delete('/:id', async (req, res, next) => {
  try {
    const [result] = await pool.query('UPDATE branches SET is_active = 0 WHERE id = :id', { id: Number(req.params.id) });
    if (!result.affectedRows) return res.status(404).json({ error: 'Cabang tidak ditemukan' });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

export default router;
