import { BillKind, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const MONTHS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

function lastDayOfMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
}

/**
 * Ensures the **current** month's RENT bill exists for every residing tenant —
 * the most recent anniversary of their move-in that has arrived. It does NOT
 * back-fill earlier months, so a resident sees one bill now and the next only
 * once that month arrives, never a pile of past months at once.
 *
 * Dates are handled as calendar (year/month/day) tuples in the server's local
 * timezone, so "due on the 20th" means the 20th here rather than drifting by a
 * timezone offset. The stored `dueDate` is anchored to UTC midnight of that day
 * so the date column reads back as the intended day.
 *
 * Idempotent: the current period is created only if missing, and a paid bill or
 * a MANUAL charge is never touched.
 */
export async function ensureRentBills(
  prisma: PrismaService,
  societyId: string,
): Promise<void> {
  const now = new Date();
  const todayY = now.getFullYear();
  const todayM = now.getMonth();
  const todayD = now.getDate();

  const tenants = await prisma.resident.findMany({
    where: {
      societyId,
      archivedAt: null,
      monthlyRent: { not: null },
      moveInDate: { not: null },
    },
    select: { flatId: true, monthlyRent: true, moveInDate: true },
  });
  if (tenants.length === 0) return;

  const existing = await prisma.bill.findMany({
    where: { societyId, kind: BillKind.RENT },
    select: { flatId: true, period: true },
  });
  const have = new Set(existing.map((b) => `${b.flatId}|${b.period}`));

  const data: Prisma.BillCreateManyInput[] = [];
  for (const t of tenants) {
    const mv = t.moveInDate!;
    const baseY = mv.getFullYear();
    const baseM = mv.getMonth();
    const baseD = mv.getDate();

    // Walk anniversaries forward and keep the LAST one that has arrived — the
    // current billing period. A future move-in has none yet.
    let current: { period: string; due: Date } | null = null;
    for (let i = 0; i < 600; i++) {
      const y = baseY + Math.floor((baseM + i) / 12);
      const m = (baseM + i) % 12;
      const d = Math.min(baseD, lastDayOfMonth(y, m));

      const dueInFuture =
        y > todayY ||
        (y === todayY && (m > todayM || (m === todayM && d > todayD)));
      if (dueInFuture) break;

      current = {
        period: `${MONTHS[m]} ${y}`,
        due: new Date(Date.UTC(y, m, d)),
      };
    }
    if (current === null) continue;

    const key = `${t.flatId}|${current.period}`;
    if (have.has(key)) continue;
    have.add(key);
    data.push({
      societyId,
      flatId: t.flatId,
      period: current.period,
      amount: t.monthlyRent!,
      dueDate: current.due,
      kind: BillKind.RENT,
    });
  }

  if (data.length) {
    await prisma.bill.createMany({ data, skipDuplicates: true });
  }
}
