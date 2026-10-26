import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';
import 'realtime.dart';

/// État global de l'application : session, profil, langues, connexion temps réel.
class Session extends ChangeNotifier {
  final ApiClient api = ApiClient(apiUrl);
  Realtime? realtime;
  Me? me;
  List<Language> languages = [];
  bool ready = false;
  String? startupError;

  /// Langue choisie sur l'écran d'accueil, avant la connexion.
  String? pendingLanguage;

  static const _tokenKey = 'lango.token';
  static const _langKey = 'lango.pendingLanguage';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    pendingLanguage = prefs.getString(_langKey);
    try {
      languages = await api.languages();
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        api.token = token;
        try {
          me = await api.me();
          _connect();
        } on ApiException catch (e) {
          if (e.status == 401) await prefs.remove(_tokenKey);
          api.token = null;
        }
      }
      startupError = null;
    } on ApiException catch (e) {
      startupError = e.message;
    }
    ready = true;
    notifyListeners();
  }

  Language? languageByCode(String code) {
    for (final l in languages) {
      if (l.code == code) return l;
    }
    return null;
  }

  String languageName(String code) => languageByCode(code)?.name ?? code;

  Future<void> choosePendingLanguage(String code) async {
    pendingLanguage = code;
    (await SharedPreferences.getInstance()).setString(_langKey, code);
    notifyListeners();
  }

  Future<String?> requestOtp(String phone) => api.requestOtp(phone);

  /// Vérifie le code SMS et ouvre la session. Applique la langue choisie à l'accueil.
  Future<void> verifyOtp(String phone, String code) async {
    final r = await api.verifyOtp(phone, code);
    api.token = r.token;
    (await SharedPreferences.getInstance()).setString(_tokenKey, r.token);
    me = r.user;
    if (pendingLanguage != null && (r.isNew || me!.language != pendingLanguage) && !me!.profileComplete) {
      me = await api.updateMe({'language': pendingLanguage});
    }
    _connect();
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> changes) async {
    me = await api.updateMe(changes);
    notifyListeners();
  }

  void _connect() {
    realtime?.dispose();
    realtime = Realtime(apiUrl, api.token!);
  }

  Future<void> logout() async {
    realtime?.dispose();
    realtime = null;
    me = null;
    api.token = null;
    (await SharedPreferences.getInstance()).remove(_tokenKey);
    notifyListeners();
  }
}
