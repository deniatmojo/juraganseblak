import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { pool } from '../db.js';

const router = Router();
const ROLES = ['owner', 'admin', 'kasir', 'karyawan', 'gudang', 'leader'];

// Migrasi ringan: pastikan ENUM role punya nilai 'karyawan' (role absensi-saja).
// Dijalankan sekali saat modul dimuat; aman dipanggil berulang.
(async () => {
  try {
    const [[col]] = await pool.query(
      `SELECT COLUMN_TYPE t FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'role'`
    );
    if (col && !col.t.includes('leader')) {
      await pool.query("ALTER TABLE users MODIFY role ENUM('owner','admin','kasir','karyawan','gudang','leader') NOT NULL");
    }
  } catch (e) {
    console.error('Migrasi role users gagal:', e.message);
  }
})();

// GET /api/users — daftar akun (tanpa hash)
router.get('/', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT u.id, u.name, u.email, u.role, u.is_active, u.created_at, u.branch_id, b.name AS branch_name
       FROM users u LEFT JOIN branches b ON b.id = u.branch_id ORDER BY u.id`
    );
    res.json(rows);
  } catch (e) { next(e); }
});

// POST /api/users — buat akun { name, email, password, role }
router.post('/', async (req, res, next) => {
  try {
    const { name, email, password, role = 'kasir', branch_id = null } = req.body || {};
    if (!name || !email || !password) return res.status(400).json({ error: 'Nama, email, dan password wajib diisi' });
    if (String(password).length < 6) return res.status(400).json({ error: 'Password minimal 6 karakter' });
    if (!ROLES.includes(role)) return res.status(400).json({ error: 'Role tidak valid' });
    const hash = bcrypt.hashSync(String(password), 10);
    const [result] = await pool.query(
      'INSERT INTO users (name, email, password_hash, role, branch_id) VALUES (:name, :email, :hash, :role, :branch)',
      { name, email, hash, role, branch: branch_id ? Number(branch_id) : null }
    );
    res.status(201).json({ id: result.insertId, name, email, role, is_active: 1, branch_id: branch_id ? Number(branch_id) : null });
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Email sudah terdaftar' });
    next(e);
  }
});

// PATCH /api/users/:id — ubah nama/role/status, atau reset password
router.patch('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const body = req.body || {};
    const params = { id };

    if (body.password) {
      if (String(body.password).length < 6) return res.status(400).json({ error: 'Password minimal 6 karakter' });
      await pool.query('UPDATE users SET password_hash = :h WHERE id = :id', { h: bcrypt.hashSync(String(body.password), 10), id });
    }
    if (body.branch_id === '') body.branch_id = null; // kosong = tidak dikunci ke cabang
    // Role yang tidak memakai kunci cabang (owner/karyawan/leader): lepas kunci lama.
    if (body.role !== undefined && body.branch_id === undefined && !['admin', 'kasir', 'gudang'].includes(body.role)) {
      body.branch_id = null;
    }
    const sets = ['name', 'role', 'is_active', 'branch_id'].filter((f) => body[f] !== undefined);
    if (body.role !== undefined && !ROLES.includes(body.role)) {
      return res.status(400).json({ error: 'Role tidak valid' });
    }
    if (sets.length) {
      if (id === req.user.id && (body.is_active === 0 || (body.role && body.role !== req.user.role))) {
        return res.status(400).json({ error: 'Tidak boleh menonaktifkan/menurunkan role akun sendiri' });
      }
      for (const f of sets) params[f] = body[f];
      await pool.query(`UPDATE users SET ${sets.map((f) => `${f} = :${f}`).join(', ')} WHERE id = :id`, params);
    }
    const [[user]] = await pool.query('SELECT id, name, email, role, is_active, branch_id FROM users WHERE id = :id', { id });
    if (!user) return res.status(404).json({ error: 'Akun tidak ditemukan' });
    res.json(user);
  } catch (e) { next(e); }
});

export default router;
