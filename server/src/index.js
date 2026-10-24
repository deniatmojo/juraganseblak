import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import authRouter from './routes/auth.js';
import productsRouter from './routes/products.js';
import categoriesRouter from './routes/categories.js';
import ordersRouter from './routes/orders.js';
import settingsRouter from './routes/settings.js';
import stockRouter from './routes/stock.js';
import shiftsRouter from './routes/shifts.js';
import transactionsRouter from './routes/transactions.js';
import usersRouter from './routes/users.js';
import employeesRouter from './routes/employees.js';
import branchesRouter from './routes/branches.js';
import attendanceRouter from './routes/attendance.js';
import payrollRouter from './routes/payroll.js';
import financeRouter from './routes/finance.js';
import uploadRouter from './routes/upload.js';
import paymentsRouter from './routes/payments.js';
import onlineRouter from './routes/online.js';
import { autoClockOut } from './routes/attendance.js';
import { requireAuth, requireRole } from './auth.js';
import { pool } from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
// rawBody disimpan untuk verifikasi signature webhook gateway (mis. Tripay HMAC).
app.use(express.json({ verify: (req, _res, buf) => { req.rawBody = buf.toString(); } }));
app.use(cors());
// Folder upload multer ada di server/uploads (lihat routes/upload.js) — path
// static harus menunjuk ke folder yang sama agar file hasil upload bisa diakses.
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// Semua endpoint butuh login, kecuali health & login itu sendiri.
app.get('/api/health', (_req, res) => res.json({ ok: true }));
app.use('/api/auth', authRouter);
// Pembayaran: webhook gateway harus publik (tanpa login), endpoint lain
// memakai requireAuth sendiri di dalam routernya.
app.use('/api/payments', paymentsRouter);
// Pesanan online: endpoint pelanggan (menu/buat pesanan/lacak) publik;
// update tahap pesanan oleh kasir dijaga requireAuth di dalam routernya.
app.use('/api/online', onlineRouter);
app.use('/api', requireAuth);
// Daftar cabang aktif untuk semua role yang login (pemilih cabang & buka shift).
app.get('/api/branch-options', async (_req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT id, name FROM branches WHERE is_active = 1 ORDER BY id');
    res.json(rows);
  } catch (e) { next(e); }
});

// Guard role — wajib dipasang SEBELUM router agar dieksekusi duluan.
// Data manajemen (menu/kategori/settings/stok/transaksi manual): baca semua
// role, ubah hanya owner/admin. Riwayat pesanan & shift: owner/admin untuk
// daftar; checkout (POST) dan buka/tutup shift terbuka untuk semua role.
const adminOnly = requireRole('owner', 'admin');
const adminOnlyForWrites = (req, res, next) => (req.method === 'GET' ? next() : adminOnly(req, res, next));
app.use('/api/products', adminOnlyForWrites);
app.use('/api/categories', adminOnlyForWrites);
app.use('/api/settings', adminOnlyForWrites);
// Stok: Admin Gudang boleh mengubah (selain owner/admin).
const stockWriters = requireRole('owner', 'admin', 'gudang');
app.use('/api/stock', (req, res, next) => (req.method === 'GET' ? next() : stockWriters(req, res, next)));
app.use('/api/transactions', requireRole('owner'));
// Daftar pesanan dibaca semua role (antrian dapur/kasir di POS); checkout (POST)
// terbuka semua role; void dst. dijaga di dalam route.
// Pesanan & shift hanya untuk peran kasir/POS (owner, admin, kasir): role lain
// (karyawan, gudang, leader) tidak punya akses data penjualan sama sekali.
const posRoles = requireRole('owner', 'admin', 'kasir');
app.use('/api/orders', posRoles, (req, res, next) => (req.method === 'GET' || req.method === 'POST' ? next() : adminOnly(req, res, next)));
// Manajemen akun, data karyawan (termasuk atur jadwal), dan payroll:
// khusus Super Admin (owner). Admin tidak boleh menyentuh menu Gaji/Karyawan.
app.use('/api/users', requireRole('owner'));
// Data karyawan: owner penuh; Tim Leader hanya jadwal masuk, rotasi cabang & data dasar
// (dibatasi per-field di routes/employees.js).
app.use('/api/employees', requireRole('owner', 'leader'));
// Kelola titik lokasi cabang absen: khusus Super Admin (owner).
app.use('/api/branches', requireRole('owner'));
// Koreksi status absensi: owner/admin/Tim Leader.
const attendanceEditors = requireRole('owner', 'admin', 'leader');
app.use('/api/attendance', (req, res, next) => (req.method === 'PATCH' ? attendanceEditors(req, res, next) : next()));
app.use('/api/payroll', requireRole('owner'));
// Laporan keuangan (laba rugi, arus kas, buku besar, jurnal): owner only.
app.use('/api/finance', requireRole('owner'));
app.use('/api/upload', adminOnly);
app.use('/api/shifts', posRoles, (req, res, next) => {
  // Daftar riwayat shift = owner/admin (diproses di route); aktifitas shift
  // (active/open/close) milik kasir sendiri.
  next();
});

app.use('/api/products', productsRouter);
app.use('/api/categories', categoriesRouter);
app.use('/api/orders', ordersRouter);
app.use('/api/settings', settingsRouter);
app.use('/api/stock', stockRouter);
app.use('/api/shifts', shiftsRouter);
app.use('/api/transactions', transactionsRouter);
app.use('/api/users', usersRouter);
app.use('/api/employees', employeesRouter);
app.use('/api/branches', branchesRouter);
app.use('/api/attendance', attendanceRouter);
app.use('/api/payroll', payrollRouter);
app.use('/api/finance', financeRouter);
app.use('/api/upload', uploadRouter);

app.use((err, _req, res, _next) => {
  if (err.status && err.status < 500) return res.status(err.status).json({ error: err.message });
  console.error(err);
  res.status(500).json({ error: 'Kesalahan server' });
});

const port = Number(process.env.PORT || 3001);
app.listen(port, () => console.log(`API Juragan Seblak jalan di http://localhost:${port}`));

// Auto clock-out karyawan: tutup absensi yang sudah melewati durasi kerja
// (clock_in + work_hours dari setting jadwal). Cek tiap menit + sekali saat boot.
autoClockOut().catch(() => {});
setInterval(() => autoClockOut().catch(() => {}), 60_000);
