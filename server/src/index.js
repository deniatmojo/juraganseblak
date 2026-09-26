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
import { autoClockOut } from './routes/attendance.js';
import { requireAuth, requireRole } from './auth.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
app.use(cors());
app.use(express.json());
// Folder upload multer ada di server/uploads (lihat routes/upload.js) — path
// static harus menunjuk ke folder yang sama agar file hasil upload bisa diakses.
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// Semua endpoint butuh login, kecuali health & login itu sendiri.
app.get('/api/health', (_req, res) => res.json({ ok: true }));
app.use('/api/auth', authRouter);
app.use('/api', requireAuth);

// Guard role — wajib dipasang SEBELUM router agar dieksekusi duluan.
// Data manajemen (menu/kategori/settings/stok/transaksi manual): baca semua
// role, ubah hanya owner/admin. Riwayat pesanan & shift: owner/admin untuk
// daftar; checkout (POST) dan buka/tutup shift terbuka untuk semua role.
const adminOnly = requireRole('owner', 'admin');
const adminOnlyForWrites = (req, res, next) => (req.method === 'GET' ? next() : adminOnly(req, res, next));
app.use('/api/products', adminOnlyForWrites);
app.use('/api/categories', adminOnlyForWrites);
app.use('/api/settings', adminOnlyForWrites);
app.use('/api/stock', adminOnlyForWrites);
app.use('/api/transactions', requireRole('owner'));
app.use('/api/orders', (req, res, next) => (req.method === 'POST' ? next() : adminOnly(req, res, next)));
// Manajemen akun, data karyawan (termasuk atur jadwal), dan payroll:
// khusus Super Admin (owner). Admin tidak boleh menyentuh menu Gaji/Karyawan.
app.use('/api/users', requireRole('owner'));
app.use('/api/employees', requireRole('owner'));
// Kelola titik lokasi cabang absen: khusus Super Admin (owner).
app.use('/api/branches', requireRole('owner'));
app.use('/api/attendance', (req, res, next) => (req.method === 'PATCH' ? adminOnly(req, res, next) : next()));
app.use('/api/payroll', requireRole('owner'));
// Laporan keuangan (laba rugi, arus kas, buku besar, jurnal): owner only.
app.use('/api/finance', requireRole('owner'));
app.use('/api/upload', adminOnly);
app.use('/api/shifts', requireAuth, (req, res, next) => {
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
  console.error(err);
  res.status(500).json({ error: 'Kesalahan server' });
});

const port = Number(process.env.PORT || 3001);
app.listen(port, () => console.log(`API Juragan Seblak jalan di http://localhost:${port}`));

// Auto clock-out karyawan: tutup absensi yang sudah melewati durasi kerja
// (clock_in + work_hours dari setting jadwal). Cek tiap menit + sekali saat boot.
autoClockOut().catch(() => {});
setInterval(() => autoClockOut().catch(() => {}), 60_000);
