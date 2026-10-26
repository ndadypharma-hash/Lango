// Modèles de données échangés avec le serveur Lango.

List<String> _strings(dynamic v) => (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];

class Language {
  final String code;
  final String name;
  final String nativeName;
  final bool beta;
  final String group;

  Language({required this.code, required this.name, required this.nativeName, required this.beta, required this.group});

  factory Language.fromJson(Map<String, dynamic> j) => Language(
        code: j['code'],
        name: j['name'],
        nativeName: j['nativeName'],
        beta: j['tier'] == 'beta',
        group: j['group'],
      );
}

class Me {
  final String id;
  final String phone;
  final String name;
  final String language;
  final String? profession;
  final List<String> interests;
  final String? country;
  final String? bio;
  final List<String> purposes;
  final String visibility;
  final bool verified;
  final int? birthYear;
  final bool datingEnabled;

  Me({
    required this.id,
    required this.phone,
    required this.name,
    required this.language,
    this.profession,
    required this.interests,
    this.country,
    this.bio,
    required this.purposes,
    required this.visibility,
    required this.verified,
    this.birthYear,
    required this.datingEnabled,
  });

  bool get profileComplete => name.trim().isNotEmpty;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'],
        phone: j['phone'],
        name: j['name'] ?? '',
        language: j['language'] ?? 'fr',
        profession: j['profession'],
        interests: _strings(j['interests']),
        country: j['country'],
        bio: j['bio'],
        purposes: _strings(j['purposes']),
        visibility: j['visibility'] ?? 'hidden',
        verified: j['verified'] == true,
        birthYear: j['birthYear'],
        datingEnabled: j['datingEnabled'] == true,
      );
}

class PublicProfile {
  final String id;
  final String name;
  final String language;
  final String? profession;
  final List<String> interests;
  final String? country;
  final String? bio;
  final String? bioTranslated;
  final List<String> purposes;
  final bool verified;

  PublicProfile({
    required this.id,
    required this.name,
    required this.language,
    this.profession,
    required this.interests,
    this.country,
    this.bio,
    this.bioTranslated,
    required this.purposes,
    required this.verified,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        id: j['id'],
        name: j['name'] ?? '',
        language: j['language'] ?? '',
        profession: j['profession'],
        interests: _strings(j['interests']),
        country: j['country'],
        bio: j['bio'],
        bioTranslated: j['bioTranslated'],
        purposes: _strings(j['purposes']),
        verified: j['verified'] == true,
      );

  String get initials => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class ChatMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final String originalText;
  final String originalLang;
  final bool translated;
  final String? warning;
  final bool read;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.originalText,
    required this.originalLang,
    required this.translated,
    this.warning,
    required this.read,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        senderId: j['senderId'],
        recipientId: j['recipientId'],
        text: j['text'],
        originalText: j['originalText'],
        originalLang: j['originalLang'],
        translated: j['translated'] == true,
        warning: j['warning'],
        read: j['read'] == true,
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );

  /// L'autre personne de la conversation, vue depuis [myId].
  String otherId(String myId) => senderId == myId ? recipientId : senderId;
}

class Conversation {
  final PublicProfile withUser;
  final ChatMessage lastMessage;
  final int unread;

  Conversation({required this.withUser, required this.lastMessage, required this.unread});

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        withUser: PublicProfile.fromJson(j['with']),
        lastMessage: ChatMessage.fromJson(j['lastMessage']),
        unread: j['unread'] ?? 0,
      );
}

class ContactRequestItem {
  final String id;
  final String intro;
  final String? introTranslated;
  final PublicProfile from;

  ContactRequestItem({required this.id, required this.intro, this.introTranslated, required this.from});

  factory ContactRequestItem.fromJson(Map<String, dynamic> j) => ContactRequestItem(
        id: j['id'],
        intro: j['intro'] ?? '',
        introTranslated: j['introTranslated'],
        from: PublicProfile.fromJson(j['from']),
      );
}
