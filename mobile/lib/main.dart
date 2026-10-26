import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'state/app_state.dart';
import 'theme/trago_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  state.initializeSession();
  runApp(ChangeNotifierProvider.value(value: state, child: const TragoApp()));
}

class TragoApp extends StatelessWidget {
  const TragoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trago',
      theme: TragoTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.authInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.isAuthenticated) return const MainShell();
    return const AuthScreen();
  }
}
