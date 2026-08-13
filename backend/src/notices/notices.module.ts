import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Module,
  NotFoundException,
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

  /// The society's own notice board — all roles can read it; pinned first,
  /// then newest. Nestora's announcements are deliberately NOT here: they are
  /// platform matters for the admin, not society business every resident
  /// should scroll past. See [announcements].
  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.prisma.notice.findMany({
      where: { societyId: resolveSocietyId(user), fromPlatform: false },
      orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
    });
  }

  /// Announcements Nestora broadcast to this society, newest first. Read-only
  /// and admin-facing — the society cannot pin, edit or remove them.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Get('announcements')
  announcements(@CurrentUser() user: AuthUser) {
    return this.prisma.notice.findMany({
      where: { societyId: resolveSocietyId(user), fromPlatform: true },
      orderBy: { createdAt: 'desc' },
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

  /// The notice, if this user may change it: only within their own society,
  /// and never a platform announcement unless they are the super admin who
  /// sent it. Anything else reads as missing.
  private async ownNotice(user: AuthUser, id: string) {
    const where =
      user.role === Role.SUPER_ADMIN
        ? { id }
        : { id, societyId: resolveSocietyId(user) };
    const notice = await this.prisma.notice.findFirst({ where });
    if (!notice) throw new NotFoundException('Notice not found');
    if (notice.fromPlatform && user.role !== Role.SUPER_ADMIN) {
      throw new ForbiddenException(
        'This announcement is from Nestora and cannot be changed here.',
      );
    }
    return notice;
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/pin')
  async togglePin(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const notice = await this.ownNotice(user, id);
    return this.prisma.notice.update({
      where: { id },
      data: { pinned: !notice.pinned },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Delete(':id')
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.ownNotice(user, id);
    return this.prisma.notice.delete({ where: { id } });
  }
}

@Module({ controllers: [NoticesController] })
export class NoticesModule {}
