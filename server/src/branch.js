import { pool } from './db.js';

// ---------------------------------------------------------------------
// Sistem multi-cabang. Aturan penentuan cabang aktif sebuah request:
//   kasir : cabang shift yang sedang terbuka (fallback: users.branch_id, cabang utama)
//   admin : dikunci ke users.branch_id (bila belum diatur → berperilaku seperti owner)
//   owner : bebas memilih lewat ?branch_id= / body.branch_id ('all' = semua cabang
//           bila endpoint mengizinkan); tanpa parameter → semua (allowAll) / cabang utama
// ---------------------------------------------------------------------

// Cabang utama = cabang aktif ber-id terkecil (tujuan default data lama & fallback).
export async function mainBranchId(conn = pool) {
  const [[row]] = await conn.query('SELECT MIN(id) AS id FROM branches WHERE is_active = 1');
  return row?.id ? Number(row.id) : null;
}

async function branchExists(id, conn = pool) {
  const [[row]] = await conn.query('SELECT id FROM branches WHERE id = :id AND is_active = 1', { id });
  return !!row;
}

// Cabang yang dikunci untuk user (null = tidak dikunci).
export async function lockedBranchId(user, conn = pool) {
  if (!user) return null;
  if (user.role === 'kasir') {
    const [[shift]] = await conn.query(
      'SELECT branch_id FROM shifts WHERE user_id = :u AND closed_at IS NULL ORDER BY id DESC LIMIT 1',
      { u: user.id }
    );
    if (shift?.branch_id) return Number(shift.branch_id);
  }
  if (user.role === 'kasir' || user.role === 'admin') {
    const [[row]] = await conn.query('SELECT branch_id FROM users WHERE id = :u', { u: user.id });
    if (row?.branch_id) return Number(row.branch_id);
    if (user.role === 'kasir') return mainBranchId(conn);
  }
  return null;
}

// Cabang yang dipakai request ini. allowAll=true → boleh mengembalikan null
// ("semua cabang") untuk owner/admin tak terkunci tanpa parameter / 'all'.
// Melempar error 400 bila branch_id dari klien tidak valid.
export async function resolveBranch(req, { allowAll = false, conn = pool } = {}) {
  const locked = await lockedBranchId(req.user, conn);
  if (locked) return locked;
  const raw = req.query?.branch_id ?? req.body?.branch_id;
  if (raw === undefined || raw === null || raw === '') return allowAll ? null : mainBranchId(conn);
  if (raw === 'all') {
    if (allowAll) return null;
    const err = new Error('Pilih satu cabang tertentu (bukan "Semua cabang") untuk mencatat data');
    err.status = 400;
    throw err;
  }
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0 || !(await branchExists(id, conn))) {
    const err = new Error('Cabang tidak valid');
    err.status = 400;
    throw err;
  }
  return id;
}

// Cabang "buka" = ada minimal satu shift terbuka di cabang itu (oleh siapa pun).
// Dipakai pesanan online: cabang tanpa shift terbuka tidak menerima pesanan.
export async function branchIsOpen(branchId, conn = pool) {
  if (!branchId) return false;
  const [[row]] = await conn.query(
    'SELECT 1 AS open_now FROM shifts WHERE branch_id = :b AND closed_at IS NULL LIMIT 1', { b: branchId }
  );
  return !!row;
}

// Tambah kondisi `col = :branch` bila cabang tertentu dipilih (null = semua).
export function branchCond(col, branchId, params) {
  if (branchId == null) return '';
  params.branch = branchId;
  return ` AND ${col} = :branch`;
}

// Pastikan baris stok (bahan × cabang) ada; min_qty awal mengikuti bahan.
export async function ensureStockRow(conn, itemId, branchId) {
  await conn.query(
    `INSERT IGNORE INTO stock_branch_items (item_id, branch_id, qty, min_qty)
     SELECT id, :b, 0, min_qty FROM stock_items WHERE id = :i`,
    { i: itemId, b: branchId }
  );
}

// Kurangi stok bahan di sebuah cabang (tidak pernah di bawah 0) + catat pergerakan 'out'.
export async function deductStock(conn, { itemId, branchId, used, note, userId = null }) {
  await ensureStockRow(conn, itemId, branchId);
  await conn.query(
    'UPDATE stock_branch_items SET qty = GREATEST(qty - :used, 0) WHERE item_id = :i AND branch_id = :b',
    { used, i: itemId, b: branchId }
  );
  await conn.query(
    `INSERT INTO stock_movements (item_id, type, qty, note, created_by, branch_id)
     VALUES (:item, 'out', :used, :note, :user, :b)`,
    { item: itemId, used, note, user: userId, b: branchId }
  );
}
