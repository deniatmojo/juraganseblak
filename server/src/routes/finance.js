import { Router } from 'express';
import { pool } from '../db.js';

// ============================================================
// Modul Laporan Keuangan (pendekatan hybrid):
// transactions (kas single-entry) + HPP dari order_items dianggap
// sebagai jurnal virtual dengan debit-kredit turunan, lalu
// diklasifikasikan ke akun untuk Laba Rugi / Arus Kas / Buku Besar.
// ============================================================
const router = Router();

const catLabel = (cat) => {
  const map = {
    penjualan: 'Pendapatan Penjualan',
    void: 'Koreksi Penjualan (Void)',
    belanja: 'Pembelian Bahan Baku',
    gaji: 'Beban Gaji',
    operasional: 'Beban Operasional',
    utilitas: 'Beban Utilitas (Listrik/Air/Gas)',
    sewa: 'Beban Sewa',
    peralatan: 'Peralatan (Investasi)',
    aset: 'Aset (Investasi)',
    modal: 'Setoran Modal',
    prive: 'Pengambilan Owner (Prive)',
    lain: 'Lain-lain',
  };
  return map[cat] || cat;
};

// Klasifikasi arus kas & laba rugi per kategori transaksi.
// return { group: 'operating'|'investing'|'financing', side: 'in'|'out', label }
function classify(type, category) {
  const c = (category || '').toLowerCase();
  if (['peralatan', 'investasi', 'aset'].some((k) => c.includes(k))) return { group: 'investing', label: catLabel(c) };
  if (c.includes('modal')) return { group: 'financing', side: 'in', label: catLabel('modal') };
  if (c.includes('prive') || c.includes('pengambilan')) return { group: 'financing', side: 'out', label: catLabel('prive') };
  if (c === 'void') return { group: 'operating', side: 'out', label: catLabel('void') };
  if (type === 'income') return { group: 'operating', side: 'in', label: catLabel(c) };
  return { group: 'operating', side: 'out', label: catLabel(c) };
}

// ---------- PERSEDIAAN & HPP (metode akuntansi penuh) ----------
// Nilai persediaan pada tanggal tertentu: stok sekarang dikurangi dampak
// pergerakan setelah tanggal tsb (masuk mengurangi persediaan masa lalu,
// keluar menambahkannya kembali). Item dinilai dengan harga beli terakhir.
async function inventoryValueAt(dateEndExclusive) {
  const [[nowVal]] = await pool.query(
    `SELECT COALESCE(SUM(qty * unit_cost), 0) v FROM stock_items WHERE is_active = 1`
  );
  const [[mv]] = await pool.query(
    `SELECT
       COALESCE(SUM(CASE WHEN m.type = 'in' THEN m.qty * COALESCE(NULLIF(m.unit_cost, 0), s.unit_cost) ELSE 0 END), 0) AS in_val,
       COALESCE(SUM(CASE WHEN m.type = 'out' THEN m.qty * s.unit_cost ELSE 0 END), 0) AS out_val
     FROM stock_movements m JOIN stock_items s ON s.id = m.item_id
     WHERE m.created_at >= :d`,
    { d: dateEndExclusive }
  );
  return Number(nowVal.v) - Number(mv.in_val) + Number(mv.out_val);
}

// Total pembelian bahan dalam periode = barang masuk (in) bernilai, kecuali stok awal.
async function purchasesInPeriod(from, to) {
  const [[row]] = await pool.query(
    `SELECT COALESCE(SUM(m.qty * COALESCE(NULLIF(m.unit_cost, 0), s.unit_cost)), 0) v
     FROM stock_movements m JOIN stock_items s ON s.id = m.item_id
     WHERE m.type = 'in' AND (m.note IS NULL OR m.note != 'Stok awal')
       AND m.created_at >= :from AND m.created_at <= :to`,
    { from: `${from} 00:00:00`, to: `${to} 23:59:59` }
  );
  return Number(row.v);
}

// HPP penuh = Persediaan awal + Pembelian − Persediaan akhir.
async function hppForPeriod(from, to) {
  const [opening, purchases, closing, recipe] = await Promise.all([
    inventoryValueAt(`${from} 00:00:00`),
    purchasesInPeriod(from, to),
    inventoryValueAt(`${to} 23:59:59`),
    pool.query(
      `SELECT COALESCE(SUM(oi.qty * p.hpp), 0) AS hpp, COUNT(DISTINCT o.id) AS n_orders
       FROM order_items oi
       JOIN orders o ON o.id = oi.order_id
       JOIN products p ON p.id = oi.product_id
       WHERE o.voided_at IS NULL AND o.created_at >= :from AND o.created_at <= :to`,
      { from: `${from} 00:00:00`, to: `${to} 23:59:59` }
    ).then(([rows]) => ({ hpp: Number(rows[0].hpp), nOrders: Number(rows[0].n_orders) })),
  ]);
  return { opening, purchases, closing, hpp_recipe: recipe.hpp, nOrders: recipe.nOrders, hpp: opening + purchases - closing };
}

