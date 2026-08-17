import { Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateMeDto } from './dto/update-me.dto';
export declare class UsersService {
    private prisma;
    constructor(prisma: PrismaService);
    updateMe(userId: string, dto: UpdateMeDto): Promise<{
        id: string;
        updatedAt: Date;
        name: string;
        societyId: string | null;
        flatId: string | null;
        createdAt: Date;
        phone: string;
        role: import(".prisma/client").$Enums.Role;
        staffLabel: string | null;
        trades: string[];
        address: string | null;
        email: string | null;
        firebaseUid: string | null;
        photoUrl: string | null;
        banned: boolean;
        joinedAt: Date | null;
        salary: Prisma.Decimal | null;
        archivedAt: Date | null;
    }>;
    deleteMe(userId: string, role: Role): Promise<{
        deleted: boolean;
    }>;
}
