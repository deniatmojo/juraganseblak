import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Klien API — padanan web/src/api.js. Base URL menunjuk ke server produksi
/// (Express di port 3002, diproxy /api oleh web server).
class ApiClient {
  static const baseUrl = 'https://juragan-seblak.airadynamics.com/api';
  static const _tokenKey = 'erp_token';

  /// Endpoint yang mengikuti cabang aktif (sama dengan BRANCH_PATHS di web).
  static const _branchPaths = [
    '/stock', '/orders', '/shifts', '/transactions', '/finance', '/online/tables',
  ];

  /// Diisi di main(): nilai cabang aktif (id / 'all') atau null bila tidak
  /// perlu disuntik (kasir, akun terkunci cabang).
  String? Function()? branchProvider;

  bool _followsBranch(String path) => _branchPaths.any(
      (p) => path == p || path.startsWith('$p/') || path.startsWith('$p?'));

  /// Suntik branch_id otomatis (query pada GET, field body pada POST/PATCH)
  /// bila halaman belum menentukannya sendiri — padanan withBranch() web.
  (String, Object?) _withBranch(String path, String method, Object? body) {
    final branch = branchProvider?.call();
    if (branch == null || branch.isEmpty || !_followsBranch(path)) {
      return (path, body);
    }
    if (method == 'GET') {
      if (RegExp(r'[?&]branch_id=').hasMatch(path)) return (path, body);
      return ('$path${path.contains('?') ? '&' : '?'}branch_id=$branch', body);
    }
    if (body is Map && !body.containsKey('branch_id')) {
      return (path, {...body, 'branch_id': int.tryParse(branch) ?? branch});
    }
    return (path, body);
  }

  String? _token;
  String? get token => _token;
  set token(String? t) {
    _token = t;
    _persist(t);
  }

  Future<void> _persist(String? t) async {
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      prefs.remove(_tokenKey);
    } else {
      prefs.setString(_tokenKey, t);
    }
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  /// Dipanggil saat sesi 401 — supaya shell mengembalikan user ke login.
  void Function()? onUnauthorized;

  Future<dynamic> request(String rawPath,
      {String method = 'GET', Object? body}) async {
    final (path, sentBody) = _withBranch(rawPath, method, body);
    body = sentBody;
    late http.Response res;
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    try {
      switch (method) {
        case 'POST':
          res = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          res = await http
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          res = await http.get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
      }
    } catch (_) {
      throw Exception('Tidak bisa terhubung ke server. Cek koneksi internet.');
    }

    if (res.statusCode >= 400) {
      if (res.statusCode == 401 && onUnauthorized != null) onUnauthorized!();
      String msg = 'Request gagal (${res.statusCode})';
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['error'] != null) msg = data['error'];
      } catch (_) {}
      throw Exception(msg);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Future<dynamic> get(String path) => request(path);
  Future<dynamic> post(String path, Object body) =>
      request(path, method: 'POST', body: body);
  Future<dynamic> patch(String path, Object body) =>
      request(path, method: 'PATCH', body: body);
  Future<dynamic> del(String path) => request(path, method: 'DELETE');

  /// Upload gambar multipart — padanan fetch('/api/upload', FormData) di web
  /// (field 'photo', server multer hanya menerima jpg/png/webp/gif, maks 2MB).
  Future<dynamic> upload(String path,
      {required String field,
      required String filename,
      required List<int> bytes,
      String contentType = 'image/jpeg'}) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_token'
      ..files.add(http.MultipartFile.fromBytes(field, bytes,
          filename: filename,
          contentType: MediaType.parse(contentType)));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 400) {
      if (res.statusCode == 401 && onUnauthorized != null) onUnauthorized!();
      String msg = 'Upload gagal (${res.statusCode})';
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['error'] != null) msg = data['error'];
      } catch (_) {}
      throw Exception(msg);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }
}

final api = ApiClient();
