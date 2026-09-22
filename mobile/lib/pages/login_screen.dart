import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../theme.dart';

/// Layar login — pembuka aplikasi. Tidak ada landing page: dari sini langsung
/// masuk ke shell ERP (owner) atau POS (karyawan).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await authService.login(_email.text, _password.text);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.char,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  // Logo aplikasi
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/logo.jpg',
                        width: 88, height: 88, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'JURAGAN',
                    style: AppText.display(size: 30, color: AppColors.cream),
                  ),
                  Text('SEBLAK',
                      style: AppText.display(size: 30, color: AppColors.ember)),

                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.chili.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: AppColors.chiliLight, size: 30),
                  ),
                  const SizedBox(height: 18),
                  Text('LOGIN SISTEM ERP',
                      textAlign: TextAlign.center,
                      style: AppText.display(size: 26, color: AppColors.cream)),
                  const SizedBox(height: 10),
                  Text(
                    'Masuk untuk mengelola pesanan, stok, dan laporan bisnis Juragan Seblak.',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 13, color: AppColors.cream.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 28),

                  // Kartu form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.charSoft,
                      border: Border.all(color: AppColors.charLine),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email',
                            style: AppText.body(
                                size: 13, weight: FontWeight.w700, color: AppColors.cream)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: AppText.body(color: AppColors.char),
                          decoration: const InputDecoration(
                              hintText: 'owner@juraganseblak.id'),
                        ),
                        const SizedBox(height: 16),
                        Text('Password',
                            style: AppText.body(
                                size: 13, weight: FontWeight.w700, color: AppColors.cream)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          style: AppText.body(color: AppColors.char),
                          decoration: const InputDecoration(hintText: '••••••••'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!,
                              style: AppText.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: AppColors.chiliLight)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.chili,
                              disabledBackgroundColor: AppColors.chiliDark,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                              elevation: 0,
                            ),
                            child: Text(
                              _loading ? 'Memeriksa...' : 'Masuk ke ERP',
                              style: AppText.body(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Demo owner: owner@juraganseblak.id / seblak123\nDemo kasir: kasir@juraganseblak.id / kasir123',
                          textAlign: TextAlign.center,
                          style: AppText.body(
                              size: 11,
                              color: AppColors.cream.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
