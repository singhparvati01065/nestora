import { PrismaService } from '../prisma/prisma.service';
export declare function ensureRecurringBills(prisma: PrismaService, societyId: string): Promise<void>;
export declare function dueDateForPeriod(period: string, day: number): Date | null;
export declare function parseStartDate(iso: string): Date | null;
export declare function monthLabelOf(date: Date): string;
