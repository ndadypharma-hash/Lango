import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  ForbiddenException,
  Get,
  HttpCode,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { MoreThan, Repository } from 'typeorm';
import { AuthGuard, CurrentUser } from '../auth/auth';
import { APP_CONFIG, AppConfig } from '../config';
import { ContactRequest, User } from '../entities';
import { TranslationService } from '../translation/translation.service';
import { UsersService } from '../users/users';

export class CreateContactRequestDto {
  @IsUUID()
  toUserId: string;

  @IsOptional() @IsString() @MaxLength(300)
  intro?: string;
}

@Injectable()
export class ContactsService {
  constructor(
    @InjectRepository(ContactRequest) private readonly requests: Repository<ContactRequest>,
    private readonly users: UsersService,
    private readonly translation: TranslationService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** Deux personnes peuvent-elles s'écrire ? Il faut une demande acceptée, dans un sens ou dans l'autre. */
  async areContacts(a: string, b: string): Promise<boolean> {
    const count = await this.requests.count({
      where: [
        { fromId: a, toId: b, status: 'accepted' },
        { fromId: b, toId: a, status: 'accepted' },
      ],
    });
    return count > 0;
  }

  async isBlocked(a: string, b: string): Promise<boolean> {
    const count = await this.requests.count({
      where: [
        { fromId: a, toId: b, status: 'blocked' },
        { fromId: b, toId: a, status: 'blocked' },
      ],
    });
    return count > 0;
  }

  /** F-72, F-73 : demande de contact avec introduction, limitée par jour. */
  async create(from: User, dto: CreateContactRequestDto): Promise<ContactRequest> {
    if (dto.toUserId === from.id) throw new BadRequestException('Vous ne pouvez pas vous ajouter vous-même');
    const target = await this.users.findById(dto.toUserId);
    if (!target || (!this.users.canSee(from, target) && !(await this.existsBetween(from.id, target.id)))) {
      throw new NotFoundException('Profil introuvable');
    }
    if (await this.isBlocked(from.id, target.id)) throw new ForbiddenException('Contact impossible');

    const since = new Date(Date.now() - 24 * 3600 * 1000);
    const sentToday = await this.requests.count({ where: { fromId: from.id, createdAt: MoreThan(since) } });
    if (sentToday >= this.config.dailyContactRequestLimit) {
      throw new HttpException('Limite quotidienne de demandes atteinte, réessayez demain', HttpStatus.TOO_MANY_REQUESTS);
    }

    // Si l'autre personne nous a déjà envoyé une demande, on l'accepte directement.
    const reverse = await this.requests.findOneBy({ fromId: target.id, toId: from.id });
    if (reverse?.status === 'pending') {
      reverse.status = 'accepted';
      return this.requests.save(reverse);
    }
    if (await this.requests.findOneBy({ fromId: from.id, toId: target.id })) {
      throw new ConflictException('Demande déjà envoyée');
    }
    return this.requests.save(this.requests.create({ fromId: from.id, toId: target.id, intro: dto.intro ?? '' }));
  }

  private async existsBetween(a: string, b: string): Promise<boolean> {
    return (await this.requests.count({ where: [{ fromId: a, toId: b }, { fromId: b, toId: a }] })) > 0;
  }

  /** Demandes reçues en attente, avec l'introduction traduite dans ma langue. */
  async incoming(me: User) {
    const pending = await this.requests.find({ where: { toId: me.id, status: 'pending' }, order: { createdAt: 'DESC' } });
    return Promise.all(
      pending.map(async (r) => {
        const sender = await this.users.findById(r.fromId);
        if (!sender) return null;
        const intro = r.intro ? await this.translation.translate(r.intro, sender.language, me.language) : null;
        return {
          id: r.id,
          createdAt: r.createdAt,
          intro: r.intro,
          introTranslated: intro?.ok ? intro.text : null,
          from: await this.users.toPublic(sender, me),
        };
      }),
    ).then((list) => list.filter((x) => x !== null));
  }

  async respond(me: User, requestId: string, action: 'accept' | 'decline' | 'block'): Promise<ContactRequest> {
    const req = await this.requests.findOneBy({ id: requestId, toId: me.id });
    if (!req) throw new NotFoundException('Demande introuvable');
    req.status = action === 'accept' ? 'accepted' : action === 'decline' ? 'declined' : 'blocked';
    return this.requests.save(req);
  }

  /** Bloquer quelqu'un à tout moment, même sans demande en cours. */
  async block(me: User, otherId: string): Promise<void> {
    const existing = await this.requests.find({
      where: [
        { fromId: me.id, toId: otherId },
        { fromId: otherId, toId: me.id },
      ],
    });
    if (existing.length) {
      for (const r of existing) r.status = 'blocked';
      await this.requests.save(existing);
    } else {
      await this.requests.save(this.requests.create({ fromId: me.id, toId: otherId, status: 'blocked' }));
    }
  }

  async list(me: User) {
    const accepted = await this.requests.find({
      where: [
        { fromId: me.id, status: 'accepted' },
        { toId: me.id, status: 'accepted' },
      ],
    });
    const ids = accepted.map((r) => (r.fromId === me.id ? r.toId : r.fromId));
    const people = await Promise.all(ids.map((id) => this.users.findById(id)));
    return Promise.all(people.filter((p): p is User => !!p).map((p) => this.users.toPublic(p, me)));
  }
}

@Controller('contacts')
@UseGuards(AuthGuard)
export class ContactsController {
  constructor(private readonly contacts: ContactsService) {}

  @Get()
  list(@CurrentUser() me: User) {
    return this.contacts.list(me);
  }

  @Post('requests')
  create(@CurrentUser() me: User, @Body() dto: CreateContactRequestDto) {
    return this.contacts.create(me, dto);
  }

  @Get('requests')
  incoming(@CurrentUser() me: User) {
    return this.contacts.incoming(me);
  }

  @Post('requests/:id/accept')
  @HttpCode(200)
  accept(@CurrentUser() me: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.contacts.respond(me, id, 'accept');
  }

  @Post('requests/:id/decline')
  @HttpCode(200)
  decline(@CurrentUser() me: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.contacts.respond(me, id, 'decline');
  }

  @Post('block/:userId')
  @HttpCode(204)
  async block(@CurrentUser() me: User, @Param('userId', ParseUUIDPipe) userId: string) {
    await this.contacts.block(me, userId);
  }
}

/** Profil d'une personne : visible si son profil est public pour moi, ou si nous sommes en contact. */
@Controller('users')
@UseGuards(AuthGuard)
export class ProfilesController {
  constructor(private readonly users: UsersService, private readonly contacts: ContactsService) {}

  @Get(':id')
  async profile(@CurrentUser() viewer: User, @Param('id', ParseUUIDPipe) id: string) {
    const target = await this.users.findById(id);
    if (!target) throw new NotFoundException('Profil introuvable');
    const visible = this.users.canSee(viewer, target) || (await this.contacts.areContacts(viewer.id, target.id));
    if (!visible || (await this.contacts.isBlocked(viewer.id, target.id))) {
      throw new NotFoundException('Profil introuvable');
    }
    return this.users.toPublic(target, viewer);
  }
}
