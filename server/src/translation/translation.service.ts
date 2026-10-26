import { Inject, Injectable, Logger } from '@nestjs/common';
import { APP_CONFIG, AppConfig } from '../config';
import { ClaudeProvider, GoogleProvider, MockProvider, TranslationProvider } from './providers';

/** Langue pivot utilisée quand la traduction directe échoue (section 9). */
const PIVOT = 'en';
const CACHE_MAX = 5000;

@Injectable()
export class TranslationService {
  private readonly logger = new Logger(TranslationService.name);
  private readonly provider: TranslationProvider;
  private readonly cache = new Map<string, string>();

  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    this.provider = TranslationService.createProvider(config);
    this.logger.log(`Moteur de traduction : ${this.provider.name}`);
  }

  static createProvider(config: AppConfig): TranslationProvider {
    switch (config.translationProvider) {
      case 'google':
        if (!config.googleApiKey) throw new Error('GOOGLE_TRANSLATE_API_KEY manquante');
        return new GoogleProvider(config.googleApiKey);
      case 'claude':
        if (!config.anthropicApiKey) throw new Error('ANTHROPIC_API_KEY manquante');
        return new ClaudeProvider(config.anthropicApiKey, config.claudeModel);
      default:
        return new MockProvider();
    }
  }

  get providerName(): string {
    return this.provider.name;
  }

  /**
   * Traduit un texte. Si la traduction directe échoue, passe par l'anglais.
   * En dernier recours, renvoie le texte original pour ne jamais bloquer un message.
   */
  async translate(text: string, from: string, to: string): Promise<{ text: string; ok: boolean }> {
    if (!text.trim() || from === to) return { text, ok: true };

    const key = `${from}>${to}:${text}`;
    const cached = this.cache.get(key);
    if (cached !== undefined) return { text: cached, ok: true };

    try {
      const out = await this.provider.translate(text, from, to);
      this.remember(key, out);
      return { text: out, ok: true };
    } catch (err) {
      this.logger.warn(`Traduction directe ${from}→${to} échouée : ${(err as Error).message}`);
    }

    if (from !== PIVOT && to !== PIVOT) {
      try {
        const pivot = await this.provider.translate(text, from, PIVOT);
        const out = await this.provider.translate(pivot, PIVOT, to);
        this.remember(key, out);
        return { text: out, ok: true };
      } catch (err) {
        this.logger.warn(`Traduction via pivot ${from}→${PIVOT}→${to} échouée : ${(err as Error).message}`);
      }
    }
    return { text, ok: false };
  }

  /** Traduit vers plusieurs langues en parallèle. */
  async translateMany(text: string, from: string, targets: string[]): Promise<Record<string, string>> {
    const unique = [...new Set(targets.filter((t) => t !== from))];
    const results = await Promise.all(unique.map((t) => this.translate(text, from, t)));
    const out: Record<string, string> = {};
    unique.forEach((t, i) => {
      if (results[i].ok) out[t] = results[i].text;
    });
    return out;
  }

  private remember(key: string, value: string) {
    if (this.cache.size >= CACHE_MAX) {
      const oldest = this.cache.keys().next().value;
      if (oldest !== undefined) this.cache.delete(oldest);
    }
    this.cache.set(key, value);
  }
}
