import 'package:flutter_test/flutter_test.dart';
import 'package:lango/models.dart';

void main() {
  test('lit un message traduit envoyé par le serveur', () {
    final m = ChatMessage.fromJson({
      'id': 'm1',
      'senderId': 'a',
      'recipientId': 'b',
      'text': 'Hello',
      'originalText': 'Bonjour',
      'originalLang': 'fr',
      'translated': true,
      'warning': null,
      'read': false,
      'createdAt': '2026-10-26T17:00:00.000Z',
    });
    expect(m.text, 'Hello');
    expect(m.originalText, 'Bonjour');
    expect(m.otherId('a'), 'b');
    expect(m.otherId('b'), 'a');
  });

  test('marque les langues africaines en bêta', () {
    final l = Language.fromJson({'code': 'mos', 'name': 'Mooré', 'nativeName': 'Mòoré', 'tier': 'beta', 'group': 'burkina'});
    expect(l.beta, isTrue);
  });
}
