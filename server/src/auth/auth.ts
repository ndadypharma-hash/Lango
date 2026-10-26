import {
  BadRequestException,
  Body,
  CanActivate,
  Controller,
  createParamDecorator,
  ExecutionContext,
  HttpCode,
  Inject,
  Injectable,
  Logger,
  Post,
  HttpException,
  HttpStatus,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { IsString, Length, Matches } from 'class-validator';
import { createHash, randomInt } from 'node:crypto';
import { Repository } from 'typeorm';
import { APP_CONFIG, AppConfig } from '../config';
import { OtpCode, User } from '../entities';

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;
const E164 = /^\+[1-9]\d{7,14}$/;

const hash = (s: string) => createHash('sha256').update(s).digest('hex');

// ---------- DTO ----------

export class RequestOtpDto {
  @Matches(E164, { message: 'Numéro attendu au format international, ex. +22670000000' })
  phone: string;
}

export class VerifyOtpDto {
  @Matches(E164, { message: 'Numéro attendu au format international, ex. +22670000000' })
  phone: string;

  @IsString()
  @Length(6, 6)
  code: string;
}

// ---------- Envoi des SMS ----------

/**
 * Point de branchement du fournisseur SMS (cahier des charges, section 8.1).
 * En développement, le code est seulement écrit dans le journal.
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  async sendOtp(phone: string, code: string): Promise<void> {
    if (this.config.production) {
      // À brancher : fournisseur SMS choisi pour l'Afrique de l'Ouest.
      throw new Error('Aucun fournisseur SMS configuré');
    }
    this.logger.log(`[DEV] Code Lango pour ${phone} : ${code}`);
  }
}

// ---------- Service ----------

export interface JwtPayload {
  sub: string;
}

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(OtpCode) private readonly otps: Repository<OtpCode>,
    @InjectRepository(User) private readonly users: Repository<User>,
    private readonly jwt: JwtService,
    private readonly sms: SmsService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async requestOtp(phone: string): Promise<{ sent: true; devCode?: string }> {
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.otps.save({ phone, codeHash: hash(phone + code), expiresAt: Date.now() + OTP_TTL_MS, attempts: 0 });
    await this.sms.sendOtp(phone, code);
    return this.config.devOtp ? { sent: true, devCode: code } : { sent: true };
  }

  async verifyOtp(phone: string, code: string): Promise<{ token: string; user: User; isNew: boolean }> {
    const otp = await this.otps.findOneBy({ phone });
    if (!otp || otp.expiresAt < Date.now()) {
      throw new BadRequestException('Code expiré ou inexistant, demandez-en un nouveau');
    }
    if (otp.attempts >= OTP_MAX_ATTEMPTS) {
      throw new HttpException('Trop de tentatives, demandez un nouveau code', HttpStatus.TOO_MANY_REQUESTS);
    }
    if (otp.codeHash !== hash(phone + code)) {
      otp.attempts += 1;
      await this.otps.save(otp);
      throw new UnauthorizedException('Code incorrect');
    }
    await this.otps.delete({ phone });

    let user = await this.users.findOneBy({ phone });
    const isNew = !user;
    if (!user) {
      user = await this.users.save(this.users.create({ phone }));
    }
    const token = await this.jwt.signAsync({ sub: user.id } satisfies JwtPayload);
    return { token, user, isNew };
  }

  async userFromToken(token: string): Promise<User | null> {
    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token);
      return await this.users.findOneBy({ id: payload.sub });
    } catch {
      return null;
    }
  }
}

// ---------- Contrôleur ----------

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /** Étape 1 : l'utilisateur saisit son numéro, on envoie un code par SMS. */
  @Post('otp/request')
  @HttpCode(200)
  request(@Body() dto: RequestOtpDto) {
    return this.auth.requestOtp(dto.phone);
  }

  /** Étape 2 : l'utilisateur saisit le code ; on renvoie un jeton de connexion. */
  @Post('otp/verify')
  @HttpCode(200)
  verify(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto.phone, dto.code);
  }
}

// ---------- Garde et décorateur ----------

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const header: string | undefined = req.headers?.authorization;
    const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
    if (!token) throw new UnauthorizedException('Connexion requise');
    const user = await this.auth.userFromToken(token);
    if (!user) throw new UnauthorizedException('Session invalide');
    req.user = user;
    return true;
  }
}

/** Injecte l'utilisateur connecté dans un paramètre de route. */
export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): User => {
  return ctx.switchToHttp().getRequest().user;
});
