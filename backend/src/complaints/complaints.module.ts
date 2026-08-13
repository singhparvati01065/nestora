import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Module,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ComplaintStatus, Role } from '@prisma/client';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';
import { RequiresFeature } from '../platform/feature.decorator';

/// Canonical maintenance staff list (mirrors the client).
export const STAFF_MEMBERS = [
  'Suresh (Plumber)',
  'Ramesh (Electrician)',
  'Vijay (Housekeeping)',
  'Anil (Handyman)',
];

class CreateComplaintDto {
  @IsString() flatId: string;
  @IsString() title: string;
  @IsString() description: string;
  @IsString() category: string;
}

class UpdateStatusDto {
  @IsEnum(ComplaintStatus) status: ComplaintStatus;
}

class AssignDto {
  @IsOptional() @IsString() assignedTo?: string | null;
}

@RequiresFeature('complaints')
@Controller('complaints')
class ComplaintsController {
  constructor(private prisma: PrismaService) {}

  /// Filters: ?flatId= (resident scope), ?assignedTo= (staff), ?unassigned=true.
  @Get()
  list(
    @CurrentUser() user: AuthUser,
    @Query('flatId') flatId?: string,
    @Query('assignedTo') assignedTo?: string,
    @Query('unassigned') unassigned?: string,
  ) {
    if (user.role === Role.RESIDENT) {
      if (!user.flatId) throw new ForbiddenException('No flat on account');
      flatId = user.flatId;
    }
    return this.prisma.complaint.findMany({
      where: {
        societyId: resolveSocietyId(user),
        ...(flatId ? { flatId } : {}),
        ...(assignedTo ? { assignedTo } : {}),
        ...(unassigned === 'true' ? { assignedTo: null } : {}),
      },
      include: { flat: { select: { number: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  /// The society's real maintenance staff, for the admin's assign dropdown.
  /// Each carries their trades so the admin can see who covers what.
  @Get('staff')
  async staff(@CurrentUser() user: AuthUser) {
    return this.prisma.user.findMany({
      where: {
        societyId: resolveSocietyId(user),
        role: Role.MAINTENANCE_STAFF,
      },
      select: { id: true, name: true, trades: true },
      orderBy: { name: 'asc' },
    });
  }

  /// Residents (or admin) raise a complaint. Residents can only file for their
  /// own flat.
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateComplaintDto) {
    if (user.role === Role.RESIDENT && dto.flatId !== user.flatId) {
      throw new ForbiddenException('Can only file for your own flat');
    }
    return this.prisma.complaint.create({
      data: { ...dto, societyId: resolveSocietyId(user) },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN, Role.MAINTENANCE_STAFF)
  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateStatusDto) {
    return this.prisma.complaint.update({
      where: { id },
      data: { status: dto.status },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN, Role.MAINTENANCE_STAFF)
  @Patch(':id/assign')
  assign(@Body() dto: AssignDto, @Param('id') id: string) {
    return this.prisma.complaint.update({
      where: { id },
      data: { assignedTo: dto.assignedTo ?? null },
    });
  }
}

@Module({ controllers: [ComplaintsController] })
export class ComplaintsModule {}
