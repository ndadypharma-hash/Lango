import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Écran 1 : bienvenue et choix de la langue.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lango', style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800, color: LangoColors.indigo)),
              const SizedBox(height: 8),
              const Text('Parle dans ta langue. Le monde t\'entend dans la sienne.', style: TextStyle(fontSize: 17)),
              const SizedBox(height: 24),
              Text('Quelle est ta langue ?', style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
          Expanded(
            child: LanguageList(
              selected: session.pendingLanguage,
              onSelected: session.choosePendingLanguage,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: session.pendingLanguage == null
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneScreen())),
              child: const Text('Continuer'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Écran 2 : numéro de téléphone.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phone = TextEditingController(text: '+226');
  bool _busy = false;

  Future<void> _submit() async {
    final phone = _phone.text.replaceAll(RegExp(r'[\s.-]'), '');
    setState(() => _busy = true);
    try {
      final devCode = await context.read<Session>().requestOtp(phone);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(phone: phone, devCode: devCode)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ton numéro')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Nous allons t\'envoyer un code par SMS pour vérifier ton numéro.'),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            decoration: const InputDecoration(labelText: 'Numéro avec indicatif pays', hintText: '+226 70 00 00 00'),
            onSubmitted: (_) => _submit(),
          ),
          const Spacer(),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Envoi…' : 'Recevoir le code')),
        ]),
      ),
    );
  }
}

/// Écran 3 : code reçu par SMS.
class OtpScreen extends StatefulWidget {
  final String phone;
  final String? devCode;
  const OtpScreen({super.key, required this.phone, this.devCode});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Version de test : le serveur de développement renvoie le code pour éviter les SMS.
    if (widget.devCode != null) _code.text = widget.devCode!;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await context.read<Session>().verifyOtp(widget.phone, _code.text.trim());
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Code de vérification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Saisis le code à 6 chiffres envoyé au ${widget.phone}.'),
          if (widget.devCode != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Version de test : le code a été rempli automatiquement.',
                  style: TextStyle(color: LangoColors.ochre)),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 12),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submit(),
          ),
          const Spacer(),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Vérification…' : 'Valider')),
        ]),
      ),
    );
  }
}
