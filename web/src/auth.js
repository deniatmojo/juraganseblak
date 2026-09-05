// Manajemen akun sederhana berbasis localStorage.
// TODO backend: pindahkan ke API + hash password di server.

const ACCOUNTS_KEY = 'erp_accounts'

const DEFAULT_ACCOUNTS = [
  {
    id: 1,
    name: 'Rangga Saputra',
    email: 'admin@barapedas.id',
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

export function logout() {
  sessionStorage.removeItem('erp_user')
}

export function getCurrentUser() {
  try {
    return JSON.parse(sessionStorage.getItem('erp_user'))
  } catch {
    return null
  }
}

// Karyawan hanya boleh membuka Absensi; selain itu khusus super admin (owner).
export const ROLE_HOME = { owner: '/erp', karyawan: '/erp/absensi' }

export function isAllowed(role, path) {
  if (role === 'owner') return true
  return path === '/erp/absensi'
}
