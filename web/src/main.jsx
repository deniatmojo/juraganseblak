import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Landing from './pages/Landing.jsx'
import Order from './pages/Order.jsx'
import Login from './pages/Login.jsx'
import AdminLayout from './components/AdminLayout.jsx'
import AdminDashboard from './pages/admin/Dashboard.jsx'
import Pos from './pages/admin/Pos.jsx'
import Absensi from './pages/admin/Absensi.jsx'
import Stock from './pages/admin/Stock.jsx'
import Keuangan from './pages/admin/Keuangan.jsx'
import './index.css'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter>
      <Routes>
        {/* Website publik */}
        <Route path="/" element={<Landing />} />
        <Route path="/order" element={<Order />} />
        <Route path="/login" element={<Login />} />

        {/* ERP Admin */}
        <Route path="/erp" element={<AdminLayout />}>
          <Route index element={<AdminDashboard />} />
          <Route path="pos" element={<Pos />} />
          <Route path="absensi" element={<Absensi />} />
          <Route path="stock" element={<Stock />} />
          <Route path="keuangan" element={<Keuangan />} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  </StrictMode>,
)
