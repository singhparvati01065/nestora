import { Body, Controller, Get, Module, Post } from '@nestjs/common';
import { Role } from '@prisma/client';
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

@Controller('support')
class SupportController {
  constructor(private prisma: PrismaService) {}

  /// The society admin's own tickets.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.prisma.supportTicket.findMany({
      where: { societyId: resolveSocietyId(user) },
      orderBy: { createdAt: 'desc' },
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
}

@Module({ controllers: [SupportController] })
export class SupportModule {}
