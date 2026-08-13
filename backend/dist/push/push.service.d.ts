import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
export type PushData = Record<string, string>;
export declare class PushService {
    private prisma;
    private readonly logger;
    private readonly app;
    constructor(prisma: PrismaService, config: ConfigService);
    get enabled(): boolean;
    private initApp;
    sendToUsers(userIds: string[], title: string, body: string, data?: PushData): Promise<number>;
    sendToSocietyAdmins(societyIds: string[], title: string, body: string, data?: PushData): Promise<number>;
}
