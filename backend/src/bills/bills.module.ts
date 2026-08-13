import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Module,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { BillKind, Prisma, Role } from '@prisma/client';
import { IsNumber, IsOptional, IsPositive, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../push/push.service';
import { RequiresFeature } from '../platform/feature.decorator';
import {
  dueDateForPeriod,
  ensureRecurringBills,
  monthLabelOf,
  parseStartDate,
} from './maintenance-billing';
import { ensureRentBills } from './rent-billing';

class GenerateBillsDto {
  /// ISO date ("2026-07-23") — the day (and month) the bill is due from.
  @IsString() startDate: string;
  @IsString() flatId: string;
  /// 'RENT' | 'MANUAL' (maintenance) | 'OTHER' (custom, needs a title).
  @IsString() kind: string;
  @IsNumber() @IsPositive() amount: number;
  /// Name of an OTHER charge, e.g. "Parking". Ignored for rent/maintenance.
  @IsOptional() @IsString() title?: string;
}

class PayBillsDto {
  @IsString({ each: true }) ids: string[];
}

class UpdateBillDto {
  @IsOptional() @IsNumber() @IsPositive() amount?: number;
  /// New ISO date ("2026-08-10") — sets the due date and (its) month.
  @IsOptional() @IsString() startDate?: string;
  /// New name for an OTHER charge. Ignored for rent/maintenance.
  @IsOptional() @IsString() title?: string;
}

@RequiresFeature('online_payments')
@Controller('bills')
class BillsController {
  constructor(
    private prisma: PrismaService,
    private push: PushService,
  ) {}

  /// Admin: all bills in the society, with a collected/pending summary.
  /// Optionally filter by ?flatId= (also how a resident reads their own).
  @Get()
  async list(
    @CurrentUser() user: AuthUser,
    @Query('flatId') flatId?: string,
  ) {
    // Residents may only read their own flat's bills.
    if (user.role === Role.RESIDENT) {
      if (!user.flatId) throw new ForbiddenException('No flat on account');
      flatId = user.flatId;
    }
    const societyId = resolveSocietyId(user);
    // Backfill any rent + maintenance bills that have come due since the last
    // read — this is what makes the monthly bills appear "on their own" without
    // a scheduler.
    await ensureRentBills(this.prisma, societyId);
    await ensureRecurringBills(this.prisma, societyId);
    const where = {
      societyId,
      deletedAt: null,
      ...(flatId ? { flatId } : {}),
    };
    const bills = await this.prisma.bill.findMany({
      where,
      include: { flat: { select: { number: true } } },
      orderBy: { createdAt: 'asc' },
    });
    const num = (b: (typeof bills)[number]) => Number(b.amount);
    return {
      bills,
      summary: {
        collected: bills.filter((b) => b.paid).reduce((s, b) => s + num(b), 0),
        pending: bills.filter((b) => !b.paid).reduce((s, b) => s + num(b), 0),
        paidCount: bills.filter((b) => b.paid).length,
        pendingCount: bills.filter((b) => !b.paid).length,
      },
    };
  }

  /// Generates a bill of one kind for a flat, from the chosen date:
  ///  - RENT / MANUAL (maintenance): recurring — sets the flat's amount and
  ///    `billingSince`, then `ensureRecurringBills` tops up each later month on
  ///    its own. Existing unpaid bills of that kind are re-dated to the picked
  ///    day so changing the date shows up on bills already made.
  ///  - OTHER: a one-off custom charge (named by `title`) for that month only.
  /// Resolves a bill this user is actually allowed to touch: a resident only
  /// within their own flat, anyone else only within their own society. A bill
  /// outside that reads as missing rather than forbidden, so an id from another
  /// society reveals nothing.
  private async ownBill(user: AuthUser, id: string) {
    const where: Prisma.BillWhereInput = { id, deletedAt: null };
    if (user.role !== Role.SUPER_ADMIN) {
      where.societyId = resolveSocietyId(user);
      if (user.role === Role.RESIDENT) {
        if (!user.flatId) {
          throw new ForbiddenException('No flat linked to this account');
        }
        where.flatId = user.flatId;
      }
    }
    const bill = await this.prisma.bill.findFirst({ where, select: { id: true } });
    if (!bill) throw new NotFoundException('Bill not found');
    return bill;
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post('generate')
  async generate(
    @CurrentUser() user: AuthUser,
    @Body() dto: GenerateBillsDto,
  ) {
    const societyId = resolveSocietyId(user);
    const start = parseStartDate(dto.startDate);
    if (!start) throw new BadRequestException('Invalid start date');
    if (!dto.flatId) throw new BadRequestException('Choose a flat');
    if (!(dto.amount > 0)) throw new BadRequestException('Enter an amount');

    const flat = await this.prisma.flat.findFirst({
      where: { id: dto.flatId, societyId },
      select: { id: true },
    });
    if (!flat) throw new BadRequestException('Unknown flat');

    // OTHER: a one-off named charge for the chosen month. Not stored on the
    // flat, so it never auto-repeats.
    if (dto.kind === BillKind.OTHER) {
      const title = (dto.title ?? '').trim();
      if (!title) throw new BadRequestException('Name the charge');
      const period = monthLabelOf(start);
      // The (flat, period, kind, title) unique also covers soft-deleted rows, so
      // look those up too: block a live duplicate, but revive a deleted one.
      const existing = await this.prisma.bill.findFirst({
        where: { flatId: dto.flatId, period, kind: BillKind.OTHER, title },
        select: { id: true, deletedAt: true },
      });
      if (existing && existing.deletedAt == null) {
        throw new BadRequestException(
          `A "${title}" charge already exists for ${period}`,
        );
      }
      if (existing) {
        await this.prisma.bill.update({
          where: { id: existing.id },
          data: {
            amount: dto.amount,
            dueDate: start,
            deletedAt: null,
            paid: false,
            paidAt: null,
          },
        });
      } else {
        await this.prisma.bill.create({
          data: {
            societyId,
            flatId: dto.flatId,
            period,
            amount: dto.amount,
            dueDate: start,
            kind: BillKind.OTHER,
            title,
          },
        });
      }
      return { created: 1, period };
    }

    if (dto.kind !== BillKind.RENT && dto.kind !== BillKind.MANUAL) {
      throw new BadRequestException('Unknown bill type');
    }

    // Recurring: the admin's picked start (day included) drives the recurrence.
    await this.prisma.flat.update({
      where: { id: dto.flatId },
      data: {
        billingSince: start,
        ...(dto.kind === BillKind.RENT
          ? { rentAmount: dto.amount }
          : { maintenanceAmount: dto.amount }),
      },
    });

    const before = await this.prisma.bill.count({ where: { societyId } });
    await ensureRecurringBills(this.prisma, societyId);
    const after = await this.prisma.bill.count({ where: { societyId } });

    // Re-date this flat's existing unpaid bills of the chosen kind to the picked
    // day, so a changed start date shows up on bills already made.
    const day = start.getUTCDate();
    const existing = await this.prisma.bill.findMany({
      where: {
        societyId,
        flatId: dto.flatId,
        deletedAt: null,
        paid: false,
        kind: dto.kind,
      },
      select: { id: true, period: true },
    });
    for (const b of existing) {
      const due = dueDateForPeriod(b.period, day);
      if (due) {
        await this.prisma.bill.update({
          where: { id: b.id },
          data: { dueDate: due },
        });
      }
    }

    return { created: after - before, period: monthLabelOf(start) };
  }

  @Roles(Role.RESIDENT, Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/pay')
  async pay(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.ownBill(user, id);
    return this.prisma.bill.update({
      where: { id },
      data: { paid: true, paidAt: new Date() },
    });
  }

  /// Pays several bills as one payment: they all get the SAME paidAt so the
  /// resident's history shows them together as a single transaction. Also drops
  /// a notification for the admin that the payment came in.
  @Roles(Role.RESIDENT, Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post('pay')
  async payMany(@CurrentUser() user: AuthUser, @Body() dto: PayBillsDto) {
    const paidAt = new Date();
    // Same rule as the single-bill routes: ids outside the caller's flat /
    // society simply do not match, so they are silently left alone.
    const where: Prisma.BillWhereInput = {
      id: { in: dto.ids },
      deletedAt: null,
    };
    if (user.role !== Role.SUPER_ADMIN) {
      where.societyId = resolveSocietyId(user);
      if (user.role === Role.RESIDENT) {
        if (!user.flatId) {
          throw new ForbiddenException('No flat linked to this account');
        }
        where.flatId = user.flatId;
      }
    }
    const res = await this.prisma.bill.updateMany({
      where,
      data: { paid: true, paidAt },
    });

    // Notify the admin about the payment.
    if (res.count > 0) {
      const bills = await this.prisma.bill.findMany({
        where: { id: { in: dto.ids } },
        select: {
          amount: true,
          societyId: true,
          flatId: true,
          flat: { select: { number: true } },
        },
      });
      if (bills.length > 0) {
        const total = bills.reduce((s, b) => s + Number(b.amount), 0);
        const flatNumber = bills[0].flat.number;
        // Name the person who actually paid (the logged-in account).
        const who = user.name
          ? `${user.name} (Flat ${flatNumber})`
          : `Flat ${flatNumber}`;
        const body =
          `${who} paid ₹${total.toFixed(0)} for ${bills.length} ` +
          `bill${bills.length === 1 ? '' : 's'}.`;
        await this.prisma.appNotification.create({
          data: {
            societyId: bills[0].societyId,
            title: 'Payment received',
            body,
          },
        });
        // The bell entry above is what the admin sees inside the app; this is
        // what reaches them when it is closed. Fire-and-forget: a push that
        // fails must not fail the payment.
        void this.push.sendToSocietyAdmins(
          [bills[0].societyId],
          'Payment received',
          body,
        );
      }
    }
    return { paid: res.count, paidAt };
  }

  /// Admin edits a single bill: its amount, due date (day/month), and — for an
  /// OTHER charge — its name. Editing one bill never changes the flat's recurring
  /// amount, so only this bill moves.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateBillDto,
  ) {
    const societyId = resolveSocietyId(user);
    const bill = await this.prisma.bill.findFirst({
      where: { id, societyId },
      select: { id: true, kind: true, flatId: true, period: true, title: true },
    });
    if (!bill) throw new BadRequestException('Bill not found');

    const data: Prisma.BillUpdateInput = {};
    if (dto.amount != null) {
      if (!(dto.amount > 0)) throw new BadRequestException('Enter an amount');
      data.amount = dto.amount;
    }
    let period = bill.period;
    if (dto.startDate) {
      const d = parseStartDate(dto.startDate);
      if (!d) throw new BadRequestException('Invalid date');
      period = monthLabelOf(d);
      data.dueDate = d;
      data.period = period;
    }
    let title = bill.title;
    if (bill.kind === BillKind.OTHER && dto.title != null) {
      title = dto.title.trim();
      if (!title) throw new BadRequestException('Name the charge');
      data.title = title;
    }

    // Moving to a month/name another bill of this kind already occupies would
    // break the (flat, period, kind, title) uniqueness — reject it clearly.
    if (period !== bill.period || title !== bill.title) {
      const clash = await this.prisma.bill.findFirst({
        where: {
          flatId: bill.flatId,
          period,
          kind: bill.kind,
          title,
          id: { not: bill.id },
        },
        select: { id: true },
      });
      if (clash) {
        throw new BadRequestException(
          bill.kind === BillKind.OTHER
            ? `A "${title}" charge already exists for ${period}`
            : `A ${bill.kind === BillKind.RENT ? 'rent' : 'maintenance'} ` +
                `bill already exists for ${period}`,
        );
      }
    }

    return this.prisma.bill.update({ where: { id }, data });
  }

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/unpay')
  async unpay(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.ownBill(user, id);
    return this.prisma.bill.update({
      where: { id },
      data: { paid: false, paidAt: null },
    });
  }

  /// Soft-deletes a bill (admin only): hidden from lists, but the row remains so
  /// the recurring backfill's dedup won't simply recreate it on the next read.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Delete(':id')
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.ownBill(user, id);
    return this.prisma.bill.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }
}

@Module({ controllers: [BillsController] })
export class BillsModule {}
