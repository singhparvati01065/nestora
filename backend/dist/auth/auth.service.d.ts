import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from './decorators/current-user.decorator';
import { DevLoginDto, FirebaseLoginDto, LoginDto, RegisterDto } from './dto/auth.dto';
import { FirebaseAdminService } from './firebase-admin.service';
export declare function toLocalPhone(e164: string): string;
export declare class AuthService {
    private prisma;
    private jwt;
    private firebase;
    private readonly logger;
    constructor(prisma: PrismaService, jwt: JwtService, firebase: FirebaseAdminService);
    private tokenFor;
    private toAuthUser;
    register(dto: RegisterDto): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
    firebaseLogin(dto: FirebaseLoginDto): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
    devLogin(dto: DevLoginDto): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
    me(userId: string): Promise<{
        society: {
            id: string;
            name: string;
            createdAt: Date;
            address: string;
            updatedAt: Date;
            logoUrl: string | null;
            hasTowers: boolean;
            monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
            maintenanceSince: Date | null;
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
    refresh(userId: string): Promise<{
        accessToken: string;
        user: AuthUser;
    }>;
}
