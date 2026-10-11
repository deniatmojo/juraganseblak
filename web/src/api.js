// Wrapper API client — semua halaman memakai modul ini untuk akses backend.
import { getBranch } from './branch'
const BASE = import.meta.env.VITE_API_BASE || '/api'
const TOKEN_KEY = 'erp_token'

// Endpoint yang mengikuti cabang aktif. Cabang disuntikkan otomatis (query pada
// GET, field body pada POST/PATCH) bila halaman belum menentukannya sendiri.
// Kasir tidak disuntik: server memakai cabang shift-nya.
const BRANCH_PATHS = ['/stock', '/orders', '/shifts', '/transactions', '/finance', '/online/tables']

function withBranch(path, method, body) {
  let role = null
  try { role = JSON.parse(sessionStorage.getItem('erp_user'))?.role } catch { /* abaikan */ }
  const branch = getBranch()
  if (!branch || role === 'kasir' || !BRANCH_PATHS.some((p) => path === p || path.startsWith(p + '/') || path.startsWith(p + '?'))) {
    return { path, body }
  }
  if (method === 'GET') {
    return { path: /[?&]branch_id=/.test(path) ? path : `${path}${path.includes('?') ? '&' : '?'}branch_id=${branch}`, body }
  }
  if (body && typeof body === 'object' && body.branch_id === undefined) return { path, body: { ...body, branch_id: branch } }
  return { path, body }
}

export function getToken() {
  return sessionStorage.getItem(TOKEN_KEY)
}

export function setToken(token) {
  if (token) sessionStorage.setItem(TOKEN_KEY, token)
  else sessionStorage.removeItem(TOKEN_KEY)
}

async function request(rawPath, { method = 'GET', body: rawBody } = {}) {
  const { path, body } = withBranch(rawPath, method, rawBody)
  const token = getToken()
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  })
  if (!res.ok) {
    // Sesi habis/invalid: bersihkan & kirim ke halaman login
    // (kecuali memang request login yang gagal).
    if (res.status === 401 && !path.startsWith('/auth/login')) {
      setToken(null)
      sessionStorage.removeItem('erp_user')
      window.location.href = '/login'
    }
    let msg = `Request gagal (${res.status})`
    try {
      const data = await res.json()
      if (data.error) msg = data.error
    } catch { /* respons bukan JSON */ }
    throw new Error(msg)
  }
  return res.json()
}

export const api = {
  get: (path) => request(path),
  post: (path, body) => request(path, { method: 'POST', body }),
  patch: (path, body) => request(path, { method: 'PATCH', body }),
  del: (path) => request(path, { method: 'DELETE' }),
}
