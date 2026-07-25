import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Module,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { BookingStatus, Role } from '@prisma/client';
import { IsIn, IsOptional, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';

class BookAmenityDto {
  @IsString() amenityId: string;
  @IsString() day: string; // ISO date "2026-07-25"
  @IsString() slot: string;
}

class AmenityDto {
  @IsString() name: string;
  @IsString() icon: string;
}

class UpdateAmenityDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() icon?: string;
}

class BookingStatusDto {
  @IsIn(['PENDING', 'APPROVED', 'REJECTED'])
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
}

/// Bookings that still hold a slot (not rejected).
const ACTIVE = { not: BookingStatus.REJECTED };

@Controller('amenities')
class AmenitiesController {
  constructor(private prisma: PrismaService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.prisma.amenity.findMany({
      where: { societyId: resolveSocietyId(user) },
      orderBy: { name: 'asc' },
    });
  }

  // ---- Admin: manage the amenities themselves ----

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: AmenityDto) {
    return this.prisma.amenity.create({
      data: {
        societyId: resolveSocietyId(user),
        name: dto.name.trim(),
        icon: dto.icon,
      },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateAmenityDto,
  ) {
    await this.ownAmenity(user, id);
    return this.prisma.amenity.update({
      where: { id },
      data: {
        ...(dto.name != null ? { name: dto.name.trim() } : {}),
        ...(dto.icon != null ? { icon: dto.icon } : {}),
      },
    });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Delete(':id')
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.ownAmenity(user, id);
    await this.prisma.amenity.delete({ where: { id } });
    return { ok: true };
  }

  // ---- Bookings ----

  /// A resident's own bookings.
  @Roles(Role.RESIDENT)
  @Get('bookings')
  bookings(@CurrentUser() user: AuthUser) {
    if (!user.flatId) throw new ForbiddenException('No flat on account');
    return this.prisma.amenityBooking.findMany({
      where: { flatId: user.flatId },
      include: { amenity: { select: { name: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  /// Admin: every booking in the society, for approval.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Get('bookings/all')
  allBookings(@CurrentUser() user: AuthUser) {
    return this.prisma.amenityBooking.findMany({
      where: { societyId: resolveSocietyId(user) },
      include: {
        amenity: { select: { name: true } },
        flat: { select: { number: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /// Slots already taken (pending or approved) for an amenity on a day — so the
  /// booking UI can grey them out.
  @Get('booked')
  async booked(
    @CurrentUser() user: AuthUser,
    @Query('amenityId') amenityId: string,
    @Query('day') day: string,
  ) {
    const societyId = resolveSocietyId(user);
    const rows = await this.prisma.amenityBooking.findMany({
      where: { societyId, amenityId, day, status: ACTIVE },
      select: { slot: true },
    });
    return rows.map((r) => r.slot);
  }

  @Roles(Role.RESIDENT)
  @Post('book')
  async book(@CurrentUser() user: AuthUser, @Body() dto: BookAmenityDto) {
    if (!user.flatId) throw new ForbiddenException('No flat on account');
    const societyId = resolveSocietyId(user);
    // One booking per amenity + day + slot (ignoring rejected ones).
    const clash = await this.prisma.amenityBooking.findFirst({
      where: {
        societyId,
        amenityId: dto.amenityId,
        day: dto.day,
        slot: dto.slot,
        status: ACTIVE,
      },
      select: { id: true },
    });
    if (clash) {
      throw new BadRequestException('That slot is already booked.');
    }
    return this.prisma.amenityBooking.create({
      data: {
        societyId,
        amenityId: dto.amenityId,
        flatId: user.flatId,
        day: dto.day,
        slot: dto.slot,
      },
    });
  }

  /// Resident cancels their own booking; admin can cancel any in their society.
  @Delete('bookings/:id')
  async cancel(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const booking = await this.prisma.amenityBooking.findUnique({
      where: { id },
      select: { flatId: true, societyId: true },
    });
    if (!booking) throw new BadRequestException('Booking not found');
    const isOwner =
      user.role === Role.RESIDENT && booking.flatId === user.flatId;
    const isAdmin =
      (user.role === Role.SOCIETY_ADMIN || user.role === Role.SUPER_ADMIN) &&
      booking.societyId === resolveSocietyId(user);
    if (!isOwner && !isAdmin) {
      throw new ForbiddenException('Not your booking');
    }
    await this.prisma.amenityBooking.delete({ where: { id } });
    return { ok: true };
  }

  /// Admin approves or rejects a booking.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch('bookings/:id/status')
  async setStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: BookingStatusDto,
  ) {
    const societyId = resolveSocietyId(user);
    const booking = await this.prisma.amenityBooking.findFirst({
      where: { id, societyId },
      select: { id: true },
    });
    if (!booking) throw new BadRequestException('Booking not found');
    return this.prisma.amenityBooking.update({
      where: { id },
      data: { status: dto.status as BookingStatus },
      include: {
        amenity: { select: { name: true } },
        flat: { select: { number: true } },
      },
    });
  }

  private async ownAmenity(user: AuthUser, id: string) {
    const found = await this.prisma.amenity.findFirst({
      where: { id, societyId: resolveSocietyId(user) },
      select: { id: true },
    });
    if (!found) throw new BadRequestException('Amenity not found');
  }
}

@Module({ controllers: [AmenitiesController] })
export class AmenitiesModule {}
