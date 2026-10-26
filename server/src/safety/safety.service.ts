import { Injectable } from '@nestjs/common';

/**
 * Détection simple des arnaques courantes (cahier des charges, section 11).
 * Première version à base de motifs ; à remplacer plus tard par un modèle
 * de classification multilingue.
 */
const SCAM_PATTERNS: RegExp[] = [
  /western\s*union/i,
  /money\s*gram/i,
  /gift\s*cards?|cartes?\s*cadeaux?/i,
  /\b(bitcoin|btc|usdt|crypto)\b/i,
  /send\s+(me\s+)?money|envoie[rz]?[\s-]+(moi\s+)?(de\s+l['’\s]?\s*)?argent/i,
  /customs\s+fees?|frais\s+de\s+douane/i,
  /(double|tripler?)\s+(your|ton|votre)\s+(money|argent|investissement|investment)/i,
  /verification\s+code|code\s+de\s+v[ée]rification|mot\s+de\s+passe|password/i,
  /orange\s*money.*(urgent|vite|maintenant)|(urgent|vite).*orange\s*money/i,
];

@Injectable()
export class SafetyService {
  /** Renvoie 'possible_scam' si l'un des textes contient un motif d'arnaque connu. */
  check(...texts: (string | undefined)[]): 'possible_scam' | null {
    for (const t of texts) {
      if (t && SCAM_PATTERNS.some((p) => p.test(t))) return 'possible_scam';
    }
    return null;
  }
}
