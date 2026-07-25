import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Module,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { Role, VisitorStatus } from '@prisma/client';
import { IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';

class CreatePreApprovedDto {
  @IsString() name: string;
  @IsString() purpose: string;
  @IsString() validLabel: string;
}

@Controller('pre-approved')
class PreApprovedController {
  constructor(private prisma: PrismaService) {}

  /// Guard sees the whole society's list; a resident sees their own flat's.
  @Get()
  list(@CurrentUser() user: AuthUser) {
    const where =
      user.role === Role.RESIDENT
        ? { societyId: resolveSocietyId(user), flatId: user.flatId ?? '' }
        : { societyId: resolveSocietyId(user) };
    return this.prisma.preApprovedVisitor.findMany({
      where,
      include: { flat: { select: { number: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  /// A resident pre-approves an expected visitor for their own flat.
  @Roles(Role.RESIDENT)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePreApprovedDto) {
    if (!user.flatId) throw new ForbiddenException('No flat on account');
    return this.prisma.preApprovedVisitor.create({
      data: {
        societyId: resolveSocietyId(user),
        flatId: user.flatId,
        name: dto.name,
        purpose: dto.purpose,
        validLabel: dto.validLabel,
      },
    });
  }

  /// Guard checks in a pre-approved visitor: creates a Visitor entry and marks
  /// the pre-approval used.
  @Roles(Role.SECURITY_GUARD, Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/check-in')
  async checkIn(@Param('id') id: string) {
    const pre = await this.prisma.preApprovedVisitor.findUniqueOrThrow({
      where: { id },
    });
    await this.prisma.visitor.create({
      data: {
        societyId: pre.societyId,
        flatId: pre.flatId,
        name: pre.name,
        purpose: pre.purpose,
        status: VisitorStatus.INSIDE,
      },
    });
    return this.prisma.preApprovedVisitor.update({
      where: { id },
      data: { checkedIn: true },
    });
  }
}

@Module({ controllers: [PreApprovedController] })
export class PreApprovedModule {}
