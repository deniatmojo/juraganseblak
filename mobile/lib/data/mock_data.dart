// Data contoh (mock) Tahap 1 — mencerminkan struktur endpoint server:
// /products, /categories, /stock, /orders, /transactions, /employees, /payroll.
// Tahap 2: ganti pemakaian kelas ini dengan hasil fetch API.

class MenuItem {
  final int id;
  final String name;
  final String category; // key kategori
  final int price;
  final int hpp;
  final bool isAvailable;
  const MenuItem(this.id, this.name, this.category, this.price, this.hpp, {this.isAvailable = true});
}

class Category {
  final String key;
  final String label;
  const Category(this.key, this.label);
}

class StockItem {
  final int id;
  final String name;
  final String category;
  final String unit;
  double qty;
  final double minQty;
  bool get isLow => qty <= minQty;
  StockItem(this.id, this.name, this.category, this.unit, this.qty, this.minQty);
}

class TxRow {
  final String id;
  final String customer;
  final String type; // 'Dine-in' | 'Online'
  final int total;
  final String status; // 'Lunas' | 'Pending' | 'Batal'
  const TxRow(this.id, this.customer, this.type, this.total, this.status);
}

class FinanceTx {
  final String type; // 'income' | 'expense'
  final String category;
  final int amount;
  final String note;
  final String date;
  const FinanceTx(this.type, this.category, this.amount, this.note, this.date);
}

class Employee {
  final int id;
  final String name;
  final String position;
  final String role; // role akun: owner/admin/kasir
  final String phone;
  final int dailyRate;
  final String shiftStart;
  final int workHours;
  bool active;
  Employee(this.id, this.name, this.position, this.role, this.phone, this.dailyRate,
      {this.shiftStart = '09:00', this.workHours = 8, this.active = true});
}

class AttendanceRow {
  final int employeeId;
  final String name;
  String status; // hadir/terlambat/izin/sakit/alpa/''
  String? clockIn;
  String? clockOut;
  String? note;
  AttendanceRow(this.employeeId, this.name, this.status);
}

class PayrollRow {
  final Employee employee;
  final int daysPresent;
  final int daysLate;
  final int daysOff;
  int kasbonOpen;
  int get gaji => daysPresent * employee.dailyRate;
  int get total => gaji - kasbonOpen;
  PayrollRow(this.employee, this.daysPresent, this.daysLate, this.daysOff, this.kasbonOpen);
}

class MockData {
  static const categories = [
    Category('seblak', 'Seblak'),
    Category('topping', 'Topping'),
    Category('minuman', 'Minuman'),
    Category('camilan', 'Camilan'),
  ];

  static const menu = [
    MenuItem(1, 'Seblak Komplit', 'seblak', 25000, 12000),
    MenuItem(2, 'Seblak Ceker', 'seblak', 20000, 9500),
    MenuItem(3, 'Seblak Tulang', 'seblak', 18000, 8000),
    MenuItem(4, 'Seblak Ayam Suwir', 'seblak', 22000, 10000),
    MenuItem(5, 'Seblak Mie Instan', 'seblak', 15000, 6000, isAvailable: false),
    MenuItem(6, 'Batagor Bakar', 'camilan', 12000, 5000),
    MenuItem(7, 'Cireng Rujak', 'camilan', 8000, 3000),
    MenuItem(8, 'Es Teh Manis', 'minuman', 5000, 1500),
    MenuItem(9, 'Es Jeruk', 'minuman', 7000, 2500),
    MenuItem(10, 'Teh Tarik', 'minuman', 9000, 3500),
    MenuItem(11, 'Ceker Mercon', 'topping', 10000, 4500),
    MenuItem(12, 'Sosis Bakar', 'topping', 8000, 3500),
  ];

  static final stock = [
    StockItem(1, 'Kerupuk mie', 'Bahan Utama', 'kg', 8.5, 3),
    StockItem(2, 'Ceker ayam', 'Protein', 'kg', 4.2, 5),
    StockItem(3, 'Sosis sapi', 'Protein', 'kg', 6.0, 4),
    StockItem(4, 'Cabe rawit merah', 'Bumbu', 'kg', 1.8, 2),
    StockItem(5, 'Bawang putih', 'Bumbu', 'kg', 2.5, 1),
    StockItem(6, 'Mie instan', 'Bahan Utama', 'pcs', 120, 40),
    StockItem(7, 'Teh tubruk', 'Minuman', 'kg', 3.0, 1),
    StockItem(8, 'Es batu', 'Minuman', 'kg', 10.0, 4),
  ];

  static const recentOrders = [
    TxRow('TRX-0921', 'Dinda Ayu', 'Dine-in', 62000, 'Lunas'),
    TxRow('TRX-0920', 'Umum', 'Online', 38000, 'Lunas'),
    TxRow('TRX-0919', 'Bagas P.', 'Dine-in', 84000, 'Lunas'),
    TxRow('TRX-0918', 'Umum', 'Online', 25000, 'Pending'),
    TxRow('TRX-0917', 'Nadia S.', 'Dine-in', 47000, 'Lunas'),
  ];

  /// Omzet 7 hari terakhir untuk grafik Dashboard.
  static const weekly = [420000, 510000, 380000, 610000, 720000, 950000, 830000];

  static const financeTx = [
    FinanceTx('income', 'penjualan', 1250000, 'Omzet shift siang', '2026-09-22'),
    FinanceTx('income', 'penjualan', 980000, 'Omzet shift malam', '2026-09-22'),
    FinanceTx('expense', 'belanja', 350000, 'Belanja ceker & kerupuk', '2026-09-22'),
    FinanceTx('expense', 'operasional', 60000, 'Gas LPG 3kg', '2026-09-21'),
    FinanceTx('expense', 'utilitas', 150000, 'Token listrik', '2026-09-21'),
    FinanceTx('income', 'penjualan', 1850000, 'Omzet akhir pekan', '2026-09-20'),
  ];

  static final employees = [
    Employee(1, 'Rangga Saputra', 'Owner', 'owner', '081234567890', 0, shiftStart: '08:00'),
    Employee(2, 'Siti Nurhaliza', 'Kasir', 'kasir', '081298765432', 80000),
    Employee(3, 'Budi Santoso', 'Koki', 'kasir', '081377788899', 90000, shiftStart: '07:00'),
    Employee(4, 'Dewi Lestari', 'Asisten Dapur', 'kasir', '081455566677', 70000),
    Employee(5, 'Agus Wijaya', 'Kurir', 'kasir', '081533344455', 75000, shiftStart: '10:00', workHours: 6),
  ];

  static final attendance = [
    AttendanceRow(2, 'Siti Nurhaliza', ''),
    AttendanceRow(3, 'Budi Santoso', ''),
    AttendanceRow(4, 'Dewi Lestari', ''),
    AttendanceRow(5, 'Agus Wijaya', ''),
  ];

  static List<PayrollRow> payroll(List<Employee> emps) => [
        PayrollRow(emps[1], 21, 2, 1, 150000),
        PayrollRow(emps[2], 23, 0, 0, 0),
        PayrollRow(emps[3], 19, 3, 2, 75000),
        PayrollRow(emps[4], 20, 1, 0, 0),
      ];
}
