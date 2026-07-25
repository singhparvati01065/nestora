import {
  Body,
  Controller,
  Get,
  Module,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';

class CreateDeliveryDto {
  @IsString() courier: string;
  @IsString() flatId: string;
}

@Controller('deliveries')
class DeliveriesController {
  constructor(private prisma: PrismaService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.prisma.delivery.findMany({
      where: { societyId: resolveSocietyId(user) },
      include: { flat: { select: { number: true } } },
      orderBy: { inAt: 'desc' },
    });
  }

  @Roles(Role.SECURITY_GUARD, Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateDeliveryDto) {
    return this.prisma.delivery.create({
      data: {
        societyId: resolveSocietyId(user),
        courier: dto.courier,
        flatId: dto.flatId,
      },
    });
  }

  @Roles(Role.SECURITY_GUARD, Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/collected')
  async toggleCollected(@Param('id') id: string) {
    const d = await this.prisma.delivery.findUniqueOrThrow({ where: { id } });
    return this.prisma.delivery.update({
      where: { id },
      data: { collected: !d.collected },
    });
  }
}

@Module({ controllers: [DeliveriesController] })
export class DeliveriesModule {}
