# Lango

**Parle dans ta langue. Le monde t'entend dans la sienne.**

Lango est une messagerie qui traduit automatiquement chaque message, pour ouvrir l'Afrique au monde et le monde à l'Afrique : savoirs, commerce, santé, culture et rencontres, en 22 langues.

## Contenu de la version 0.1

| Dossier | Rôle |
| --- | --- |
| `server/` | Serveur Node.js (NestJS) : comptes par SMS, profils, découverte, demandes de contact, messagerie traduite en temps réel, alerte anti-arnaque |
| `app/` | Application mobile Flutter (Android d'abord) |
| `codemagic.yaml` | Compilation en ligne de l'application de test |

Fonctionnalités du cahier des charges couvertes : F-01 à F-05 (sans synchronisation du répertoire), F-10 à F-14, F-62 partiel, F-70 à F-75, et la protection des utilisateurs de la section 11.

**Pas encore dans cette version :** messages vocaux (F-20 à F-22), appels traduits (F-30 à F-36), groupes, notifications push, interface en mooré et dioula.

## Lancer le serveur

```bash
cd server
cp .env.example .env      # puis remplir les valeurs
npm install
npm test                  # 15 tests automatisés
npm run dev               # démarre sur le port 3000
```

Par défaut, le serveur utilise une base SQLite locale et un traducteur factice (`[en] Bonjour`) pour tester sans frais. Pour de vraies traductions, mettre `TRANSLATION_PROVIDER=claude` avec `ANTHROPIC_API_KEY`, ou `google` avec `GOOGLE_TRANSLATE_API_KEY`.

En production : `NODE_ENV=production`, `JWT_SECRET`, `DATABASE_URL` (PostgreSQL) et un fournisseur SMS à brancher dans `server/src/auth/auth.ts` (`SmsService`). Le `Dockerfile` fonctionne sur la plupart des hébergeurs (Render, Railway, Fly.io, un VPS…).

## Compiler l'application

**Avec un ordinateur** (Flutter installé) :

```bash
cd app
bash tool/prepare_android.sh
flutter pub get
flutter run --dart-define=API_URL=http://ADRESSE_DU_SERVEUR:3000
```

**Sans ordinateur** : pousser ce dépôt sur GitHub, le connecter à [Codemagic](https://codemagic.io), définir la variable `API_URL`, et lancer le workflow `android-test`. L'APK de test se télécharge à la fin de la compilation.

## API en bref

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| GET | `/health`, `/languages` | État du service, liste des 22 langues |
| POST | `/auth/otp/request`, `/auth/otp/verify` | Connexion par code SMS |
| GET, PATCH | `/me` | Mon profil |
| GET | `/discover?q=&interest=&purpose=&country=&language=` | Découverte de personnes |
| GET | `/users/:id` | Profil public, présentation traduite |
| GET, POST | `/contacts`, `/contacts/requests` | Contacts et demandes |
| POST | `/contacts/requests/:id/accept` · `/decline`, `/contacts/block/:userId` | Répondre, bloquer |
| GET | `/conversations`, `/conversations/:userId/messages` | Discussions, historique traduit |
| POST | `/conversations/:userId/messages`, `/conversations/:userId/read` | Envoyer, marquer comme lu |
| Socket.IO | `message:send` → `message:new`, `message:read` | Temps réel (jeton dans `auth.token`) |
