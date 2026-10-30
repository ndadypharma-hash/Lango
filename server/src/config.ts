import { randomBytes } from 'node:crypto';

// Configuration centrale, lue depuis les variables d'environnement.
// Voir .env.example pour la liste complète.

const env = process.env;

export type TranslationProviderName = 'mock' | 'google' | 'claude';

export interface AppConfig {
  port: number;
  production: boolean;
  jwtSecret: string;
  /** URL PostgreSQL (production). Absente : SQLite local. */
  databaseUrl?: string;
  /** Fichier SQLite pour le développement, ou ':memory:' pour les tests. */
  sqlitePath: string;
  /** En développement, le code SMS est renvoyé dans la réponse pour tester sans SMS. */
  devOtp: boolean;
  translationProvider: TranslationProviderName;
  googleApiKey?: string;
  anthropicApiKey?: string;
  claudeModel: string;
  /** Nombre maximal de demandes de contact envoyées par jour et par personne. */
  dailyContactRequestLimit: number;
}

export function loadConfig(overrides: Partial<AppConfig> = {}): AppConfig {
  const production = env.NODE_ENV === 'production';
  let jwtSecret = env.JWT_SECRET ?? '';
  if (!jwtSecret) {
    if (production) throw new Error('JWT_SECRET est obligatoire en production');
    // Version de test : secret aléatoire. Les sessions seront perdues au redémarrage.
    jwtSecret = randomBytes(32).toString('hex');
    console.warn('JWT_SECRET absent : secret temporaire généré (sessions perdues au redémarrage).');
  }
  const config: AppConfig = {
    port: Number(env.PORT ?? 3000),
    production,
    jwtSecret,
    databaseUrl: env.DATABASE_URL || undefined,
    sqlitePath: env.SQLITE_PATH ?? 'lango-dev.sqlite',
    devOtp: production ? false : env.DEV_OTP !== 'false',
    translationProvider: (env.TRANSLATION_PROVIDER as TranslationProviderName) ?? 'mock',
    googleApiKey: env.GOOGLE_TRANSLATE_API_KEY || undefined,
    anthropicApiKey: env.ANTHROPIC_API_KEY || undefined,
    claudeModel: env.CLAUDE_MODEL ?? 'claude-haiku-5-5',
    dailyContactRequestLimit: Number(env.DAILY_CONTACT_REQUEST_LIMIT ?? 20),
    ...overrides,
  };
  if (config.production && config.translationProvider === 'mock') {
    throw new Error('TRANSLATION_PROVIDER=mock est interdit en production');
  }
  return config;
}

export const APP_CONFIG = Symbol('APP_CONFIG');
