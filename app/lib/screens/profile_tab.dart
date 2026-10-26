import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session.dart';
import '../theme.dart';
import 'profile_edit_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  static const _visibility = {
    'everyone': 'Visible par tout le monde',
    'verified': 'Visible par les profils vérifiés',
    'hidden': 'Invisible dans la découverte',
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final me = session.me!;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: LangoColors.indigo,
            foregroundColor: Colors.white,
            child: Text(me.name.isEmpty ? '?' : me.name[0].toUpperCase(), style: const TextStyle(fontSize: 22)),
          ),
          title: Text(me.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          subtitle: Text(me.phone),
        ),
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.translate), title: const Text('Ma langue'), subtitle: Text(session.languageName(me.language))),
        if (me.profession?.isNotEmpty == true)
          ListTile(leading: const Icon(Icons.work_outline), title: const Text('Métier'), subtitle: Text(me.profession!)),
        ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('Découverte'), subtitle: Text(_visibility[me.visibility] ?? me.visibility)),
        if (me.verified) const ListTile(leading: Icon(Icons.verified), title: Text('Profil vérifié')),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
          icon: const Icon(Icons.edit),
          label: const Text('Modifier mon profil'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: session.logout, child: const Text('Se déconnecter')),
        const SizedBox(height: 24),
        const Text('Lango 0.1 — version de test', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}
