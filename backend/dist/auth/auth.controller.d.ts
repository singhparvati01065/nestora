import { AuthService } from './auth.service';
import { AuthUser } from './decorators/current-user.decorator';
import { DevLoginDto, FirebaseLoginDto, LoginDto, RegisterDto } from './dto/auth.dto';
export declare class AuthController {
    private auth;
    constructor(auth: AuthService);
    register(dto: RegisterDto): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
    firebase(dto: FirebaseLoginDto): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
    devLogin(dto: DevLoginDto): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
    me(user: AuthUser): Promise<{
        society: {
            id: string;
            name: string;
            address: string;
            createdAt: Date;
            updatedAt: Date;
            city: string | null;
            state: string | null;
            logoUrl: string | null;
            hasTowers: boolean;
            monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
            maintenanceSince: Date | null;
            plan: import(".prisma/client").$Enums.SubscriptionPlan;
            planExpiresAt: Date | null;
            suspended: boolean;
        } | null;
        flat: {
            number: string;
            id: string;
            societyId: string;
            towerId: string;
            floor: number;
            rentAmount: import("@prisma/client/runtime/library").Decimal | null;
            maintenanceAmount: import("@prisma/client/runtime/library").Decimal | null;
            billingSince: Date | null;
        } | null;
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
    refresh(user: AuthUser): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
}
