import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Sesi pengguna — login server-side via POST /api/auth/login (JWT),
/// padanan serverLogin() di web/src/auth.js. Token & profil bertahan di
/// device, jadi tidak perlu login ulang tiap membuka aplikasi.
class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // 'owner' | 'admin' | 'kasir' | 'karyawan' — sama dengan DB
  final int? branchId; // admin: dikunci ke cabang ini; kasir: cabang bawaan

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.branchId,
  });

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get isLeader => role == 'leader';

  /// Role yang bekerja lintas cabang lewat pemilih cabang di header
  /// (owner, admin, dan Admin Gudang untuk stok per cabang).
  bool get branchScoped => role == 'owner' || role == 'admin' || role == 'gudang';

  /// Akses melihat & mengoreksi absensi semua karyawan.
  bool get canManageAttendance => isAdmin || isLeader;

  /// Admin / Admin Gudang yang dikunci ke satu cabang tidak bisa mengganti cabang.
  bool get isLockedAdmin => (role == 'admin' || role == 'gudang') && branchId != null;

  /// Label tampilan, sama dengan roleLabel AdminLayout.jsx web.
  String get roleLabel => const {
        'owner': 'Super Admin',
        'admin': 'Admin',
        'kasir': 'Karyawan Kasir',
        'karyawan': 'Karyawan',
        'gudang': 'Admin Gudang',
        'leader': 'Tim Leader',
      }[role] ?? role;
}

class AuthService extends ChangeNotifier {
  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Pulihkan sesi tersimpan saat aplikasi dibuka.
  Future<void> restore() async {
    await api.loadToken();
    if (api.token == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('erp_user');
    if (raw != null) {
      try {
        final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _user = AppUser(
          id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
          name: j['name'] ?? '',
          email: j['email'] ?? '',
          role: j['role'] ?? 'karyawan',
          branchId: j['branch_id'] == null
              ? null
              : (j['branch_id'] is int
                  ? j['branch_id'] as int
                  : int.tryParse('${j['branch_id']}')),
        );
      } catch (_) {}
    }
  }

  Future<AppUser> login(String email, String password) async {
    final data = await api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    // Role DB ('owner'|'admin'|'kasir') dipetakan ke role UI, sama seperti web.
    final u = Map<String, dynamic>.from(data['user'] as Map);
    // Role diteruskan apa adanya (owner/admin/kasir/karyawan) — matriks menu
    // di erp_shell mengikuti web/src/auth.js isAllowed().
    api.token = data['token'] as String?;
    _user = AppUser(
      id: u['id'] is int ? u['id'] : int.tryParse('${u['id']}') ?? 0,
      name: u['name'] ?? '',
      email: u['email'] ?? email,
      role: u['role'] as String? ?? 'karyawan',
      branchId: u['branch_id'] == null
          ? null
          : (u['branch_id'] is int
              ? u['branch_id'] as int
              : int.tryParse('${u['branch_id']}')),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('erp_user', jsonEncode({
      'id': _user!.id,
      'name': _user!.name,
      'email': _user!.email,
      'role': _user!.role,
      'branch_id': _user!.branchId,
    }));
    notifyListeners();
    return _user!;
  }

  void logout() {
    api.token = null;
    _user = null;
    _clearUser();
    notifyListeners();
  }

  Future<void> _clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('erp_user');
  }
}

final authService = AuthService();
