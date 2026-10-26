import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'chat_screen.dart';

class ConversationsTab extends StatefulWidget {
  const ConversationsTab({super.key});
  @override
  State<ConversationsTab> createState() => _ConversationsTabState();
}

class _ConversationsTabState extends State<ConversationsTab> {
  List<Conversation> _items = [];
  List<PublicProfile> _contacts = [];
  bool _loading = true;
  StreamSubscription<ChatMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context.read<Session>().realtime?.messages.listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<Session>().api;
    try {
      final results = await Future.wait([api.conversations(), api.contacts()]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Conversation>;
        _contacts = results[1] as List<PublicProfile>;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(PublicProfile p) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(person: p)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<Session>().me!.id;
    final withoutChat = _contacts.where((c) => !_items.any((i) => i.withUser.id == c.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Discussions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty && withoutChat.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucune discussion pour l\'instant.\nVa dans « Découvrir » pour trouver des personnes qui partagent tes centres d\'intérêt.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ])
                  : ListView(children: [
                      for (final c in _items)
                        ListTile(
                          leading: Avatar(c.withUser),
                          title: Text(c.withUser.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${c.lastMessage.senderId == myId ? 'Toi : ' : ''}${c.lastMessage.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: c.unread > 0
                              ? CircleAvatar(radius: 11, child: Text('${c.unread}', style: const TextStyle(fontSize: 12)))
                              : null,
                          onTap: () => _open(c.withUser),
                        ),
                      if (withoutChat.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text('Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      for (final p in withoutChat)
                        ListTile(
                          leading: Avatar(p),
                          title: Text(p.name),
                          subtitle: Text(personSubtitle(context, p)),
                          onTap: () => _open(p),
                        ),
                    ]),
            ),
    );
  }
}
