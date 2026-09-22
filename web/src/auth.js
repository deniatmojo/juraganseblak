// Manajemen sesi login.
// Login utama sekarang server-side (JWT); fungsi akun localStorage di bawah
// masih dipakai halaman Karyawan sampung modul SDM (users CRUD) di-migrasi.

import { api, setToken, getToken } from './api'

const ACCOUNTS_KEY = 'erp_accounts'

const DEFAULT_ACCOUNTS = [
  {
    id: 1,
    name: 'Rangga Saputra',
    email: 'admin@juraganseblak.id',
    password: 'admin123',
    role: 'owner', // super admin: akses semua menu
    position: 'Owner',
    active: true,
  },
]

export function getAccounts() {
  try {
    const raw = localStorage.getItem(ACCOUNTS_KEY)
    if (!raw) return DEFAULT_ACCOUNTS
    return JSON.parse(raw)
  } catch {
    return DEFAULT_ACCOUNTS
  }
}

function saveAccounts(accounts) {
  localStorage.setItem(ACCOUNTS_KEY, JSON.stringify(accounts))
}

export function addAccount({ name, email, password, role = 'karyawan', position = '' }) {
  const accounts = getAccounts()
  if (accounts.some((a) => a.email.toLowerCase() === email.toLowerCase())) {
    throw new Error('Email sudah terdaftar.')
  }
  const account = {
    id: Date.now(),
    name,
    email,
    password,
    role, // 'owner' | 'karyawan'
    position,
    active: true,
  }
  saveAccounts([...accounts, account])
  return account
}

export function removeAccount(id) {
  const accounts = getAccounts().filter((a) => a.id !== id)
  saveAccounts(accounts)
}

export function authenticate(email, password) {
  const acc = getAccounts().find(
    (a) => a.email.toLowerCase() === email.toLowerCase() && a.active,
  )
  if (!acc || acc.password !== password) return null
  return acc
}

export function login(acc) {
  sessionStorage.setItem(
    'erp_user',
    JSON.stringify({ id: acc.id, name: acc.name, email: acc.email, role: acc.role, position: acc.position }),
  )
}

// Login server-side: POST /api/auth/login → simpan token + profil.
// Role DB dipakai apa adanya: owner | admin | kasir | karyawan.
export async function serverLogin(email, password) {
  const { token, user } = await api.post('/auth/login', { email, password })
  setToken(token)
  const session = { id: user.id, name: user.name, email: user.email, role: user.role, position: user.role }
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
// - owner  (Super Admin)  : semua menu
// - admin  (Admin)        : POS & Absensi (tanpa atur jadwal, tanpa Gaji/Karyawan)
// - kasir  (Karyawan Kasir): POS & Absensi
// - karyawan (Karyawan)   : Absensi saja (absen harian + rekap sendiri)
export const ROLE_HOME = { owner: '/erp', admin: '/erp/pos', kasir: '/erp/pos', karyawan: '/erp/absensi' }

export function isAllowed(role, path) {
  if (role === 'owner') return true
  if (role === 'karyawan') return path === '/erp/absensi'
  return path === '/erp/absensi' || path === '/erp/pos'
}
