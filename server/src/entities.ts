import {
  BeforeInsert,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryColumn,
  PrimaryGeneratedColumn,
} from 'typeorm';

// Types de colonnes choisis pour fonctionner à la fois sur SQLite (dev, tests)
// et PostgreSQL (production).

export type Visibility = 'hidden' | 'verified' | 'everyone';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Numéro au format international E.164, ex. +22670000000 */
  @Index({ unique: true })
  @Column({ type: 'varchar', length: 20 })
  phone: string;

  @Column({ type: 'varchar', length: 80, default: '' })
  name: string;

  /** Langue principale (code de languages.ts) : tout est traduit vers elle. */
  @Column({ type: 'varchar', length: 8, default: 'fr' })
  language: string;

  /** Langues secondaires comprises (F-02). */
  @Column({ type: 'simple-json', default: '[]' })
  extraLanguages: string[];

  // --- Profil public, utilisé par la découverte (F-70 à F-75) ---

  @Column({ type: 'varchar', length: 80, nullable: true })
  profession: string | null;

  @Column({ type: 'simple-json', default: '[]' })
  interests: string[];

  /** Code pays ISO à 2 lettres, ex. BF, TZ, CN */
  @Column({ type: 'varchar', length: 2, nullable: true })
  country: string | null;

  /** Présentation écrite dans la langue de l'utilisateur, traduite pour chaque visiteur. */
  @Column({ type: 'text', nullable: true })
  bio: string | null;

  /** Dimensions recherchées : savoir, commerce, rencontre. */
  @Column({ type: 'simple-json', default: '[]' })
  purposes: string[];

  @Column({ type: 'varchar', length: 10, default: 'hidden' })
  visibility: Visibility;

  /** Profil vérifié (pièce d'identité ou vidéo) — validé par la modération. */
  @Column({ type: 'boolean', default: false })
  verified: boolean;

  @Column({ type: 'int', nullable: true })
  birthYear: number | null;

  /** Espace rencontres, activé volontairement, réservé aux 18 ans et plus (F-75). */
  @Column({ type: 'boolean', default: false })
  datingEnabled: boolean;

  @CreateDateColumn()
  createdAt: Date;
}

@Entity('otp_codes')
export class OtpCode {
  @PrimaryColumn({ type: 'varchar', length: 20 })
  phone: string;

  @Column({ type: 'varchar', length: 64 })
  codeHash: string;

  @Column({ type: 'bigint', transformer: { to: (v: number) => v, from: (v: string | number) => Number(v) } })
  expiresAt: number;

  @Column({ type: 'int', default: 0 })
  attempts: number;
}

export type ContactRequestStatus = 'pending' | 'accepted' | 'declined' | 'blocked';

@Entity('contact_requests')
@Index(['fromId', 'toId'], { unique: true })
export class ContactRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 36 })
  fromId: string;

  @Column({ type: 'varchar', length: 36 })
  toId: string;

  /** Message d'introduction, dans la langue de l'expéditeur. */
  @Column({ type: 'text', default: '' })
  intro: string;

  @Column({ type: 'varchar', length: 10, default: 'pending' })
  status: ContactRequestStatus;

  @CreateDateColumn()
  createdAt: Date;
}

@Entity('messages')
@Index(['senderId', 'recipientId', 'sentAt'])
export class Message {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 36 })
  senderId: string;

  @Column({ type: 'varchar', length: 36 })
  recipientId: string;

  /** Texte tel qu'écrit par l'expéditeur (toujours consultable, F-12). */
  @Column({ type: 'text' })
  originalText: string;

  @Column({ type: 'varchar', length: 8 })
  originalLang: string;

  /** Traductions par code de langue, ex. { "en": "Hello" } */
  @Column({ type: 'simple-json', default: '{}' })
  translations: Record<string, string>;

  /** Alerte de sécurité, ex. 'possible_scam' */
  @Column({ type: 'varchar', length: 30, nullable: true })
  warning: string | null;

  @Column({ type: 'boolean', default: false })
  read: boolean;

  /** Horodatage en millisecondes, strictement croissant : sert à ordonner les messages. */
  @Index()
  @Column({ type: 'bigint', transformer: { to: (v: number) => v, from: (v: string | number) => Number(v) } })
  sentAt: number;

  @BeforeInsert()
  stamp() {
    const now = Date.now();
    lastSentAt = now > lastSentAt ? now : lastSentAt + 1;
    this.sentAt = lastSentAt;
  }
}

let lastSentAt = 0;

export const ENTITIES = [User, OtpCode, ContactRequest, Message];
