import { BillKind, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const MONTHS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/**
 * Back-fills the admin-set recurring bills for every flat that has a
 * `billingSince`: a RENT bill of `rentAmount` and/or a MANUAL (maintenance) bill
 * of `maintenanceAmount`, for each month from that month up to the current one.
 * Same lazy, scheduler-free pattern as the per-resident rent — called on every
 * GET /bills, so later months appear on their own.
 *
 * Dedups against existing bills by (flat, period, kind), so a flat whose
 * per-resident rent already made a RENT bill for a month is never doubled, a
 * paid bill is untouched, and changing an amount only affects new months.
 *
 * Calendar (year/month) tuples are read in the server's local timezone so the
 * "current month" is the month here, not one shifted by a UTC offset.
 */
export async function ensureRecurringBills(
  prisma: PrismaService,
  societyId: string,
): Promise<void> {
  const now = new Date();
  const nowY = now.getFullYear();
  const nowM = now.getMonth();

  const flats = await prisma.flat.findMany({
    where: { societyId, billingSince: { not: null } },
    select: {
      id: true,
      rentAmount: true,
      maintenanceAmount: true,
      billingSince: true,
    },
  });
  if (flats.length === 0) return;

  const existing = await prisma.bill.findMany({
    where: { societyId },
    select: { flatId: true, period: true, kind: true },
  });
  const have = new Set(
    existing.map((b) => `${b.flatId}|${b.period}|${b.kind}`),
  );

  const data: Prisma.BillCreateManyInput[] = [];
  const add = (
    flatId: string,
    period: string,
    amount: Prisma.Decimal,
    due: Date,
    kind: BillKind,
  ) => {
    const key = `${flatId}|${period}|${kind}`;
    if (have.has(key)) return;
    have.add(key);
    data.push({ societyId, flatId, period, amount, dueDate: due, kind });
  };

  for (const f of flats) {
    const since = f.billingSince!;
    const sY = since.getFullYear();
    const sM = since.getMonth();
    const sD = since.getDate();
    // From the start month through the current month — but always at least the
    // start month itself, so generating a future month's bill materialises it now
    // rather than waiting for that month to arrive.
    const span = Math.max(0, (nowY - sY) * 12 + (nowM - sM));

    for (let i = 0; i <= span; i++) {
      const y = sY + Math.floor((sM + i) / 12);
      const m = (sM + i) % 12;
      const period = `${MONTHS[m]} ${y}`;
      // Each month is due on the same day-of-month the admin picked.
      const day = Math.min(sD, lastDayOfMonth(y, m));
      const due = new Date(Date.UTC(y, m, day));
      if (f.rentAmount) add(f.id, period, f.rentAmount, due, BillKind.RENT);
      if (f.maintenanceAmount) {
        add(f.id, period, f.maintenanceAmount, due, BillKind.MANUAL);
      }
    }
  }

  if (data.length) {
    await prisma.bill.createMany({ data, skipDuplicates: true });
  }
}

function lastDayOfMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
}

/** The due date for a "Jul 2026" period on day-of-month [day] (UTC midnight). */
export function dueDateForPeriod(period: string, day: number): Date | null {
  const parts = period.trim().split(/\s+/);
  if (parts.length !== 2) return null;
  const m = MONTHS.indexOf(parts[0]);
  const y = Number(parts[1]);
  if (m < 0 || !Number.isFinite(y)) return null;
  return new Date(Date.UTC(y, m, Math.min(day, lastDayOfMonth(y, m))));
}

/** Parses an ISO date ("2026-07-23") to that day at UTC midnight. */
export function parseStartDate(iso: string): Date | null {
  const parts = iso.trim().split('-').map(Number);
  if (parts.length < 3) return null;
  const [y, m, d] = parts;
  if (!y || !m || !d) return null;
  return new Date(Date.UTC(y, m - 1, d));
}

const MONTHS_LABEL = MONTHS;
/** "Jul 2026" for the month of [date] (local calendar). */
export function monthLabelOf(date: Date): string {
  return `${MONTHS_LABEL[date.getMonth()]} ${date.getFullYear()}`;
}