async function txInPeriod(from, to) {
  const [rows] = await pool.query(
    `SELECT t.id, t.type, t.category, t.amount, t.note, t.ref_order, t.created_at, u.name AS by_name
     FROM transactions t LEFT JOIN users u ON u.id = t.created_by
     WHERE t.created_at >= :from AND t.created_at <= :to
     ORDER BY t.created_at ASC`,
    { from: `${from} 00:00:00`, to: `${to} 23:59:59` }
  );
  return rows.map((r) => ({ ...r, amount: Number(r.amount) }));
}

const parseRange = (req, res) => {
  const from = req.query.from;
  const to = req.query.to || req.query.from;
  if (!from || !to) {
    res.status(400).json({ error: 'Parameter from dan to wajib diisi' });
    return null;
  }
  return { from, to };
};

// ---------- LABA RUGI ----------
// GET /api/finance/income-statement?from=&to=
router.get('/income-statement', async (req, res, next) => {
  try {
    const r = parseRange(req, res); if (!r) return;
    const txs = await txInPeriod(r.from, r.to);
    const inv = await hppForPeriod(r.from, r.to);

    const revenues = [];
    const expenses = [];
    for (const t of txs) {
      const c = (t.category || '').toLowerCase();
      if (t.type === 'income' && c !== 'modal') {
        const label = catLabel(c);
        const ex = revenues.find((x) => x.label === label);
        if (ex) ex.amount += t.amount; else revenues.push({ label, amount: t.amount });
      } else if (t.type === 'income' && c === 'modal') {
        // modal bukan pendapatan — masuk arus kas pendanaan saja
      } else if (c === 'void') {
        const label = catLabel('void');
        const ex = revenues.find((x) => x.label === label);
        if (ex) ex.amount -= t.amount; else revenues.push({ label, amount: -t.amount });
      } else if (c === 'belanja') {
        // Pembelian bahan TIDAK jadi beban laba rugi — nilainya mengalir ke
        // persediaan; yang jadi biaya hanyalah bahan yang terpakai (HPP).
      } else {
        const label = catLabel(c);
        const ex = expenses.find((x) => x.label === label);
        if (ex) ex.amount += t.amount; else expenses.push({ label, amount: t.amount });
      }
    }
    const revenueTotal = revenues.reduce((s, x) => s + x.amount, 0);
    const expenseTotal = expenses.reduce((s, x) => s + x.amount, 0);
    const gross = revenueTotal - inv.hpp;
    res.json({
      from: r.from, to: r.to,
      revenues, n_orders: inv.nOrders,
      revenue_total: revenueTotal,
      hpp: inv.hpp,
      inventory: {
        opening: inv.opening, purchases: inv.purchases, closing: inv.closing,
      },
      hpp_recipe: inv.hpp_recipe,
      gross_profit: gross,
      expenses, expense_total: expenseTotal,
      net_profit: gross - expenseTotal,
    });
  } catch (e) { next(e); }
});

// ---------- ARUS KAS ----------
// GET /api/finance/cash-flow?from=&to=
router.get('/cash-flow', async (req, res, next) => {
  try {
    const r = parseRange(req, res); if (!r) return;
    const txs = await txInPeriod(r.from, r.to);

    const [[open]] = await pool.query(
      `SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE -amount END), 0) AS bal
       FROM transactions WHERE created_at < :from`,
      { from: `${r.from} 00:00:00` }
    );
    const opening = Number(open.bal);

    const mk = () => ({ inflow: 0, outflow: 0, details: [] });
    const groups = { operating: mk(), investing: mk(), financing: mk() };
    for (const t of txs) {
      const cl = classify(t.type, t.category);
      const g = groups[cl.group];
      if (t.type === 'income' && cl.side !== 'out') {
        g.inflow += t.amount;
        const d = g.details.find((x) => x.label === cl.label && x.kind === 'in');
        if (d) d.amount += t.amount; else g.details.push({ label: cl.label, kind: 'in', amount: t.amount });
      } else {
        g.outflow += t.amount;
        const d = g.details.find((x) => x.label === cl.label && x.kind === 'out');
        if (d) d.amount += t.amount; else g.details.push({ label: cl.label, kind: 'out', amount: t.amount });
      }
    }
    const net = (g) => g.inflow - g.outflow;
    const netTotal = net(groups.operating) + net(groups.investing) + net(groups.financing);
    res.json({
      from: r.from, to: r.to,
      operating: { ...groups.operating, net: net(groups.operating) },
      investing: { ...groups.investing, net: net(groups.investing) },
      financing: { ...groups.financing, net: net(groups.financing) },
      opening_balance: opening,
      net_change: netTotal,
      closing_balance: opening + netTotal,
    });
  } catch (e) { next(e); }
});

