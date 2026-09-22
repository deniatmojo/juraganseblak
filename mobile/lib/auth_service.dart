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
  final String role; // 'owner' | 'karyawan' (kasir dipetakan ke sini)

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isOwner => role == 'owner';
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
    final dbRole = u['role'] as String? ?? 'kasir';
    api.token = data['token'] as String?;
    _user = AppUser(
      id: u['id'] is int ? u['id'] : int.tryParse('${u['id']}') ?? 0,
      name: u['name'] ?? '',
      email: u['email'] ?? email,
      role: dbRole == 'kasir' ? 'karyawan' : 'owner',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('erp_user', jsonEncode({
      'id': _user!.id,
      'name': _user!.name,
      'email': _user!.email,
      'role': _user!.role,
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
