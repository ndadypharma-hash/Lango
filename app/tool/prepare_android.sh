#!/usr/bin/env bash
# Génère le projet Android de Lango (une seule fois, ou à chaque compilation en ligne).
# À lancer depuis le dossier app/ :  bash tool/prepare_android.sh
set -euo pipefail

if [ ! -d android ]; then
  flutter create --org app.lango --project-name lango --platforms=android .
fi

MANIFEST=android/app/src/main/AndroidManifest.xml

# Accès Internet (indispensable pour joindre le serveur)
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
fi

# Nom affiché sous l'icône
sed -i 's#android:label="lango"#android:label="Lango"#' "$MANIFEST"

# Versions de test seulement : autorise un serveur en http:// (sans https)
if [ "${ALLOW_HTTP:-true}" = "true" ] && ! grep -q 'usesCleartextTraffic' "$MANIFEST"; then
  sed -i 's#<application#<application android:usesCleartextTraffic="true"#' "$MANIFEST"
fi

echo "Projet Android prêt."
