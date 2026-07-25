import { Controller, Get, Module } from '@nestjs/common';
import { Public } from '../auth/decorators/public.decorator';
import { PrismaService } from '../prisma/prisma.service';

@Controller('app-version')
class AppVersionController {
  constructor(private prisma: PrismaService) {}

  /// The mobile app reads this on launch to decide whether to prompt / force an
  /// update. Public — no auth needed.
  @Public()
  @Get()
  async get() {
    const [cfg, settings] = await Promise.all([
      this.prisma.appConfig.upsert({
        where: { id: 'app' },
        update: {},
        create: { id: 'app' },
      }),
      this.prisma.platformSettings.findUnique({ where: { id: 'main' } }),
    ]);
    return {
      androidVersion: cfg.androidVersion,
      iosVersion: cfg.iosVersion,
      forceUpdate: cfg.forceUpdate,
      releaseNotes: cfg.releaseNotes,
      maintenanceMode: settings?.maintenanceMode ?? false,
      appName: settings?.appName ?? 'Nestora',
    };
  }
}

@Module({ controllers: [AppVersionController] })
export class AppVersionModule {}
