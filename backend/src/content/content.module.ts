import { Controller, Get, Module, Param } from '@nestjs/common';
import { Public } from '../auth/decorators/public.decorator';
import { PrismaService } from '../prisma/prisma.service';

@Controller('content')
class ContentController {
  constructor(private prisma: PrismaService) {}

  /// All content pages (title + key) — for a "Help & Legal" menu.
  @Public()
  @Get()
  list() {
    return this.prisma.contentPage.findMany({
      select: { key: true, title: true },
      orderBy: { key: 'asc' },
    });
  }

  /// One content page's full body — shown in the app.
  @Public()
  @Get(':key')
  async get(@Param('key') key: string) {
    const page = await this.prisma.contentPage.findUnique({ where: { key } });
    return page ?? { key, title: '', body: '' };
  }
}

@Module({ controllers: [ContentController] })
export class ContentModule {}
