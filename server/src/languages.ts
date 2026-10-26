// Les 22 langues de Lango (cahier des charges, section 9).
// tier 'stable' : langue bien couverte par l'IA ; 'beta' : qualité encore inégale.

export interface Language {
  code: string;
  name: string; // nom en français
  nativeName: string;
  tier: 'stable' | 'beta';
  group: 'monde' | 'afrique' | 'burkina';
}

export const LANGUAGES: Language[] = [
  // 10 langues les plus parlées au monde
  { code: 'en', name: 'Anglais', nativeName: 'English', tier: 'stable', group: 'monde' },
  { code: 'zh', name: 'Chinois mandarin', nativeName: '中文', tier: 'stable', group: 'monde' },
  { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', tier: 'stable', group: 'monde' },
  { code: 'es', name: 'Espagnol', nativeName: 'Español', tier: 'stable', group: 'monde' },
  { code: 'ar', name: 'Arabe', nativeName: 'العربية', tier: 'stable', group: 'monde' },
  { code: 'fr', name: 'Français', nativeName: 'Français', tier: 'stable', group: 'monde' },
  { code: 'bn', name: 'Bengali', nativeName: 'বাংলা', tier: 'stable', group: 'monde' },
  { code: 'pt', name: 'Portugais', nativeName: 'Português', tier: 'stable', group: 'monde' },
  { code: 'ru', name: 'Russe', nativeName: 'Русский', tier: 'stable', group: 'monde' },
  { code: 'id', name: 'Indonésien', nativeName: 'Bahasa Indonesia', tier: 'stable', group: 'monde' },
  // 10 langues africaines les plus parlées
  { code: 'sw', name: 'Swahili', nativeName: 'Kiswahili', tier: 'beta', group: 'afrique' },
  { code: 'ha', name: 'Haoussa', nativeName: 'Hausa', tier: 'beta', group: 'afrique' },
  { code: 'am', name: 'Amharique', nativeName: 'አማርኛ', tier: 'beta', group: 'afrique' },
  { code: 'yo', name: 'Yoruba', nativeName: 'Yorùbá', tier: 'beta', group: 'afrique' },
  { code: 'om', name: 'Oromo', nativeName: 'Afaan Oromoo', tier: 'beta', group: 'afrique' },
  { code: 'ig', name: 'Igbo', nativeName: 'Igbo', tier: 'beta', group: 'afrique' },
  { code: 'ff', name: 'Fulfulde (peul)', nativeName: 'Fulfulde', tier: 'beta', group: 'afrique' },
  { code: 'zu', name: 'Zoulou', nativeName: 'isiZulu', tier: 'beta', group: 'afrique' },
  { code: 'so', name: 'Somali', nativeName: 'Soomaali', tier: 'beta', group: 'afrique' },
  { code: 'ln', name: 'Lingala', nativeName: 'Lingála', tier: 'beta', group: 'afrique' },
  // Langues locales du Burkina Faso
  { code: 'mos', name: 'Mooré', nativeName: 'Mòoré', tier: 'beta', group: 'burkina' },
  { code: 'dyu', name: 'Dioula', nativeName: 'Julakan', tier: 'beta', group: 'burkina' },
];

const BY_CODE = new Map(LANGUAGES.map((l) => [l.code, l]));

export const LANGUAGE_CODES = LANGUAGES.map((l) => l.code);

export function isSupportedLanguage(code: string): boolean {
  return BY_CODE.has(code);
}

export function getLanguage(code: string): Language | undefined {
  return BY_CODE.get(code);
}
