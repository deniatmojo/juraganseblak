import { useState } from 'react'

const employees = [
  { name: 'Melati Putri', img: 'https://randomuser.me/api/portraits/women/65.jpg', posisi: 'Kasir', masuk: '08.58', keluar: '—', status: 'Hadir', cls: 'text-green-700 bg-green-50' },
  { name: 'Dimas Ariyanto', img: 'https://randomuser.me/api/portraits/men/22.jpg', posisi: 'Koki', masuk: '07.45', keluar: '—', status: 'Hadir', cls: 'text-green-700 bg-green-50' },
  { name: 'Ayu Lestari', img: 'https://randomuser.me/api/portraits/women/12.jpg', posisi: 'Pelayan', masuk: '09.02', keluar: '—', status: 'Hadir', cls: 'text-green-700 bg-green-50' },
  { name: 'Rizky Ramadhan', img: 'https://randomuser.me/api/portraits/men/41.jpg', posisi: 'Pelayan', masuk: '—', keluar: '—', status: 'Izin', cls: 'text-ember bg-ember/10' },
  { name: 'Fitri Handayani', img: 'https://randomuser.me/api/portraits/women/33.jpg', posisi: 'Kasir', masuk: '13.00', keluar: '—', status: 'Hadir', cls: 'text-green-700 bg-green-50' },
  { name: 'Bayu Firmansyah', img: 'https://randomuser.me/api/portraits/men/76.jpg', posisi: 'Koki', masuk: '—', keluar: '—', status: 'Absen', cls: 'text-chili bg-red-50' },
  { name: 'Nadia Kusuma', img: 'https://randomuser.me/api/portraits/women/50.jpg', posisi: 'Pelayan', masuk: '08.40', keluar: '17.05', status: 'Selesai', cls: 'text-char/50 bg-cream' },
]

const summary = [
  { value: '15', label: 'Hadir Hari Ini', iconCls: 'bg-green-50', color: 'text-green-600', icon: 'M5 13l4 4L19 7' },
  { value: '2', label: 'Izin / Sakit', iconCls: 'bg-ember/10', color: 'text-ember', icon: 'M12 8v4l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z' },
  { value: '1', label: 'Tanpa Keterangan', iconCls: 'bg-red-50', color: 'text-chili', icon: 'M6 18L18 6M6 6l12 12' },
]

export default function Absensi() {
  const [clockedIn, setClockedIn] = useState(false)
  const [statusText, setStatusText] = useState('Belum absen masuk hari ini')

  const toggleClock = () => {
    const now = new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
    if (!clockedIn) {
      setStatusText('Absen masuk pukul ' + now)
    } else {
      setStatusText('Absen keluar pukul ' + now)
    }
    setClockedIn(!clockedIn)
  }

  return (
    <main className="flex-1 p-5 md:p-8 space-y-7">
      {/* CLOCK IN/OUT CARD */}
      <div className="bg-char rounded-2xl p-7 md:p-8 grid md:grid-cols-[1fr_auto] gap-6 items-center">
        <div>
          <p className="text-ember font-bold text-xs mb-2">Absensi Kamu</p>
          <div className="flex items-center gap-4">
            <img src="https://randomuser.me/api/portraits/men/54.jpg" alt="Foto profil" className="w-14 h-14 rounded-full object-cover ring-2 ring-chili" />
            <div>
              <p className="font-display text-xl text-cream uppercase leading-none">Rangga Saputra</p>
              <p className="text-cream/50 text-sm mt-1.5">{statusText}</p>
            </div>
          </div>
        </div>
        <button
          onClick={toggleClock}
          className={`clock-btn w-full md:w-auto font-bold text-white px-10 py-5 rounded-2xl text-lg flex items-center justify-center gap-3 ${
            clockedIn ? 'bg-char-soft hover:bg-char-line border border-cream/20' : 'bg-chili hover:bg-chili-dark'
          }`}
        >
          <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          {clockedIn ? 'Clock Out' : 'Clock In'}
        </button>
      </div>

      {/* SUMMARY STRIP */}
      <div className="grid sm:grid-cols-3 gap-5">
        {summary.map((s) => (
          <div key={s.label} className="bg-white rounded-2xl p-6 border border-black/5 shadow-sm flex items-center gap-4">
            <span className={`w-11 h-11 rounded-xl ${s.iconCls} grid place-items-center shrink-0`}>
              <svg className={`w-5 h-5 ${s.color}`} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d={s.icon} /></svg>
            </span>
            <div>
              <p className="text-2xl font-display">{s.value}</p>
              <p className="text-xs text-char/50">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* EMPLOYEE TABLE */}
      <div className="bg-white rounded-2xl border border-black/5 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-6 py-5 border-b border-black/5">
          <h2 className="font-bold">Daftar Karyawan</h2>
          <span className="text-xs text-char/50">18 karyawan terdaftar</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[720px]">
            <thead>
              <tr className="text-left text-char/40 text-xs uppercase border-b border-black/5">
                <th className="px-6 py-3 font-bold">Karyawan</th>
                <th className="px-6 py-3 font-bold">Posisi</th>
                <th className="px-6 py-3 font-bold">Jam Masuk</th>
                <th className="px-6 py-3 font-bold">Jam Keluar</th>
                <th className="px-6 py-3 font-bold">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/5">
              {employees.map((emp) => (
                <tr key={emp.name} className="hover:bg-cream/60 transition-colors">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <img src={emp.img} alt="" className="w-9 h-9 rounded-full object-cover" />
                      <span className="font-semibold">{emp.name}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 text-char/60">{emp.posisi}</td>
                  <td className={`px-6 py-4 ${emp.masuk === '—' ? 'text-char/40' : ''}`}>{emp.masuk}</td>
                  <td className="px-6 py-4 text-char/40">{emp.keluar}</td>
                  <td className="px-6 py-4">
                    <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${emp.cls}`}>{emp.status}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </main>
  )
}
