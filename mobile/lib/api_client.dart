import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Klien API — padanan web/src/api.js. Base URL menunjuk ke server produksi
/// (Express di port 3002, diproxy /api oleh web server).
class ApiClient {
  static const baseUrl = 'https://template-one.airadynamics.com/api';
  static const _tokenKey = 'erp_token';

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

  Future<dynamic> request(String path,
      {String method = 'GET', Object? body}) async {
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
}

final api = ApiClient();
