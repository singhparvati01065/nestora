import { AuthUser } from '../auth/decorators/current-user.decorator';
import { UpdateMeDto } from './dto/update-me.dto';
import { UsersService } from './users.service';
export declare class UsersController {
    private users;
    constructor(users: UsersService);
    updateMe(user: AuthUser, dto: UpdateMeDto): Promise<{
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
        salary: import("@prisma/client/runtime/library").Decimal | null;
        archivedAt: Date | null;
        trades: string[];
        createdAt: Date;
        updatedAt: Date;
    }>;
    deleteMe(user: AuthUser): Promise<{
        deleted: boolean;
    }>;
}
