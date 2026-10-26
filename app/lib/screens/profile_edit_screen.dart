import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session.dart';
import '../widgets.dart';

/// Création (première connexion) ou modification du profil.
class ProfileEditScreen extends StatefulWidget {
  final bool firstTime;
  const ProfileEditScreen({super.key, this.firstTime = false});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name, _profession, _interests, _country, _bio, _birthYear;
  late String _language;
  late String _visibility;
  late Set<String> _purposes;
  late bool _dating;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<Session>().me!;
    _name = TextEditingController(text: me.name);
    _profession = TextEditingController(text: me.profession ?? '');
    _interests = TextEditingController(text: me.interests.join(', '));
    _country = TextEditingController(text: me.country ?? '');
    _bio = TextEditingController(text: me.bio ?? '');
    _birthYear = TextEditingController(text: me.birthYear?.toString() ?? '');
    _language = me.language;
    _visibility = me.visibility;
    _purposes = me.purposes.toSet();
    _dating = me.datingEnabled;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showError(context, 'Indique ton nom ou prénom');
      return;
    }
    final country = _country.text.trim().toUpperCase();
    if (country.isNotEmpty && !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      showError(context, 'Pays : code à 2 lettres, ex. BF, TZ, CN');
      return;
    }
    final changes = <String, dynamic>{
      'name': _name.text.trim(),
      'language': _language,
      'profession': _profession.text.trim(),
      'interests': _interests.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(10).toList(),
      if (country.isNotEmpty) 'country': country,
      'bio': _bio.text.trim(),
      'visibility': _visibility,
      'purposes': _purposes.toList(),
      if (int.tryParse(_birthYear.text.trim()) != null) 'birthYear': int.parse(_birthYear.text.trim()),
      'datingEnabled': _dating,
    };
    setState(() => _busy = true);
    try {
      await context.read<Session>().updateProfile(changes);
      if (mounted && !widget.firstTime) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final lang = session.languageByCode(_language);
    return Scaffold(
      appBar: AppBar(title: Text(widget.firstTime ? 'Ton profil' : 'Modifier le profil')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.firstTime)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Présente-toi. Ta présentation sera traduite pour chaque personne qui la lit.'),
          ),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom ou prénom *')),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ma langue'),
          subtitle: Text(lang == null ? _language : '${lang.nativeName} (${lang.name})'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final code = await pickLanguage(context, _language);
            if (code != null) setState(() => _language = code);
          },
        ),
        TextField(controller: _profession, decoration: const InputDecoration(labelText: 'Métier', hintText: 'ex. Agriculteur, commerçante, médecin')),
        const SizedBox(height: 12),
        TextField(controller: _interests, decoration: const InputDecoration(labelText: "Centres d'intérêt", hintText: 'séparés par des virgules')),
        const SizedBox(height: 12),
        TextField(
          controller: _country,
          maxLength: 2,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Pays (code à 2 lettres)', hintText: 'BF, TZ, CN, JP…'),
        ),
        TextField(controller: _bio, maxLines: 4, maxLength: 500, decoration: const InputDecoration(labelText: 'Présentation')),
        const SizedBox(height: 8),
        Text('Ce que je cherche sur Lango', style: Theme.of(context).textTheme.titleSmall),
        Wrap(spacing: 8, children: [
          for (final p in ['savoir', 'commerce'])
            FilterChip(
              label: Text(purposeLabels[p]!),
              selected: _purposes.contains(p),
              onSelected: (v) => setState(() => v ? _purposes.add(p) : _purposes.remove(p)),
            ),
        ]),
        const SizedBox(height: 16),
        Text('Qui peut me trouver ?', style: Theme.of(context).textTheme.titleSmall),
        RadioGroup<String>(
          groupValue: _visibility,
          onChanged: (v) => setState(() => _visibility = v ?? _visibility),
          child: const Column(children: [
            RadioListTile<String>(value: 'everyone', title: Text('Tout le monde')),
            RadioListTile<String>(value: 'verified', title: Text('Seulement les profils vérifiés')),
            RadioListTile<String>(value: 'hidden', title: Text('Personne (seulement mes contacts)')),
          ]),
        ),
        const Divider(height: 32),
        Text('Espace rencontres', style: Theme.of(context).textTheme.titleSmall),
        const Text('Réservé aux plus de 18 ans. Tu restes libre d\'accepter ou non chaque demande.'),
        const SizedBox(height: 8),
        TextField(
          controller: _birthYear,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'Année de naissance'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activer les rencontres'),
          value: _dating,
          onChanged: (v) => setState(() {
            _dating = v;
            v ? _purposes.add('rencontre') : _purposes.remove('rencontre');
          }),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Enregistrement…' : 'Enregistrer')),
      ]),
    );
  }
}
