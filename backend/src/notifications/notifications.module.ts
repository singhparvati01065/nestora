import { Controller, Get, Module, Patch } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';

@Controller('notifications')
class NotificationsController {
  constructor(private prisma: PrismaService) {}

  /// The society's notifications (payments etc.), newest first, with the
  /// unread count so a badge can be shown.
  @Get()
  async list(@CurrentUser() user: AuthUser) {
    const societyId = resolveSocietyId(user);
    const notifications = await this.prisma.appNotification.findMany({
      where: { societyId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    const unread = notifications.filter((n) => !n.read).length;
    return { notifications, unread };
  }

  /// Marks every notification in the society read (called when the screen opens).
  @Patch('read')
  async markAllRead(@CurrentUser() user: AuthUser) {
    await this.prisma.appNotification.updateMany({
      where: { societyId: resolveSocietyId(user), read: false },
      data: { read: true },
    });
    return { ok: true };
  }
}

@Module({ controllers: [NotificationsController] })
export class NotificationsModule {}
