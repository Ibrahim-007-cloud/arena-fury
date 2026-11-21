import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/models/app_user.dart';
import 'screens/auth/login_screen.dart';
import 'screens/menu/main_menu_screen.dart';
import 'services/app_services.dart';

class ArenaFuryApp extends StatelessWidget {
  const ArenaFuryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arena Fury',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AuthGate(),
    );
  }
}

/// Shows the login screen or the main menu depending on auth state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AppUser?> _stream = AppServices.auth.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _stream,
      initialData: AppServices.auth.currentUser,
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return const LoginScreen();
        return MainMenuScreen(key: ValueKey(user.uid), user: user);
      },
    );
  }
}
