import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Landing from './pages/Landing.jsx'
import Order from './pages/Order.jsx'
import Login from './pages/Login.jsx'
import Download from './pages/Download.jsx'
import AdminLayout from './components/AdminLayout.jsx'
import AdminDashboard from './pages/admin/Dashboard.jsx'
import Pos from './pages/admin/Pos.jsx'
import Menu from './pages/admin/Menu.jsx'
import Absensi from './pages/admin/Absensi.jsx'
import Stock from './pages/admin/Stock.jsx'
import Keuangan from './pages/admin/Keuangan.jsx'
import KeuanganLayout from './pages/admin/keuangan/KeuanganLayout.jsx'
import LabaRugi from './pages/admin/keuangan/LabaRugi.jsx'
import ArusKas from './pages/admin/keuangan/ArusKas.jsx'
import BukuBesar from './pages/admin/keuangan/BukuBesar.jsx'
import Jurnal from './pages/admin/keuangan/Jurnal.jsx'
import Karyawan from './pages/admin/Karyawan.jsx'
import Gaji from './pages/admin/Gaji.jsx'
import './index.css'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter>
      <Routes>
        {/* Website publik */}
        <Route path="/" element={<Landing />} />
        <Route path="/order" element={<Order />} />
        <Route path="/login" element={<Login />} />
        <Route path="/download" element={<Download />} />

        {/* ERP Admin */}
        <Route path="/erp" element={<AdminLayout />}>
          <Route index element={<AdminDashboard />} />
          <Route path="pos" element={<Pos />} />
          <Route path="menu" element={<Menu />} />
          <Route path="absensi" element={<Absensi />} />
          <Route path="stock" element={<Stock />} />
          <Route path="keuangan" element={<KeuanganLayout />}>
            <Route index element={<Keuangan />} />
            <Route path="laba-rugi" element={<LabaRugi />} />
            <Route path="arus-kas" element={<ArusKas />} />
            <Route path="buku-besar" element={<BukuBesar />} />
            <Route path="jurnal" element={<Jurnal />} />
          </Route>
          <Route path="karyawan" element={<Karyawan />} />
          <Route path="gaji" element={<Gaji />} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  </StrictMode>,
)
