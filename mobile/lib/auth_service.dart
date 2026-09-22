import 'dart:async';
import 'package:flutter/foundation.dart';

/// Sesi pengguna — Tahap 1 masih lokal (mock).
/// Tahap 2 akan diganti dengan POST /api/auth/login (JWT) ke server ERP.
class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // 'owner' | 'karyawan'

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

  /// Akun demo — sama seperti kredensial demo di halaman Login web.
  static const _demoAccounts = {
    'owner@juraganseblak.id': ('seblak123', 'Rangga Saputra', 'owner'),
    'kasir@juraganseblak.id': ('kasir123', 'Siti Nurhaliza', 'karyawan'),
  };

  /// Validasi kredensial. Simulasi latensi jaringan; Tahap 2: serverLogin().
  Future<AppUser> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final acc = _demoAccounts[email.trim().toLowerCase()];
    if (acc == null || acc.$1 != password) {
      throw Exception('Email atau password salah. Coba lagi.');
    }
    final id = acc.$3 == 'owner' ? 1 : 2;
    _user = AppUser(
        id: id, name: acc.$2, email: email.trim().toLowerCase(), role: acc.$3);
    notifyListeners();
    return _user!;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

final authService = AuthService();
