import { AuthUser } from '../auth/decorators/current-user.decorator';
import { CreateSocietyDto } from './dto/create-society.dto';
import { UpdateSocietyDto } from './dto/update-society.dto';
import { UpdateSocietyProfileDto } from './dto/update-society-profile.dto';
import { SocietiesService } from './societies.service';
export declare class SocietiesController {
    private societies;
    constructor(societies: SocietiesService);
    create(user: AuthUser, dto: CreateSocietyDto): Promise<{
        stats: {
            towers: number;
            flats: number;
            minFloors: number;
            maxFloors: number;
        };
        towers: ({
            flats: {
                number: string;
                id: string;
                societyId: string;
                towerId: string;
                floor: number;
                rentAmount: import("@prisma/client/runtime/library").Decimal | null;
                maintenanceAmount: import("@prisma/client/runtime/library").Decimal | null;
                billingSince: Date | null;
            }[];
        } & {
            id: string;
            name: string;
            societyId: string;
            letter: string;
        })[];
        id: string;
        updatedAt: Date;
        name: string;
        logoUrl: string | null;
        createdAt: Date;
        address: string;
        city: string | null;
        state: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
        plan: import(".prisma/client").$Enums.SubscriptionPlan;
        planExpiresAt: Date | null;
        suspended: boolean;
    }>;
    updateProfile(user: AuthUser, id: string, dto: UpdateSocietyProfileDto): Promise<{
        stats: {
            towers: number;
            flats: number;
            minFloors: number;
            maxFloors: number;
        };
        towers: ({
            flats: {
                number: string;
                id: string;
                societyId: string;
                towerId: string;
                floor: number;
                rentAmount: import("@prisma/client/runtime/library").Decimal | null;
                maintenanceAmount: import("@prisma/client/runtime/library").Decimal | null;
                billingSince: Date | null;
            }[];
        } & {
            id: string;
            name: string;
            societyId: string;
            letter: string;
        })[];
        id: string;
        updatedAt: Date;
        name: string;
        logoUrl: string | null;
        createdAt: Date;
        address: string;
        city: string | null;
        state: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
        plan: import(".prisma/client").$Enums.SubscriptionPlan;
        planExpiresAt: Date | null;
        suspended: boolean;
    }>;
    update(user: AuthUser, id: string, dto: UpdateSocietyDto): Promise<{
        stats: {
            towers: number;
            flats: number;
            minFloors: number;
            maxFloors: number;
        };
        towers: ({
            flats: {
                number: string;
                id: string;
                societyId: string;
                towerId: string;
                floor: number;
                rentAmount: import("@prisma/client/runtime/library").Decimal | null;
                maintenanceAmount: import("@prisma/client/runtime/library").Decimal | null;
                billingSince: Date | null;
            }[];
        } & {
            id: string;
            name: string;
            societyId: string;
            letter: string;
        })[];
        id: string;
        updatedAt: Date;
        name: string;
        logoUrl: string | null;
        createdAt: Date;
        address: string;
        city: string | null;
        state: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
        plan: import(".prisma/client").$Enums.SubscriptionPlan;
        planExpiresAt: Date | null;
        suspended: boolean;
    }>;
    mine(user: AuthUser, societyId?: string): Promise<{
        stats: {
            towers: number;
            flats: number;
            minFloors: number;
            maxFloors: number;
        };
        towers: ({
            flats: {
                number: string;
                id: string;
                societyId: string;
                towerId: string;
                floor: number;
                rentAmount: import("@prisma/client/runtime/library").Decimal | null;
                maintenanceAmount: import("@prisma/client/runtime/library").Decimal | null;
                billingSince: Date | null;
            }[];
        } & {
            id: string;
            name: string;
            societyId: string;
            letter: string;
        })[];
        id: string;
        updatedAt: Date;
        name: string;
        logoUrl: string | null;
        createdAt: Date;
        address: string;
        city: string | null;
        state: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
        plan: import(".prisma/client").$Enums.SubscriptionPlan;
        planExpiresAt: Date | null;
        suspended: boolean;
    }>;
    findOne(id: string): Promise<{
        stats: {
            towers: number;
            flats: number;
            minFloors: number;
            maxFloors: number;
        };
        towers: ({
            flats: {
                number: string;
                id: string;
                societyId: string;
                towerId: string;
                floor: number;
                rentAmount: import("@prisma/client/runtime/library").Decimal | null;
                maintenanceAmount: import("@prisma/client/runtime/library").Decimal | null;
                billingSince: Date | null;
            }[];
        } & {
            id: string;
            name: string;
            societyId: string;
            letter: string;
        })[];
        id: string;
        updatedAt: Date;
        name: string;
        logoUrl: string | null;
        createdAt: Date;
        address: string;
        city: string | null;
        state: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
        plan: import(".prisma/client").$Enums.SubscriptionPlan;
        planExpiresAt: Date | null;
        suspended: boolean;
    }>;
    flats(id: string): Promise<{
        number: string;
        id: string;
        towerId: string;
        floor: number;
    }[]>;
}
