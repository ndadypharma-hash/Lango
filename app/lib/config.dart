/// Adresse du serveur Lango.
///
/// Par défaut : le serveur de test hébergé sur Render.
/// Pour en utiliser un autre à la compilation :
///   flutter build apk --dart-define=API_URL=https://autre-serveur.example
const String _override = String.fromEnvironment('API_URL');
const String apiUrl = _override == '' ? 'https://lango-fdzj.onrender.com' : _override;
