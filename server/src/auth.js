import jwt from 'jsonwebtoken';

const SECRET = process.env.JWT_SECRET || 'dev-secret-ganti-di-produksi';
const TOKEN_TTL = '12h';

export function signToken(user) {
  return jwt.sign({ sub: user.id, role: user.role, name: user.name }, SECRET, {
    expiresIn: TOKEN_TTL,
  });
}

function readToken(req) {
  const header = req.get('authorization') || '';
  return header.startsWith('Bearer ') ? header.slice(7) : null;
}

// Wajib login (token valid). Menempelkan req.user = { id, role, name }.
export function requireAuth(req, res, next) {
  const token = readToken(req);
  if (!token) return res.status(401).json({ error: 'Login diperlukan' });
  try {
    const payload = jwt.verify(token, SECRET);
    req.user = { id: payload.sub, role: payload.role, name: payload.name };
    next();
  } catch {
    return res.status(401).json({ error: 'Sesi berakhir, silakan login ulang' });
  }
}

// Batasi role tertentu, mis. requireRole('owner', 'admin')
export function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user?.role)) {
      return res.status(403).json({ error: 'Anda tidak punya akses fitur ini' });
    }
    next();
  };
}
