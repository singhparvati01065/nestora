import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateMeDto } from './dto/update-me.dto';
export declare class UsersService {
    private prisma;
    constructor(prisma: PrismaService);
    updateMe(userId: string, dto: UpdateMeDto): Promise<{
        id: string;
        phone: string;
        email: string | null;
        firebaseUid: string | null;
        name: string;
        photoUrl: string | null;
        role: import(".prisma/client").$Enums.Role;
        societyId: string | null;
        flatId: string | null;
        staffLabel: string | null;
        banned: boolean;
        address: string | null;
        joinedAt: Date | null;
        salary: Prisma.Decimal | null;
        archivedAt: Date | null;
        trades: string[];
        createdAt: Date;
        updatedAt: Date;
    }>;
}
