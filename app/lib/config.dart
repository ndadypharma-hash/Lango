/// Adresse du serveur Lango.
///
/// Se règle à la compilation :
///   flutter run --dart-define=API_URL=https://api.mon-domaine.com
/// Par défaut : le serveur de développement vu depuis l'émulateur Android.
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');
