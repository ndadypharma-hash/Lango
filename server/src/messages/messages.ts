import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  HttpCode,
  Injectable,
  Logger,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import { InjectRepository } from '@nestjs/typeorm';
import { IsInt, IsISO8601, IsOptional, IsString, IsUUID, Length, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { Server, Socket } from 'socket.io';
import { LessThan, Repository } from 'typeorm';
import { AuthGuard, AuthService, CurrentUser } from '../auth/auth';
import { ContactsService } from '../contacts/contacts';
import { Message, User } from '../entities';
import { SafetyService } from '../safety/safety.service';
import { TranslationService } from '../translation/translation.service';
import { UsersService } from '../users/users';

// ---------- DTO ----------

export class SendMessageDto {
  @IsString()
  @Length(1, 4000)
  text: string;
}

export class SocketSendDto extends SendMessageDto {
  @IsUUID()
  to: string;
}

export class HistoryQueryDto {
  @IsOptional() @IsISO8601()
  before?: string;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit?: number;
}

/** Un message tel que le voit une personne donnée : dans sa langue, original consultable. */
export interface MessageView {
  id: string;
  senderId: string;
  recipientId: string;
  /** Texte à afficher, dans la langue de la personne qui lit. */
  text: string;
  originalText: string;
  originalLang: string;
  translated: boolean;
  warning: string | null;
  read: boolean;
  createdAt: Date;
}

// ---------- Diffusion temps réel ----------

/** Garde une référence au serveur Socket.IO pour pousser les événements aux salles des utilisateurs. */
@Injectable()
export class RealtimeService {
  private server?: Server;
  attach(server: Server) {
    this.server = server;
  }
  emitTo(userId: string, event: string, payload: unknown) {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }
}

// ---------- Service ----------

@Injectable()
export class MessagesService {
  constructor(
    @InjectRepository(Message) private readonly messages: Repository<Message>,
    private readonly users: UsersService,
    private readonly contacts: ContactsService,
    private readonly translation: TranslationService,
    private readonly safety: SafetyService,
    private readonly realtime: RealtimeService,
  ) {}

  async view(m: Message, viewer: User): Promise<MessageView> {
    const isSender = m.senderId === viewer.id;
    let text = m.originalText;
    let translated = false;
    if (!isSender && viewer.language !== m.originalLang) {
      let t = m.translations[viewer.language];
      if (t === undefined) {
        // La personne a changé de langue depuis : on traduit à la demande et on garde le résultat.
        const r = await this.translation.translate(m.originalText, m.originalLang, viewer.language);
        if (r.ok) {
          t = r.text;
          m.translations = { ...m.translations, [viewer.language]: t };
          await this.messages.save(m);
        }
      }
      if (t !== undefined) {
        text = t;
        translated = true;
      }
    }
    return {
      id: m.id,
      senderId: m.senderId,
      recipientId: m.recipientId,
      text,
      originalText: m.originalText,
      originalLang: m.originalLang,
      translated,
      warning: isSender ? null : m.warning,
      read: m.read,
      createdAt: new Date(m.sentAt),
    };
  }

  async send(senderId: string, recipientId: string, text: string): Promise<{ forSender: MessageView; forRecipient: MessageView }> {
    const [sender, recipient] = await Promise.all([this.users.findById(senderId), this.users.findById(recipientId)]);
    if (!sender) throw new ForbiddenException('Session invalide');
    if (!recipient) throw new NotFoundException('Destinataire introuvable');
    if (!(await this.contacts.areContacts(sender.id, recipient.id)) || (await this.contacts.isBlocked(sender.id, recipient.id))) {
      throw new ForbiddenException("Cette personne doit d'abord accepter votre demande de contact");
    }

    const clean = text.trim();
    const translations = await this.translation.translateMany(clean, sender.language, [recipient.language]);
    const warning = this.safety.check(clean, ...Object.values(translations));

    const saved = await this.messages.save(
      this.messages.create({
        senderId: sender.id,
        recipientId: recipient.id,
        originalText: clean,
        originalLang: sender.language,
        translations,
        warning,
      }),
    );
    const forSender = await this.view(saved, sender);
    const forRecipient = await this.view(saved, recipient);
    this.realtime.emitTo(sender.id, 'message:new', forSender);
    this.realtime.emitTo(recipient.id, 'message:new', forRecipient);
    return { forSender, forRecipient };
  }

  async history(me: User, otherId: string, query: HistoryQueryDto): Promise<MessageView[]> {
    const limit = query.limit ?? 50;
    const before = query.before ? new Date(query.before).getTime() : undefined;
    const where = [
      { senderId: me.id, recipientId: otherId, ...(before ? { sentAt: LessThan(before) } : {}) },
      { senderId: otherId, recipientId: me.id, ...(before ? { sentAt: LessThan(before) } : {}) },
    ];
    const list = await this.messages.find({ where, order: { sentAt: 'DESC' }, take: limit });
    const views = await Promise.all(list.map((m) => this.view(m, me)));
    return views.reverse(); // du plus ancien au plus récent
  }

  async markRead(me: User, otherId: string): Promise<number> {
    const result = await this.messages.update({ senderId: otherId, recipientId: me.id, read: false }, { read: true });
    const count = result.affected ?? 0;
    if (count) this.realtime.emitTo(otherId, 'message:read', { by: me.id });
    return count;
  }

  /** Liste des conversations, la plus récente en premier, avec le nombre de messages non lus. */
  async conversations(me: User) {
    const recent = await this.messages.find({
      where: [{ senderId: me.id }, { recipientId: me.id }],
      order: { sentAt: 'DESC' },
      take: 1000,
    });
    const byOther = new Map<string, { last: Message; unread: number }>();
    for (const m of recent) {
      const other = m.senderId === me.id ? m.recipientId : m.senderId;
      const entry = byOther.get(other) ?? { last: m, unread: 0 };
      if (m.recipientId === me.id && !m.read) entry.unread += 1;
      byOther.set(other, entry);
    }
    const out = [];
    for (const [otherId, { last, unread }] of byOther) {
      const other = await this.users.findById(otherId);
      if (!other) continue;
      out.push({ with: await this.users.toPublic(other, me), lastMessage: await this.view(last, me), unread });
    }
    return out;
  }
}

// ---------- REST ----------

@Controller('conversations')
@UseGuards(AuthGuard)
export class MessagesController {
  constructor(private readonly messages: MessagesService) {}

  @Get()
  list(@CurrentUser() me: User) {
    return this.messages.conversations(me);
  }

  @Get(':userId/messages')
  history(@CurrentUser() me: User, @Param('userId', ParseUUIDPipe) userId: string, @Query() query: HistoryQueryDto) {
    return this.messages.history(me, userId, query);
  }

  /** Envoi par HTTP (secours si la connexion temps réel est coupée). */
  @Post(':userId/messages')
  async send(@CurrentUser() me: User, @Param('userId', ParseUUIDPipe) userId: string, @Body() dto: SendMessageDto) {
    return (await this.messages.send(me.id, userId, dto.text)).forSender;
  }

  @Post(':userId/read')
  @HttpCode(200)
  async read(@CurrentUser() me: User, @Param('userId', ParseUUIDPipe) userId: string) {
    return { updated: await this.messages.markRead(me, userId) };
  }
}

// ---------- Temps réel (Socket.IO) ----------

@WebSocketGateway({ cors: { origin: '*' } })
export class MessagesGateway implements OnGatewayInit, OnGatewayConnection {
  private readonly logger = new Logger(MessagesGateway.name);

  constructor(
    private readonly auth: AuthService,
    private readonly messages: MessagesService,
    private readonly realtime: RealtimeService,
  ) {}

  afterInit(server: Server) {
    this.realtime.attach(server);
  }

  async handleConnection(client: Socket) {
    const token: string | undefined = client.handshake.auth?.token;
    const user = token ? await this.auth.userFromToken(token) : null;
    if (!user) {
      client.emit('error', { message: 'Session invalide' });
      client.disconnect(true);
      return;
    }
    client.data.userId = user.id;
    await client.join(`user:${user.id}`);
    client.emit('ready', { userId: user.id });
  }

  @SubscribeMessage('message:send')
  async onSend(@ConnectedSocket() client: Socket, @MessageBody() body: SocketSendDto) {
    const userId: string | undefined = client.data.userId;
    if (!userId) return { ok: false, error: 'Session invalide' };
    const text = typeof body?.text === 'string' ? body.text : '';
    const to = typeof body?.to === 'string' ? body.to : '';
    if (!text.trim() || text.length > 4000 || !to) return { ok: false, error: 'Message invalide' };
    try {
      const { forSender } = await this.messages.send(userId, to, text);
      return { ok: true, message: forSender };
    } catch (err) {
      this.logger.debug(`Envoi refusé : ${(err as Error).message}`);
      return { ok: false, error: (err as Error).message };
    }
  }
}
