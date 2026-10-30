import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  /// Détail technique, affiché dans les versions de test pour le diagnostic.
  final String? detail;
  ApiException(this.status, this.message, {this.detail});
  @override
  String toString() => message;
}

/// Client HTTP du serveur Lango.
class ApiClient {
  final String baseUrl;
  String? token;
  final http.Client _http;

  ApiClient(this.baseUrl, {http.Client? client}) : _http = client ?? http.Client();

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final headers = <String, String>{
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      // 70 s : le serveur gratuit de test peut mettre une minute à se réveiller.
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 70)));
    } catch (e) {
      throw ApiException(0, 'Connexion impossible au serveur Lango. Vérifiez votre réseau et réessayez.', detail: '$e');
    }
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final msg = data is Map ? data['message'] : null;
      throw ApiException(res.statusCode, msg is List ? msg.join('\n') : (msg?.toString() ?? 'Erreur ${res.statusCode}'));
    }
    return data;
  }

  // --- Langues et connexion ---

  Future<List<Language>> languages() async =>
      (await _send('GET', '/languages') as List).map((e) => Language.fromJson(e)).toList();

  /// Renvoie le code de test en développement (null en production).
  Future<String?> requestOtp(String phone) async =>
      (await _send('POST', '/auth/otp/request', body: {'phone': phone}))['devCode'];

  Future<({String token, Me user, bool isNew})> verifyOtp(String phone, String code) async {
    final r = await _send('POST', '/auth/otp/verify', body: {'phone': phone, 'code': code});
    return (token: r['token'] as String, user: Me.fromJson(r['user']), isNew: r['isNew'] == true);
  }

  // --- Profil ---

  Future<Me> me() async => Me.fromJson(await _send('GET', '/me'));

  Future<Me> updateMe(Map<String, dynamic> changes) async => Me.fromJson(await _send('PATCH', '/me', body: changes));

  Future<List<PublicProfile>> discover({String? q, String? interest, String? purpose, String? country, String? language}) async {
    final query = <String, String>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (interest != null && interest.isNotEmpty) 'interest': interest,
      if (purpose != null) 'purpose': purpose,
      if (country != null && country.isNotEmpty) 'country': country,
      if (language != null) 'language': language,
    };
    return (await _send('GET', '/discover', query: query) as List).map((e) => PublicProfile.fromJson(e)).toList();
  }

  Future<PublicProfile> profile(String id) async => PublicProfile.fromJson(await _send('GET', '/users/$id'));

  // --- Contacts ---

  Future<List<PublicProfile>> contacts() async =>
      (await _send('GET', '/contacts') as List).map((e) => PublicProfile.fromJson(e)).toList();

  Future<void> requestContact(String userId, String intro) =>
      _send('POST', '/contacts/requests', body: {'toUserId': userId, if (intro.isNotEmpty) 'intro': intro});

  Future<List<ContactRequestItem>> incomingRequests() async =>
      (await _send('GET', '/contacts/requests') as List).map((e) => ContactRequestItem.fromJson(e)).toList();

  Future<void> answerRequest(String id, bool accept) =>
      _send('POST', '/contacts/requests/$id/${accept ? 'accept' : 'decline'}');

  Future<void> block(String userId) => _send('POST', '/contacts/block/$userId');

  // --- Messages ---

  Future<List<Conversation>> conversations() async =>
      (await _send('GET', '/conversations') as List).map((e) => Conversation.fromJson(e)).toList();

  Future<List<ChatMessage>> history(String userId) async =>
      (await _send('GET', '/conversations/$userId/messages') as List).map((e) => ChatMessage.fromJson(e)).toList();

  Future<ChatMessage> send(String userId, String text) async =>
      ChatMessage.fromJson(await _send('POST', '/conversations/$userId/messages', body: {'text': text}));

  Future<void> markRead(String userId) => _send('POST', '/conversations/$userId/read');
}
