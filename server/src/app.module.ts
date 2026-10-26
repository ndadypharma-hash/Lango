import { Controller, DynamicModule, Get, Module, ValidationPipe } from '@nestjs/common';
import { APP_PIPE } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthController, AuthGuard, AuthService, SmsService } from './auth/auth';
import { APP_CONFIG, AppConfig } from './config';
import { ContactsController, ContactsService, ProfilesController } from './contacts/contacts';
import { ENTITIES } from './entities';
import { LANGUAGES } from './languages';
import { MessagesController, MessagesGateway, MessagesService, RealtimeService } from './messages/messages';
import { SafetyService } from './safety/safety.service';
import { TranslationService } from './translation/translation.service';
import { UsersController, UsersService } from './users/users';

@Controller()
class MetaController {
  constructor(private readonly translation: TranslationService) {}

  @Get('health')
  health() {
    return { status: 'ok', app: 'lango', version: '0.1.0', translation: this.translation.providerName };
  }

  /** Liste des 22 langues, pour l'écran de choix de langue de l'application. */
  @Get('languages')
  languages() {
    return LANGUAGES;
  }
}

@Module({})
export class AppModule {
  static forRoot(config: AppConfig): DynamicModule {
    const database = config.databaseUrl
      ? TypeOrmModule.forRoot({
          type: 'postgres',
          url: config.databaseUrl,
          entities: ENTITIES,
          // Pour la bêta seulement : en production stable, passer à des migrations versionnées.
          synchronize: true,
        })
      : TypeOrmModule.forRoot({
          type: 'better-sqlite3',
          database: config.sqlitePath,
          entities: ENTITIES,
          synchronize: true,
        });

    return {
      module: AppModule,
      imports: [
        database,
        TypeOrmModule.forFeature(ENTITIES),
        JwtModule.register({ secret: config.jwtSecret, signOptions: { expiresIn: '90d' } }),
      ],
      controllers: [MetaController, AuthController, UsersController, ProfilesController, ContactsController, MessagesController],
      providers: [
        { provide: APP_CONFIG, useValue: config },
        { provide: APP_PIPE, useValue: new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }) },
        AuthService,
        AuthGuard,
        SmsService,
        UsersService,
        ContactsService,
        MessagesService,
        MessagesGateway,
        RealtimeService,
        TranslationService,
        SafetyService,
      ],
    };
  }
}
