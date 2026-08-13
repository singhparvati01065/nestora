import { PrismaService } from '../prisma/prisma.service';
export declare class FeatureFlagsService {
    private prisma;
    private cache;
    private loadedAt;
    private inFlight;
    constructor(prisma: PrismaService);
    all(): Promise<Record<string, boolean>>;
    isEnabled(key: string): Promise<boolean>;
    private load;
}
