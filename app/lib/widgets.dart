import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'session.dart';
import 'theme.dart';

/// Pastille "bêta" pour les langues dont la traduction est encore en amélioration.
class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: LangoColors.ochre.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('bêta', style: TextStyle(fontSize: 11, color: LangoColors.ochre, fontWeight: FontWeight.w600)),
    );
  }
}

/// Liste des 22 langues, regroupées : monde, Afrique, Burkina Faso.
class LanguageList extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;
  const LanguageList({super.key, required this.selected, required this.onSelected});

  static const _groups = {
    'monde': 'Langues du monde',
    'afrique': "Langues d'Afrique",
    'burkina': 'Burkina Faso',
  };

  @override
  Widget build(BuildContext context) {
    final langs = context.watch<Session>().languages;
    final children = <Widget>[];
    _groups.forEach((group, title) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: LangoColors.ochre)),
      ));
      for (final l in langs.where((l) => l.group == group)) {
        children.add(ListTile(
          title: Text(l.nativeName),
          subtitle: Text(l.name),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (l.beta) const BetaBadge(),
            if (l.code == selected) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check_circle)),
          ]),
          selected: l.code == selected,
          onTap: () => onSelected(l.code),
        ));
      }
    });
    return ListView(children: children);
  }
}

Future<String?> pickLanguage(BuildContext context, String? current) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.8,
      child: LanguageList(selected: current, onSelected: (c) => Navigator.pop(ctx, c)),
    ),
  );
}

class Avatar extends StatelessWidget {
  final PublicProfile person;
  final double radius;
  const Avatar(this.person, {super.key, this.radius = 22});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: LangoColors.indigo,
      foregroundColor: Colors.white,
      child: Text(person.initials, style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600)),
    );
  }
}

/// Ligne "Profession · Pays · Langue" sous un nom.
String personSubtitle(BuildContext context, PublicProfile p) {
  final session = context.read<Session>();
  return [
    if (p.profession != null && p.profession!.isNotEmpty) p.profession!,
    if (p.country != null) p.country!,
    session.languageName(p.language),
  ].join(' · ');
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
}

const purposeLabels = {
  'savoir': 'Partager des savoirs',
  'commerce': 'Commerce',
  'rencontre': 'Rencontres',
};
