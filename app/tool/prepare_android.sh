#!/usr/bin/env bash
# Génère le projet Android de Lango (une seule fois, ou à chaque compilation en ligne).
# À lancer depuis le dossier app/ :  bash tool/prepare_android.sh
# Compatible Mac (Codemagic) et Linux : les fichiers sont modifiés avec perl, pas sed.
set -euo pipefail

if [ ! -d android ]; then
  flutter create --org app.lango --project-name lango --platforms=android .
  # flutter create ajoute un test d'exemple qui ne correspond pas à Lango.
  rm -f test/widget_test.dart
fi

MANIFEST=android/app/src/main/AndroidManifest.xml

# Accès Internet (indispensable pour joindre le serveur)
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
fi

# Nom affiché sous l'icône
perl -pi -e 's#android:label="lango"#android:label="Lango"#' "$MANIFEST"

# Seulement pour un serveur de test en http:// (sans https) : ALLOW_HTTP=true
if [ "${ALLOW_HTTP:-false}" = "true" ] && ! grep -q 'usesCleartextTraffic' "$MANIFEST"; then
  perl -pi -e 's#<application#<application android:usesCleartextTraffic="true"#' "$MANIFEST"
fi

echo "Projet Android prêt."
