import { AuthUser } from '../auth/decorators/current-user.decorator';
import { UpdateMeDto } from './dto/update-me.dto';
import { UsersService } from './users.service';
export declare class UsersController {
    private users;
    constructor(users: UsersService);
    updateMe(user: AuthUser, dto: UpdateMeDto): Promise<{
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
        salary: import("@prisma/client/runtime/library").Decimal | null;
        archivedAt: Date | null;
        updatedAt: Date;
    }>;
}
