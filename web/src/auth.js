// Manajemen sesi login — login server-side (JWT). Tidak ada akun/password
// bawaan di kode klien.

import { api, setToken, getToken } from './api'

// Login server-side: POST /api/auth/login → simpan token + profil.
// Role DB dipakai apa adanya: owner | admin | kasir | karyawan.
export async function serverLogin(email, password) {
  const { token, user } = await api.post('/auth/login', { email, password })
  setToken(token)
  const session = { id: user.id, name: user.name, email: user.email, role: user.role, position: user.role, branch_id: user.branch_id ?? null }
  sessionStorage.setItem('erp_user', JSON.stringify(session))
  return session
}

export function logout() {
  setToken(null)
  sessionStorage.removeItem('erp_user')
}

export function hasToken() {
  return Boolean(getToken())
}

export function getCurrentUser() {
  try {
    return JSON.parse(sessionStorage.getItem('erp_user'))
  } catch {
    return null
  }
}

// Hak akses per role:
// - owner    (Super Admin)   : semua
// - admin    (Admin)         : semua KECUALI Gaji, Karyawan, Keuangan (dan atur jadwal absensi)
// - kasir    (Karyawan Kasir): POS, Pesanan Online & Absensi saja
// - karyawan (Karyawan)      : Absensi saja
// - gudang   (Admin Gudang)   : Absensi + Stock
// - leader   (Tim Leader)     : Absensi + Karyawan (jadwal masuk, rotasi cabang; tanpa gaji/akun)
export const ROLE_HOME = { owner: '/erp', admin: '/erp', kasir: '/erp/pos', karyawan: '/erp/absensi', gudang: '/erp/stock', leader: '/erp/absensi' }

const ADMIN_BLOCKED = ['/erp/gaji', '/erp/karyawan', '/erp/keuangan']

const KASIR_ALLOWED = ['/erp/pos', '/erp/pesanan-online', '/erp/absensi']
// Admin Gudang: Absensi (miliknya) + Stock. Tim Leader: Absensi (semua karyawan) + Karyawan (terbatas).
const GUDANG_ALLOWED = ['/erp/absensi', '/erp/stock']
const LEADER_ALLOWED = ['/erp/absensi', '/erp/karyawan']

export function isAllowed(role, path) {
  if (role === 'owner') return true
  if (role === 'admin') return !ADMIN_BLOCKED.some((p) => path === p || path.startsWith(p + '/'))
  if (role === 'kasir') return KASIR_ALLOWED.includes(path)
  if (role === 'karyawan') return path === '/erp/absensi'
  if (role === 'gudang') return GUDANG_ALLOWED.includes(path)
  if (role === 'leader') return LEADER_ALLOWED.includes(path)
  return false
}
