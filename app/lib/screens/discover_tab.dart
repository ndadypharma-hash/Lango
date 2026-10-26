import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'person_screen.dart';

/// Découverte de personnes par métier, intérêt, pays ou langue (F-70, F-71).
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final _query = TextEditingController();
  String? _purpose;
  String? _language;
  List<PublicProfile> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final r = await context.read<Session>().api.discover(q: _query.text.trim(), purpose: _purpose, language: _language);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final me = session.me!;
    final purposes = ['savoir', 'commerce', if (me.datingEnabled) 'rencontre'];
    return Scaffold(
      appBar: AppBar(title: const Text('Découvrir le monde')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Métier, intérêt, nom… ex. riz, climat, tissage'),
            onSubmitted: (_) => _search(),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final p in purposes)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(purposeLabels[p]!),
                  selected: _purpose == p,
                  onSelected: (v) {
                    setState(() => _purpose = v ? p : null);
                    _search();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                avatar: const Icon(Icons.translate, size: 18),
                label: Text(_language == null ? 'Toutes les langues' : session.languageName(_language!)),
                onPressed: () async {
                  final code = await pickLanguage(context, _language);
                  setState(() => _language = code);
                  _search();
                },
              ),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty && _searched
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Personne pour ces critères pour l\'instant. Essaie un autre mot.', textAlign: TextAlign.center),
                    ))
                  : RefreshIndicator(
                      onRefresh: _search,
                      child: ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          final bio = p.bioTranslated ?? p.bio;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Avatar(p, radius: 26),
                              title: Row(children: [
                                Flexible(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                if (p.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 16)),
                              ]),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(personSubtitle(context, p)),
                                if (bio != null && bio.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ),
                              ]),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonScreen(person: p))),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
