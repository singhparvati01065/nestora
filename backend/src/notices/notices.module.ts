import {
  Body,
  Controller,
  Delete,
  Get,
  Module,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { IsBoolean, IsOptional, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';

class CreateNoticeDto {
  @IsString() title: string;
  @IsString() body: string;
  @IsOptional() @IsBoolean() pinned?: boolean;
}

@Controller('notices')
class NoticesController {
  constructor(private prisma: PrismaService) {}

  /// All roles in the society can read notices; pinned first, then newest.
  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.prisma.notice.findMany({
      where: { societyId: resolveSocietyId(user) },
      orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateNoticeDto) {
    return this.prisma.notice.create({
      data: {
        title: dto.title,
        body: dto.body,
        pinned: dto.pinned ?? false,
        societyId: resolveSocietyId(user),
      },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/pin')
  async togglePin(@Param('id') id: string) {
    const notice = await this.prisma.notice.findUniqueOrThrow({ where: { id } });
    return this.prisma.notice.update({
      where: { id },
      data: { pinned: !notice.pinned },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.prisma.notice.delete({ where: { id } });
  }
}

@Module({ controllers: [NoticesController] })
export class NoticesModule {}