// ---------- JURNAL (umum) ----------
// GET /api/finance/journal?from=&to= — entri debit-kredit turunan dari kas.
router.get('/journal', async (req, res, next) => {
  try {
    const r = parseRange(req, res); if (!r) return;
    const txs = await txInPeriod(r.from, r.to);
    const entries = txs.map((t, i) => {
      const label = catLabel((t.category || '').toLowerCase());
      const isIncome = t.type === 'income';
      return {
        no: i + 1,
        id: t.id,
        date: t.created_at,
        description: t.note || label,
        debit_account: isIncome ? 'Kas' : label,
        credit_account: isIncome ? label : 'Kas',
        amount: t.amount,
        by_name: t.by_name,
      };
    });
    const total = entries.reduce((s, e) => s + e.amount, 0);
    res.json({ from: r.from, to: r.to, entries, total_debit: total, total_kredit: total, balanced: true });
  } catch (e) { next(e); }
});

// ---------- DAFTAR AKUN ----------
// GET /api/finance/accounts — akun Kas, HPP, dan tiap kategori transaksi.
router.get('/accounts', async (_req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT DISTINCT type, category FROM transactions ORDER BY category');
    const accounts = [
      { key: 'kas', label: 'Kas & Bank', group: 'aset' },
      { key: 'hpp', label: 'Harga Pokok Penjualan (HPP)', group: 'hpp' },
    ];
    for (const r of rows) {
      const c = (r.category || 'lain').toLowerCase();
      const cl = classify(r.type, r.category);
      accounts.push({
        key: `cat:${r.type}:${c}`,
        label: catLabel(c),
        group: r.type === 'income' ? (c === 'modal' ? 'pendanaan' : 'pendapatan') : cl.group === 'investing' ? 'investasi' : cl.group === 'financing' ? 'pendanaan' : 'beban',
      });
    }
    res.json(accounts);
  } catch (e) { next(e); }
});

// ---------- BUKU BESAR ----------
// GET /api/finance/ledger?account=&from=&to= — saldo berjalan per akun.
router.get('/ledger', async (req, res, next) => {
  try {
    const r = parseRange(req, res); if (!r) return;
    const account = req.query.account || 'kas';
    let opening = 0;
    const rows = [];

    if (account === 'kas') {
      const [[open]] = await pool.query(
        `SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE -amount END), 0) AS bal
         FROM transactions WHERE created_at < :from`,
        { from: `${r.from} 00:00:00` }
      );
      opening = Number(open.bal);
      const txs = await txInPeriod(r.from, r.to);
      for (const t of txs) {
        rows.push({
          date: t.created_at, description: t.note || catLabel((t.category || '').toLowerCase()),
          debit: t.type === 'income' ? t.amount : 0, credit: t.type === 'income' ? 0 : t.amount,
        });
      }
    } else if (account === 'hpp') {
      const [items] = await pool.query(
        `SELECT o.order_no, o.created_at, SUM(oi.qty * p.hpp) AS hpp
         FROM order_items oi
         JOIN orders o ON o.id = oi.order_id
         JOIN products p ON p.id = oi.product_id
         WHERE o.voided_at IS NULL AND o.created_at >= :from AND o.created_at <= :to
         GROUP BY o.id, o.order_no, o.created_at
         ORDER BY o.created_at ASC`,
        { from: `${r.from} 00:00:00`, to: `${r.to} 23:59:59` }
      );
      for (const it of items) {
        rows.push({ date: it.created_at, description: `HPP pesanan ${it.order_no}`, debit: Number(it.hpp), credit: 0 });
      }
    } else if (account.startsWith('cat:')) {
      const [, type, cat] = account.split(':');
      const [[open]] = await pool.query(
        `SELECT COALESCE(SUM(amount), 0) AS total FROM transactions
         WHERE type = :type AND LOWER(category) = :cat AND created_at < :from`,
        { type, cat, from: `${r.from} 00:00:00` }
      );
      opening = Number(open.total);
      const [txs] = await pool.query(
        `SELECT t.created_at, t.amount, t.note, t.type FROM transactions t
         WHERE t.type = :type AND LOWER(t.category) = :cat
           AND t.created_at >= :from AND t.created_at <= :to
         ORDER BY t.created_at ASC`,
        { type, cat, from: `${r.from} 00:00:00`, to: `${r.to} 23:59:59` }
      );
      for (const t of txs) {
        const isDebit = type === 'expense';
        rows.push({ date: t.created_at, description: t.note || catLabel(cat), debit: isDebit ? Number(t.amount) : 0, credit: isDebit ? 0 : Number(t.amount) });
      }
    } else {
      return res.status(400).json({ error: 'Akun tidak dikenal' });
    }

    let bal = opening;
    const withBalance = rows.map((x) => {
      bal += x.debit - x.credit;
      return { ...x, balance: bal };
    });
    const totalDebit = rows.reduce((s, x) => s + x.debit, 0);
    const totalKredit = rows.reduce((s, x) => s + x.credit, 0);
    res.json({
      from: r.from, to: r.to, account,
      opening_balance: opening,
      rows: withBalance,
      total_debit: totalDebit, total_kredit: totalKredit,
      closing_balance: opening + totalDebit - totalKredit,
    });
  } catch (e) { next(e); }
});

export default router;
