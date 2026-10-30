import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding.dart';
import 'screens/profile_edit_screen.dart';
import 'session.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => Session()..init(),
      child: const LangoApp(),
    ),
  );
}

class LangoApp extends StatelessWidget {
  const LangoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lango',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const _Root(),
    );
  }
}

/// Choisit l'écran de départ selon l'état de la session.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.ready) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Connexion à Lango…\nLa première ouverture peut prendre jusqu\'à une minute.', textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }
    if (session.startupError != null && session.languages.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off, size: 48),
              const SizedBox(height: 16),
              Text(session.startupError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: session.init, child: const Text('Réessayer')),
              const SizedBox(height: 24),
              // Diagnostic pour la version de test
              Text('Serveur : $apiUrl', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              if (session.startupDetail != null)
                Text(session.startupDetail!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      );
    }
    final me = session.me;
    if (me == null) return const WelcomeScreen();
    if (!me.profileComplete) return const ProfileEditScreen(firstTime: true);
    return const HomeScreen();
  }
}
