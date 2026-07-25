import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateMeDto } from './dto/update-me.dto';
export declare class UsersService {
    private prisma;
    constructor(prisma: PrismaService);
    updateMe(userId: string, dto: UpdateMeDto): Promise<{
        id: string;
        societyId: string | null;
        name: string;
        flatId: string | null;
        createdAt: Date;
        phone: string;
        role: import(".prisma/client").$Enums.Role;
        staffLabel: string | null;
        trades: string[];
        firebaseUid: string | null;
        photoUrl: string | null;
        address: string | null;
        joinedAt: Date | null;
        salary: Prisma.Decimal | null;
        archivedAt: Date | null;
        updatedAt: Date;
    }>;
}
