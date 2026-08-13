import { SubscriptionPlan } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
type Planned = {
    id: string;
    plan: SubscriptionPlan;
    planExpiresAt: Date | null;
};
export declare function applyPlanExpiry<T extends Planned>(prisma: PrismaService, society: T): Promise<T>;
export {};
