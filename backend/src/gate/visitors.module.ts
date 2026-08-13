import {
  Body,
  Controller,
  Get,
  Module,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { Role, VisitorStatus } from '@prisma/client';
import { IsOptional, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';
import { RequiresFeature } from '../platform/feature.decorator';

class CreateVisitorDto {
  @IsString() name: string;
  @IsString() purpose: string;
  @IsOptional() @IsString() flatId?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() vehicleNo?: string;
}

@RequiresFeature('visitors')
@Controller('visitors')
class VisitorsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list(@CurrentUser() user: AuthUser) {
    const societyId = resolveSocietyId(user);
    const visitors = await this.prisma.visitor.findMany({
      where: { societyId },
      include: { flat: { select: { number: true } } },
      orderBy: { inAt: 'desc' },
    });
    return {
      visitors,
      summary: {
        insideNow: visitors.filter((v) => v.status === VisitorStatus.INSIDE)
          .length,
        today: visitors.length,
      },
    };
  }

  @Roles(Role.SECURITY_GUARD, Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateVisitorDto) {
    return this.prisma.visitor.create({
      data: {
        societyId: resolveSocietyId(user),
        name: dto.name,
        purpose: dto.purpose,
        flatId: dto.flatId ?? null,
        phone: dto.phone ?? null,
        vehicleNo: dto.vehicleNo ?? null,
      },
    });
  }

  @Roles(Role.SECURITY_GUARD, Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/checkout')
  checkout(@Param('id') id: string) {
    return this.prisma.visitor.update({
      where: { id },
      data: { status: VisitorStatus.EXITED, outAt: new Date() },
    });
  }
}

@Module({ controllers: [VisitorsController] })
export class VisitorsModule {}
