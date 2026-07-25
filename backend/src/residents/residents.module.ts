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
import { ResidentType, Role } from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Min,
} from 'class-validator';
import { toLocalPhone } from '../auth/auth.service';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { ensureRentBills } from '../bills/rent-billing';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';

class CreateResidentDto {
  @IsString() flatId: string;
  @IsString() name: string;
  @IsString() phone: string;
  @IsEnum(ResidentType) type: ResidentType;

  /// Monthly rent. With [moveInDate] set, monthly bills auto-generate. Rent is
  /// now usually set from the admin's Generate Bill flow, so this is optional.
  @IsOptional() @IsNumber() @IsPositive() monthlyRent?: number;

  /// ISO date the resident moved in — the anniversary each bill is due on.
  @IsOptional() @IsISO8601() moveInDate?: string;

  @IsOptional() @IsNumber() @IsPositive() advanceAmount?: number;
  @IsOptional() @IsNumber() @IsPositive() maintenanceAmount?: number;
  @IsOptional() @IsString() occupation?: string;
  @IsOptional() @IsInt() @Min(1) familyMembers?: number;
  @IsOptional() @IsString({ each: true }) documentUrls?: string[];
}

class UpdateResidentDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsEnum(ResidentType) type?: ResidentType;
  @IsOptional() @IsNumber() @IsPositive() monthlyRent?: number;
  @IsOptional() @IsISO8601() moveInDate?: string;
  @IsOptional() @IsNumber() @IsPositive() advanceAmount?: number;
  @IsOptional() @IsNumber() @IsPositive() maintenanceAmount?: number;
  @IsOptional() @IsString() occupation?: string;
  @IsOptional() @IsInt() @Min(1) familyMembers?: number;
  @IsOptional() @IsString({ each: true }) documentUrls?: string[];
}

@Controller('residents')
class ResidentsController {
  constructor(private prisma: PrismaService) {}

  /// Active residents (not archived).
  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.prisma.resident.findMany({
      where: { societyId: resolveSocietyId(user), archivedAt: null },
      include: { flat: { select: { number: true } } },
      orderBy: { createdAt: 'asc' },
    });
  }

  /// Removed (archived) residents — the history, newest first.
  @Get('archived')
  history(@CurrentUser() user: AuthUser) {
    return this.prisma.resident.findMany({
      where: { societyId: resolveSocietyId(user), archivedAt: { not: null } },
      include: { flat: { select: { number: true } } },
      orderBy: { archivedAt: 'desc' },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post()
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateResidentDto) {
    const societyId = resolveSocietyId(user);
    // One active resident per flat: block a second until the current one is
    // removed (archived / deleted).
    const occupied = await this.prisma.resident.findFirst({
      where: { flatId: dto.flatId, societyId, archivedAt: null },
      select: { id: true },
    });
    if (occupied) {
      throw new BadRequestException(
        'This flat already has a resident. Remove them before adding a new one.',
      );
    }
    const resident = await this.prisma.resident.create({
      data: {
        societyId,
        flatId: dto.flatId,
        name: dto.name,
        phone: dto.phone,
        type: dto.type,
        monthlyRent: dto.monthlyRent,
        moveInDate: dto.moveInDate ? new Date(dto.moveInDate) : undefined,
        advanceAmount: dto.advanceAmount,
        maintenanceAmount: dto.maintenanceAmount,
        occupation: dto.occupation,
        familyMembers: dto.familyMembers,
        documentUrls: dto.documentUrls,
      },
    });
    // Link the resident's login account to this flat so they see its bills.
    await this.linkUserToFlat(dto.phone, dto.flatId, societyId, dto.name);
    // Immediately generate any months already due.
    await ensureRentBills(this.prisma, societyId);
    return resident;
  }

  /// Points the resident's login (matched by phone) at [flatId], creating the
  /// account if it doesn't exist yet — so signing in with that number lands on
  /// the flat and GET /bills scopes to it. Only ever touches RESIDENT accounts.
  private async linkUserToFlat(
    phone: string | null | undefined,
    flatId: string,
    societyId: string,
    name: string,
  ) {
    const local = phone ? toLocalPhone(phone) : '';
    if (!local) return;
    const existing = await this.prisma.user.findUnique({
      where: { phone: local },
    });
    if (existing) {
      if (existing.role !== Role.RESIDENT) return;
      await this.prisma.user.update({
        where: { id: existing.id },
        data: { flatId, societyId },
      });
    } else {
      await this.prisma.user.create({
        data: { phone: local, name, role: Role.RESIDENT, flatId, societyId },
      });
    }
  }

  /// Detaches the resident's login from any flat (used when they're archived or
  /// removed), so they stop seeing that flat's bills. Never deletes the account.
  private async unlinkUserFromFlat(phone: string | null | undefined) {
    const local = phone ? toLocalPhone(phone) : '';
    if (!local) return;
    await this.prisma.user.updateMany({
      where: { phone: local, role: Role.RESIDENT },
      data: { flatId: null },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateResidentDto,
  ) {
    const societyId = resolveSocietyId(user);
    const resident = await this.prisma.resident.update({
      where: { id },
      data: {
        name: dto.name,
        phone: dto.phone,
        type: dto.type,
        monthlyRent: dto.monthlyRent,
        moveInDate: dto.moveInDate ? new Date(dto.moveInDate) : undefined,
        advanceAmount: dto.advanceAmount,
        maintenanceAmount: dto.maintenanceAmount,
        occupation: dto.occupation,
        familyMembers: dto.familyMembers,
        documentUrls: dto.documentUrls,
      },
    });
    // Keep the linked login pointing at this flat (e.g. if the phone changed).
    await this.linkUserToFlat(
      resident.phone,
      resident.flatId,
      societyId,
      resident.name,
    );
    await ensureRentBills(this.prisma, societyId);
    return resident;
  }

  /// Soft delete: moves the resident to the history screen, keeping the record.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/archive')
  async archive(@Param('id') id: string) {
    const resident = await this.prisma.resident.update({
      where: { id },
      data: { archivedAt: new Date() },
    });
    // An archived resident should no longer see the flat's bills.
    await this.unlinkUserFromFlat(resident.phone);
    return resident;
  }

  /// Permanently deletes a resident (from the history screen).
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Delete(':id')
  async remove(@Param('id') id: string) {
    const resident = await this.prisma.resident.delete({ where: { id } });
    await this.unlinkUserFromFlat(resident.phone);
    return resident;
  }
}

@Module({ controllers: [ResidentsController] })
export class ResidentsModule {}
