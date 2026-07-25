import {
  BadRequestException,
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
import {
  IsIn,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
} from 'class-validator';
import { toLocalPhone } from '../auth/auth.service';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';

const STAFF_ROLES: Role[] = [Role.SECURITY_GUARD, Role.MAINTENANCE_STAFF];

class CreateStaffDto {
  @IsIn(['SECURITY_GUARD', 'MAINTENANCE_STAFF'])
  role: 'SECURITY_GUARD' | 'MAINTENANCE_STAFF';
  @IsString() name: string;
  @IsString() phone: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsISO8601() joinedAt?: string;
  @IsOptional() @IsNumber() @IsPositive() salary?: number;
  /// Trades a maintenance staffer handles; ignored for guards.
  @IsOptional() @IsString({ each: true }) trades?: string[];
}

class UpdateStaffDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsISO8601() joinedAt?: string;
  @IsOptional() @IsNumber() salary?: number;
  @IsOptional() @IsString({ each: true }) trades?: string[];
}

const STAFF_FIELDS = {
  id: true,
  name: true,
  phone: true,
  address: true,
  joinedAt: true,
  salary: true,
  role: true,
  trades: true,
} as const;

@Controller('staff')
class StaffController {
  constructor(private prisma: PrismaService) {}

  /// The society's active guards + maintenance staff, for the admin.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Get()
  list(@CurrentUser() user: AuthUser) {
    const societyId = resolveSocietyId(user);
    return this.prisma.user.findMany({
      where: { societyId, role: { in: STAFF_ROLES }, archivedAt: null },
      select: STAFF_FIELDS,
      orderBy: { name: 'asc' },
    });
  }

  /// Removed (archived) staff — the history, newest first.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Get('archived')
  history(@CurrentUser() user: AuthUser) {
    const societyId = resolveSocietyId(user);
    return this.prisma.user.findMany({
      where: {
        societyId,
        role: { in: STAFF_ROLES },
        archivedAt: { not: null },
      },
      select: STAFF_FIELDS,
      orderBy: { archivedAt: 'desc' },
    });
  }

  /// Creates a guard / maintenance login account for this society. Matched by
  /// phone: a fresh number gets a new account, and they then simply log in with
  /// it — staff never self-register.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post()
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateStaffDto) {
    const societyId = resolveSocietyId(user);
    const phone = toLocalPhone(dto.phone);
    if (phone.length < 10) {
      throw new BadRequestException('Enter a valid phone number');
    }
    const role = dto.role as Role;
    const trades = role === Role.MAINTENANCE_STAFF ? dto.trades ?? [] : [];
    const address = dto.address?.trim() || null;
    const joinedAt = dto.joinedAt ? new Date(dto.joinedAt) : new Date();
    const salary = dto.salary ?? null;

    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing && !STAFF_ROLES.includes(existing.role)) {
      throw new BadRequestException(
        'This number already belongs to another account',
      );
    }
    if (existing) {
      // Re-adding a previously removed number un-archives it.
      return this.prisma.user.update({
        where: { id: existing.id },
        data: {
          name: dto.name.trim(),
          role,
          societyId,
          trades,
          address,
          joinedAt,
          salary,
          archivedAt: null,
        },
        select: STAFF_FIELDS,
      });
    }
    return this.prisma.user.create({
      data: {
        phone,
        name: dto.name.trim(),
        role,
        societyId,
        trades,
        address,
        joinedAt,
        salary,
      },
      select: STAFF_FIELDS,
    });
  }

  /// Edits a staff member's details (name, phone, address, trades). Their role
  /// stays fixed. Society-scoped.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateStaffDto,
  ) {
    const societyId = resolveSocietyId(user);
    const staff = await this.prisma.user.findFirst({
      where: { id, societyId, role: { in: STAFF_ROLES } },
      select: { id: true, role: true },
    });
    if (!staff) throw new BadRequestException('Staff member not found');

    const data: {
      name?: string;
      address?: string | null;
      joinedAt?: Date;
      salary?: number | null;
      trades?: string[];
      phone?: string;
    } = {};
    if (dto.name != null) data.name = dto.name.trim();
    if (dto.address !== undefined) data.address = dto.address?.trim() || null;
    if (dto.joinedAt) data.joinedAt = new Date(dto.joinedAt);
    if (dto.salary !== undefined) data.salary = dto.salary || null;
    if (staff.role === Role.MAINTENANCE_STAFF && dto.trades != null) {
      data.trades = dto.trades;
    }
    if (dto.phone != null) {
      const phone = toLocalPhone(dto.phone);
      if (phone.length < 10) {
        throw new BadRequestException('Enter a valid phone number');
      }
      const clash = await this.prisma.user.findFirst({
        where: { phone, id: { not: id } },
        select: { id: true },
      });
      if (clash) {
        throw new BadRequestException(
          'This number already belongs to another account',
        );
      }
      data.phone = phone;
    }
    return this.prisma.user.update({
      where: { id },
      data,
      select: STAFF_FIELDS,
    });
  }

  /// Soft-remove: moves the staff member to history. Kept society-scoped for the
  /// record; login is refused for archived accounts (see AuthService).
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/archive')
  async archive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const societyId = resolveSocietyId(user);
    const staff = await this.prisma.user.findFirst({
      where: { id, societyId, role: { in: STAFF_ROLES } },
      select: { id: true },
    });
    if (!staff) throw new BadRequestException('Staff member not found');
    return this.prisma.user.update({
      where: { id },
      data: { archivedAt: new Date() },
      select: STAFF_FIELDS,
    });
  }

  /// Permanently deletes a staff account (from history).
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Delete(':id')
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const societyId = resolveSocietyId(user);
    const staff = await this.prisma.user.findFirst({
      where: { id, societyId, role: { in: STAFF_ROLES } },
      select: { id: true },
    });
    if (!staff) throw new BadRequestException('Staff member not found');
    await this.prisma.user.delete({ where: { id } });
    return { ok: true };
  }
}

@Module({ controllers: [StaffController] })
export class StaffModule {}
