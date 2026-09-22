import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'theme.dart';
import 'pages/login_screen.dart';
import 'pages/erp_shell.dart';

void main() {
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
      home: ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          final user = authService.user;
          if (user == null) {
            return LoginScreen(
              onSuccess: (_) {}, // state berubah → shell dibangun ulang
            );
          }
          return ErpShell(key: ValueKey(user.id), user: user);
        },
      ),
    );
  }
}
