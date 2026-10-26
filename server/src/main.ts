import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { AppConfig, loadConfig } from './config';

export async function createApp(config: AppConfig) {
  const app = await NestFactory.create(AppModule.forRoot(config), {
    logger: config.production ? ['log', 'warn', 'error'] : ['log', 'warn', 'error', 'debug'],
  });
  app.enableCors();
  app.enableShutdownHooks();
  return app;
}

async function bootstrap() {
  const config = loadConfig();
  const app = await createApp(config);
  await app.listen(config.port, '0.0.0.0');
  new Logger('Lango').log(`Serveur Lango prêt sur le port ${config.port}`);
}

if (require.main === module) {
  bootstrap().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
