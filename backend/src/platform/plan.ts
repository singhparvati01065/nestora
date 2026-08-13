import { SubscriptionPlan } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/// A society whose premium plan is set from the super-admin panel.
type Planned = {
  id: string;
  plan: SubscriptionPlan;
  planExpiresAt: Date | null;
};

/// A premium plan lapses on its own: once `planExpiresAt` is in the past the
/// society drops back to FREE.
///
/// Applied lazily wherever the society is read rather than by a cron, so the
/// answer is correct on the first request after expiry with nothing scheduled
/// to keep running. Returns the society as it should now be read.
export async function applyPlanExpiry<T extends Planned>(
  prisma: PrismaService,
  society: T,
): Promise<T> {
  const expired =
    society.plan !== SubscriptionPlan.FREE &&
    society.planExpiresAt !== null &&
    society.planExpiresAt.getTime() <= Date.now();
  if (!expired) return society;

  await prisma.society
    .update({
      where: { id: society.id },
      data: { plan: SubscriptionPlan.FREE, planExpiresAt: null },
    })
    .catch(() => null);
  return { ...society, plan: SubscriptionPlan.FREE, planExpiresAt: null };
}
