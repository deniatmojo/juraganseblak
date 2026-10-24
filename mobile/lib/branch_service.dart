import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Satu cabang aktif (GET /api/branch-options).
class BranchOption {
  final int id;
  final String name;
  const BranchOption(this.id, this.name);
}

/// Cabang aktif aplikasi — padanan web/src/branch.js + pemilih cabang di
/// AdminLayout.jsx. Owner (dan admin yang belum dikunci) memilih cabang di
/// header; nilainya: id cabang atau 'all' (hanya untuk melihat laporan
/// gabungan). Admin yang dikunci ke satu cabang dan kasir ditentukan server.
class BranchService extends ChangeNotifier {
  static const _key = 'erp_branch';

  List<BranchOption> branches = [];
  String selected = ''; // '' | 'all' | '<id>'

  bool canPick(AppUser? u) => u != null && u.branchScoped && u.branchId == null;

  /// Cabang efektif untuk label/default form: pilihan header (bila id),
  /// cabang terkunci admin, atau null (semua / belum ditentukan).
  int? effectiveId(AppUser? u) {
    if (u != null && u.isLockedAdmin) return u.branchId;
    return int.tryParse(selected);
  }

  String nameOf(int? id) {
    for (final b in branches) {
      if (b.id == id) return b.name;
    }
    return '-';
  }

  /// Nilai `branch_id` yang disuntikkan ke request API (null = tidak disuntik).
  /// Kasir/karyawan tidak disuntik — server memakai cabang shift mereka.
  String? paramFor(AppUser? u) {
    if (u == null || !u.branchScoped) return null;
    return selected.isEmpty ? null : selected;
  }

  Future<void> reload() async {
    try {
      final rows = await api.get('/branch-options') as List;
      branches = rows
          .map((r) => Map<String, dynamic>.from(r as Map))
          .map((r) => BranchOption(
              r['id'] is int ? r['id'] as int : int.parse('${r['id']}'),
              '${r['name']}'))
          .toList();
    } catch (_) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    var saved = prefs.getString(_key) ?? '';
    final valid =
        saved == 'all' || branches.any((b) => '${b.id}' == saved);
    if (!valid) saved = branches.isEmpty ? '' : '${branches.first.id}';
    selected = saved;
    notifyListeners();
  }

  Future<void> select(String value) async {
    selected = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
    notifyListeners();
  }
}

final branchService = BranchService();
