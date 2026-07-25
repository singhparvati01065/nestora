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
            societyId: string;
            name: string;
            letter: string;
        })[];
        id: string;
        name: string;
        createdAt: Date;
        address: string;
        updatedAt: Date;
        logoUrl: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
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
            societyId: string;
            name: string;
            letter: string;
        })[];
        id: string;
        name: string;
        createdAt: Date;
        address: string;
        updatedAt: Date;
        logoUrl: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
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
            societyId: string;
            name: string;
            letter: string;
        })[];
        id: string;
        name: string;
        createdAt: Date;
        address: string;
        updatedAt: Date;
        logoUrl: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
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
            societyId: string;
            name: string;
            letter: string;
        })[];
        id: string;
        name: string;
        createdAt: Date;
        address: string;
        updatedAt: Date;
        logoUrl: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
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
            societyId: string;
            name: string;
            letter: string;
        })[];
        id: string;
        name: string;
        createdAt: Date;
        address: string;
        updatedAt: Date;
        logoUrl: string | null;
        hasTowers: boolean;
        monthlyMaintenance: import("@prisma/client/runtime/library").Decimal | null;
        maintenanceSince: Date | null;
    }>;
    flats(id: string): Promise<{
        number: string;
        id: string;
        towerId: string;
        floor: number;
    }[]>;
}
