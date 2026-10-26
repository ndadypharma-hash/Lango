import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Injectable,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Repository } from 'typeorm';
import { AuthGuard, CurrentUser } from '../auth/auth';
import { User, Visibility } from '../entities';
import { LANGUAGE_CODES } from '../languages';
import { TranslationService } from '../translation/translation.service';

export const PURPOSES = ['savoir', 'commerce', 'rencontre'] as const;
const VISIBILITIES: Visibility[] = ['hidden', 'verified', 'everyone'];
const ADULT_AGE = 18;

export function isAdult(user: Pick<User, 'birthYear'>, now = new Date()): boolean {
  // Prudence : on considère l'âge atteint seulement l'année suivant l'anniversaire possible.
  return user.birthYear != null && now.getFullYear() - user.birthYear > ADULT_AGE;
}

// ---------- DTO ----------

export class UpdateProfileDto {
  @IsOptional() @IsString() @Length(1, 80)
  name?: string;

  @IsOptional() @IsIn(LANGUAGE_CODES, { message: 'Langue non prise en charge' })
  language?: string;

  @IsOptional() @IsArray() @ArrayMaxSize(5) @IsIn(LANGUAGE_CODES, { each: true })
  extraLanguages?: string[];

  @IsOptional() @IsString() @MaxLength(80)
  profession?: string;

  @IsOptional() @IsArray() @ArrayMaxSize(10) @IsString({ each: true }) @MaxLength(40, { each: true })
  interests?: string[];

  @IsOptional() @Matches(/^[A-Z]{2}$/, { message: 'Code pays ISO à 2 lettres attendu, ex. BF' })
  country?: string;

  @IsOptional() @IsString() @MaxLength(500)
  bio?: string;

  @IsOptional() @IsArray() @IsIn(PURPOSES as unknown as string[], { each: true })
  purposes?: string[];

  @IsOptional() @IsIn(VISIBILITIES)
  visibility?: Visibility;

  @IsOptional() @IsInt() @Min(1900) @Max(new Date().getFullYear())
  birthYear?: number;

  @IsOptional() @IsBoolean()
  datingEnabled?: boolean;
}

export class DiscoverQueryDto {
  @IsOptional() @IsString() @MaxLength(80)
  q?: string;

  @IsOptional() @IsString() @MaxLength(80)
  profession?: string;

  @IsOptional() @IsString() @MaxLength(40)
  interest?: string;

  @IsOptional() @Matches(/^[A-Z]{2}$/)
  country?: string;

  @IsOptional() @IsIn(LANGUAGE_CODES)
  language?: string;

  @IsOptional() @IsIn(PURPOSES as unknown as string[])
  purpose?: string;
}

/** Ce que les autres voient d'un profil : jamais le numéro de téléphone. */
export interface PublicProfile {
  id: string;
  name: string;
  language: string;
  extraLanguages: string[];
  profession: string | null;
  interests: string[];
  country: string | null;
  bio: string | null;
  bioTranslated: string | null;
  purposes: string[];
  verified: boolean;
}

// ---------- Service ----------

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    private readonly translation: TranslationService,
  ) {}

  async update(user: User, dto: UpdateProfileDto): Promise<User> {
    const next = { ...user, ...dto };
    if (next.datingEnabled && !isAdult(next)) {
      throw new ForbiddenException("L'espace rencontres est réservé aux personnes de plus de 18 ans");
    }
    if (dto.country) next.country = dto.country.toUpperCase();
    return this.users.save(next);
  }

  async findById(id: string): Promise<User | null> {
    return this.users.findOneBy({ id });
  }

  /** Un visiteur peut-il voir ce profil dans la découverte ? */
  canSee(viewer: User, target: User): boolean {
    if (viewer.id === target.id) return true;
    if (target.visibility === 'everyone') return true;
    if (target.visibility === 'verified') return viewer.verified;
    return false;
  }

  async toPublic(target: User, viewer: User): Promise<PublicProfile> {
    let bioTranslated: string | null = null;
    if (target.bio) {
      const r = await this.translation.translate(target.bio, target.language, viewer.language);
      bioTranslated = r.ok ? r.text : null;
    }
    return {
      id: target.id,
      name: target.name,
      language: target.language,
      extraLanguages: target.extraLanguages,
      profession: target.profession,
      interests: target.interests,
      country: target.country,
      bio: target.bio,
      bioTranslated,
      purposes: target.purposes.filter((p) => p !== 'rencontre' || (viewer.datingEnabled && isAdult(viewer))),
      verified: target.verified,
    };
  }

  /** Découverte de personnes (F-70, F-71). */
  async discover(viewer: User, query: DiscoverQueryDto, limit = 20): Promise<PublicProfile[]> {
    if (query.purpose === 'rencontre' && !(viewer.datingEnabled && isAdult(viewer))) {
      throw new ForbiddenException("Activez l'espace rencontres (18 ans et plus) pour chercher dans cette catégorie");
    }
    const qb = this.users
      .createQueryBuilder('u')
      .where('u.id != :me', { me: viewer.id })
      .andWhere(
        viewer.verified ? "u.visibility IN ('everyone', 'verified')" : "u.visibility = 'everyone'",
      );
    if (query.country) qb.andWhere('u.country = :country', { country: query.country.toUpperCase() });
    if (query.language) qb.andWhere('u.language = :lang', { lang: query.language });
    if (query.profession) qb.andWhere('LOWER(u.profession) LIKE :prof', { prof: `%${query.profession.toLowerCase()}%` });
    if (query.interest) qb.andWhere('LOWER(u.interests) LIKE :int', { int: `%${query.interest.toLowerCase()}%` });
    if (query.purpose) qb.andWhere('u.purposes LIKE :purpose', { purpose: `%"${query.purpose}"%` });
    if (query.q) {
      qb.andWhere('(LOWER(u.name) LIKE :q OR LOWER(u.profession) LIKE :q OR LOWER(u.bio) LIKE :q OR LOWER(u.interests) LIKE :q)', {
        q: `%${query.q.toLowerCase()}%`,
      });
    }
    qb.orderBy('u.verified', 'DESC').addOrderBy('u.createdAt', 'DESC').take(limit);

    let found = await qb.getMany();
    if (query.purpose === 'rencontre') {
      found = found.filter((u) => u.datingEnabled && isAdult(u));
    }
    return Promise.all(found.map((u) => this.toPublic(u, viewer)));
  }
}

// ---------- Contrôleur ----------

@Controller()
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  me(@CurrentUser() user: User) {
    return user;
  }

  @Patch('me')
  update(@CurrentUser() user: User, @Body() dto: UpdateProfileDto) {
    return this.users.update(user, dto);
  }

  @Get('discover')
  discover(@CurrentUser() user: User, @Query() query: DiscoverQueryDto) {
    if (!user.name) throw new BadRequestException('Complétez votre profil avant de découvrir des personnes');
    return this.users.discover(user, query);
  }
}
