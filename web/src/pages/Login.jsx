import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { authenticate, login, ROLE_HOME } from '../auth'

export default function Login() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = (e) => {
    e.preventDefault()
    setError('')

    const account = authenticate(email, password)
    if (account) {
      setLoading(true)
      login(account)
      setTimeout(() => navigate(ROLE_HOME[account.role] ?? '/erp'), 500)
    } else {
      setError('Email atau password salah. Coba lagi.')
    }
  }

  const inputCls = 'w-full bg-white text-char border border-black/15 rounded-xl px-4 py-3 text-sm'

  return (
    <div className="min-h-screen bg-char text-cream antialiased flex flex-col">
      <header className="border-b border-char-line">
        <div className="max-w-3xl mx-auto px-5 md:px-8 h-16 md:h-20 flex items-center justify-between">
          <Link to="/" className="font-display text-2xl text-cream tracking-wide">
            BARA<span className="text-chili">.</span>PEDAS
          </Link>
          <Link to="/" className="text-cream/70 hover:text-ember text-sm font-semibold flex items-center gap-1.5 transition-colors">
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2"><path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" /></svg>
            Kembali
          </Link>
        </div>
      </header>

      <main className="flex-1 flex items-center justify-center px-5 py-12">
        <div className="w-full max-w-md">
          <div className="text-center mb-8">
            <div className="w-14 h-14 rounded-full bg-chili/20 grid place-items-center mx-auto mb-5">
              <svg className="w-7 h-7 text-chili" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
            </div>
            <h1 className="font-display text-3xl md:text-4xl uppercase leading-tight">Login Sistem ERP</h1>
            <p className="mt-3 text-cream/60 text-sm">Masuk untuk mengelola pesanan, stok, dan laporan bisnis Bara.Pedas.</p>
          </div>

          <form onSubmit={handleSubmit} className="bg-char-soft border border-char-line rounded-2xl p-6 md:p-8 space-y-5">
            <div>
              <label htmlFor="email" className="block text-sm font-bold mb-1.5">Email</label>
              <input
                type="email"
                id="email"
                required
                placeholder="admin@barapedas.id"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className={inputCls}
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-bold mb-1.5">Password</label>
              <input
                type="password"
                id="password"
                required
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className={inputCls}
              />
            </div>

            {error && (
              <p className="text-chili-light text-sm font-semibold" role="alert">{error}</p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-chili hover:bg-chili-dark disabled:opacity-60 text-white font-bold py-4 rounded-full transition-colors text-sm md:text-base"
            >
              {loading ? 'Memeriksa...' : 'Masuk ke ERP'}
            </button>

            <p className="text-center text-xs text-cream/40">
              Akun demo: <span className="text-cream/70 font-semibold">admin@barapedas.id</span> / <span className="text-cream/70 font-semibold">admin123</span>
            </p>
          </form>
        </div>
      </main>
    </div>
  )
}
