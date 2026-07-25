import { join } from 'path';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { UPLOADS_DIR, UPLOADS_ROUTE } from './uploads/uploads.constants';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.enableCors();
  app.setGlobalPrefix('api');
  // Uploaded avatars/logos are served straight off disk. Static assets ignore
  // the global prefix, so these live at /uploads/x.jpg, not /api/uploads/x.jpg.
  app.useStaticAssets(UPLOADS_DIR, { prefix: UPLOADS_ROUTE });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  const port = app.get(ConfigService).get<number>('PORT') ?? 3000;
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Nestora API running on http://localhost:${port}/api`);
  // eslint-disable-next-line no-console
  console.log(`Uploads served from ${join(UPLOADS_DIR)}`);
}
bootstrap();
