import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../session.dart';
import '../widgets.dart';

/// Demandes de contact reçues : accepter ou refuser.
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});
  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  List<ContactRequestItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<Session>().api.incomingRequests();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _answer(ContactRequestItem r, bool accept) async {
    try {
      await context.read<Session>().api.answerRequest(r.id, accept);
      if (!mounted) return;
      setState(() => _items.remove(r));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accept ? 'Tu peux maintenant écrire à ${r.from.name}.' : 'Demande refusée.'),
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes reçues')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 160),
                      Center(child: Text('Aucune demande pour l\'instant.')),
                    ])
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final r = _items[i];
                        final intro = r.introTranslated ?? r.intro;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Avatar(r.from),
                                title: Text(r.from.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(personSubtitle(context, r.from)),
                              ),
                              if (intro.isNotEmpty) Text(intro),
                              const SizedBox(height: 8),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                TextButton(onPressed: () => _answer(r, false), child: const Text('Refuser')),
                                const SizedBox(width: 8),
                                FilledButton.tonal(onPressed: () => _answer(r, true), child: const Text('Accepter')),
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
