import 'package:flutter/material.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'theme.dart';
import 'pages/login_screen.dart';
import 'pages/erp_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  api.onUnauthorized = () => authService.logout();
  runApp(const JuraganSeblakApp());
}

class JuraganSeblakApp extends StatelessWidget {
  const JuraganSeblakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juragan Seblak',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Aplikasi dibuka LANGSUNG ke login ERP — tidak ada landing page.
      home: FutureBuilder(
        future: authService.restore(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _Splash();
          }
          return ListenableBuilder(
            listenable: authService,
            builder: (context, _) {
              final user = authService.user;
              if (user == null) {
                return const LoginScreen();
              }
              return ErpShell(key: ValueKey(user.id), user: user);
            },
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.char,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/logo.jpg', width: 80, height: 80, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          Text('JURAGAN', style: AppText.display(size: 26, color: AppColors.cream)),
          Text('SEBLAK', style: AppText.display(size: 16, color: AppColors.ember)),
          const SizedBox(height: 24),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                color: AppColors.chiliLight, strokeWidth: 2.5),
          ),
        ]),
      ),
    );
  }
}
