import {
  Body,
  Controller,
  Get,
  Module,
  NotFoundException,
  Param,
  Post,
} from '@nestjs/common';
import { Role, TicketStatus } from '@prisma/client';
import { IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';

class CreateTicketDto {
  @IsString() category: string;
  @IsString() subject: string;
  @IsString() message: string;
}

class ReplyDto {
  @IsString() body: string;
}

@Controller('support')
class SupportController {
  constructor(private prisma: PrismaService) {}

  /// The society admin's own tickets, with the whole conversation on each —
  /// their own replies and support's, oldest first so it reads as a thread.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.prisma.supportTicket.findMany({
      where: { societyId: resolveSocietyId(user) },
      orderBy: { createdAt: 'desc' },
      include: {
        replies: { orderBy: { createdAt: 'asc' } },
      },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateTicketDto) {
    return this.prisma.supportTicket.create({
      data: {
        societyId: resolveSocietyId(user),
        category: dto.category,
        subject: dto.subject.trim(),
        message: dto.message.trim(),
      },
    });
  }

  /// The society admin's side of the conversation. Only on their own society's
  /// tickets, and a reply reopens a closed one — otherwise an answer would land
  /// in a ticket nobody looks at again.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post(':id/replies')
  async reply(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReplyDto,
  ) {
    const body = dto.body.trim();
    if (!body) throw new NotFoundException('Nothing to send');

    const ticket = await this.prisma.supportTicket.findFirst({
      where: { id, societyId: resolveSocietyId(user) },
      select: { id: true, status: true },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');

    const reply = await this.prisma.ticketReply.create({
      data: {
        ticketId: ticket.id,
        body,
        author: user.name,
        fromSupport: false,
      },
    });
    if (ticket.status !== TicketStatus.OPEN) {
      await this.prisma.supportTicket.update({
        where: { id: ticket.id },
        data: { status: TicketStatus.OPEN },
      });
    }
    return reply;
  }
}

@Module({ controllers: [SupportController] })
export class SupportModule {}
