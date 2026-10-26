import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Conversation avec une personne : chaque message s'affiche dans ma langue,
/// avec l'original consultable d'un simple appui.
class ChatScreen extends StatefulWidget {
  final PublicProfile person;
  const ChatScreen({super.key, required this.person});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _showOriginal = {};
  bool _loading = true;
  bool _sending = false;
  StreamSubscription<ChatMessage>? _sub;

  Session get _session => context.read<Session>();
  String get _myId => _session.me!.id;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = _session.realtime?.messages.listen((m) {
      if (m.otherId(_myId) != widget.person.id) return;
      _add(m);
      if (m.senderId == widget.person.id) _session.api.markRead(widget.person.id);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _session.api.history(widget.person.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
      });
      _session.api.markRead(widget.person.id);
      _toBottom();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _add(ChatMessage m) {
    if (_messages.any((x) => x.id == m.id)) return;
    setState(() => _messages.add(m));
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      // Temps réel d'abord ; en cas d'échec de connexion, envoi par HTTP.
      final sent = await _session.realtime?.send(widget.person.id, text) ?? await _session.api.send(widget.person.id, text);
      _input.clear();
      _add(sent);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _block() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bloquer ${widget.person.name} ?'),
        content: const Text('Cette personne ne pourra plus t\'écrire ni voir ton profil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bloquer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _session.api.block(widget.person.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final theirLang = session.languageByCode(widget.person.language);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Avatar(widget.person, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.person.name, overflow: TextOverflow.ellipsis),
              Text(
                '${session.languageName(session.me!.language)} ⇄ ${theirLang?.name ?? widget.person.language}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'block' ? _block() : null,
            itemBuilder: (_) => const [PopupMenuItem(value: 'block', child: Text('Bloquer'))],
          ),
        ],
      ),
      body: Column(children: [
        if (theirLang?.beta == true)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: LangoColors.ochre.withValues(alpha: 0.12),
            child: Text('Le ${theirLang!.name} est en bêta : la traduction peut contenir des erreurs.',
                style: const TextStyle(fontSize: 13)),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _bubble(_messages[i]),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Écris dans ta langue…'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.senderId == _myId;
    final scheme = Theme.of(context).colorScheme;
    final showOriginal = _showOriginal.contains(m.id);
    final time = TimeOfDay.fromDateTime(m.createdAt).format(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine ? LangoColors.indigo : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (m.warning == 'possible_scam')
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: LangoColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  '⚠️ Attention : ce message ressemble à une arnaque. N\'envoie jamais d\'argent ni de code à une personne que tu ne connais pas.',
                  style: TextStyle(color: LangoColors.warning, fontSize: 13),
                ),
              ),
            Text(m.text, style: TextStyle(color: mine ? Colors.white : scheme.onSurface, fontSize: 16)),
            if (m.translated && showOriginal)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Original (${context.read<Session>().languageName(m.originalLang)}) : ${m.originalText}',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (m.translated)
                GestureDetector(
                  onTap: () => setState(() => showOriginal ? _showOriginal.remove(m.id) : _showOriginal.add(m.id)),
                  child: Text(
                    showOriginal ? 'Masquer l\'original' : 'Traduit · voir l\'original',
                    style: const TextStyle(fontSize: 12, color: LangoColors.ochre, fontWeight: FontWeight.w600),
                  ),
                ),
              if (m.translated) const SizedBox(width: 8),
              Text(time, style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : scheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
    );
  }
}
