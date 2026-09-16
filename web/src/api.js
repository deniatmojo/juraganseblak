// Wrapper API client — semua halaman memakai modul ini untuk akses backend.
const BASE = import.meta.env.VITE_API_BASE || '/api'
const TOKEN_KEY = 'erp_token'

export function getToken() {
  return sessionStorage.getItem(TOKEN_KEY)
}

export function setToken(token) {
  if (token) sessionStorage.setItem(TOKEN_KEY, token)
  else sessionStorage.removeItem(TOKEN_KEY)
}

async function request(path, { method = 'GET', body } = {}) {
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
