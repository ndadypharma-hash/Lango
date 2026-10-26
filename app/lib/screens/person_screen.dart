import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../session.dart';
import '../widgets.dart';

/// Profil d'une personne découverte, avec la demande de contact (F-72).
class PersonScreen extends StatefulWidget {
  final PublicProfile person;
  const PersonScreen({super.key, required this.person});
  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  final _intro = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await context.read<Session>().api.requestContact(widget.person.id, _intro.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final session = context.watch<Session>();
    final lang = session.languageByCode(p.language);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Center(child: Avatar(p, radius: 44)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(p.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (p.verified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified)),
        ]),
        const SizedBox(height: 4),
        Text(personSubtitle(context, p), textAlign: TextAlign.center),
        if (lang?.beta == true)
          const Padding(padding: EdgeInsets.only(top: 6), child: Center(child: BetaBadge())),
        const SizedBox(height: 20),
        if ((p.bioTranslated ?? p.bio)?.isNotEmpty == true) ...[
          Text(p.bioTranslated ?? p.bio!, style: const TextStyle(fontSize: 16)),
          if (p.bioTranslated != null && p.bio != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Original : ${p.bio}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
            ),
          const SizedBox(height: 16),
        ],
        if (p.interests.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: [for (final i in p.interests) Chip(label: Text(i))]),
        if (p.purposes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Cherche : ${p.purposes.map((x) => purposeLabels[x] ?? x).join(', ')}'),
        ],
        const Divider(height: 40),
        if (_sent)
          const Text('Demande envoyée. Tu pourras écrire dès qu\'elle sera acceptée.', textAlign: TextAlign.center)
        else ...[
          Text('Présente-toi dans ta langue, ${p.name} le lira dans la sienne.'),
          const SizedBox(height: 8),
          TextField(
            controller: _intro,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'Bonjour, je suis… et j\'aimerais échanger sur…'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _request,
            icon: const Icon(Icons.person_add_alt),
            label: Text(_busy ? 'Envoi…' : 'Demander à échanger'),
          ),
        ],
      ]),
    );
  }
}
