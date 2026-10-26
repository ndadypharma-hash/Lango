import 'package:flutter/material.dart';

import 'conversations_tab.dart';
import 'discover_tab.dart';
import 'profile_tab.dart';
import 'requests_tab.dart';

/// Écran principal : quatre onglets.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _pages = [ConversationsTab(), DiscoverTab(), RequestsTab(), ProfileTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Discussions'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Découvrir'),
          NavigationDestination(icon: Icon(Icons.person_add_alt), label: 'Demandes'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
        ],
      ),
    );
  }
}
