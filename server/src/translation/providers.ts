import { getLanguage } from '../languages';

/**
 * Un moteur de traduction. Lango peut changer de fournisseur sans toucher
 * au reste du code (cahier des charges, section 8.2).
 */
export interface TranslationProvider {
  readonly name: string;
  translate(text: string, from: string, to: string): Promise<string>;
}

/** Moteur factice pour le développement et les tests : n'appelle aucun service payant. */
export class MockProvider implements TranslationProvider {
  readonly name = 'mock';
  async translate(text: string, _from: string, to: string): Promise<string> {
    return `[${to}] ${text}`;
  }
}

/** Codes de langue attendus par Google Cloud Translation quand ils diffèrent des nôtres. */
const GOOGLE_CODES: Record<string, string> = { zh: 'zh-CN' };

/** Google Cloud Translation, API v2 (clé d'API). */
export class GoogleProvider implements TranslationProvider {
  readonly name = 'google';
  constructor(private readonly apiKey: string, private readonly fetchFn: typeof fetch = fetch) {}

  async translate(text: string, from: string, to: string): Promise<string> {
    const url = `https://translation.googleapis.com/language/translate/v2?key=${encodeURIComponent(this.apiKey)}`;
    const res = await this.fetchFn(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        q: text,
        source: GOOGLE_CODES[from] ?? from,
        target: GOOGLE_CODES[to] ?? to,
        format: 'text',
      }),
    });
    if (!res.ok) {
      throw new Error(`Google Translate a répondu ${res.status}`);
    }
    const data = (await res.json()) as { data?: { translations?: { translatedText: string }[] } };
    const out = data.data?.translations?.[0]?.translatedText;
    if (!out) throw new Error('Réponse Google Translate vide');
    return out;
  }
}

/** Traduction par un modèle Claude : utile pour garder le ton et le contexte. */
export class ClaudeProvider implements TranslationProvider {
  readonly name = 'claude';
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async translate(text: string, from: string, to: string): Promise<string> {
    const fromName = getLanguage(from)?.name ?? from;
    const toName = getLanguage(to)?.name ?? to;
    const res = await this.fetchFn('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': this.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: this.model,
        max_tokens: 2048,
        system:
          `Tu es le traducteur de la messagerie Lango. Traduis le message de l'utilisateur ` +
          `du ${fromName} (code ${from}) vers le ${toName} (code ${to}). ` +
          `Garde le ton, les émojis, les noms propres et le sens exact. ` +
          `Réponds uniquement avec la traduction, sans guillemets ni commentaire.`,
        messages: [{ role: 'user', content: text }],
      }),
    });
    if (!res.ok) {
      throw new Error(`API Claude a répondu ${res.status}`);
    }
    const data = (await res.json()) as { content?: { type: string; text?: string }[] };
    const out = data.content?.find((c) => c.type === 'text')?.text?.trim();
    if (!out) throw new Error('Réponse Claude vide');
    return out;
  }
}
