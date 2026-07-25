import { Prisma } from '@prisma/client';
import { AuthUser } from '../auth/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSocietyDto } from './dto/create-society.dto';
import { UpdateSocietyDto } from './dto/update-society.dto';
import { UpdateSocietyProfileDto } from './dto/update-society-profile.dto';
export declare class SocietiesService {
    private prisma;
    constructor(prisma: PrismaService);
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
                rentAmount: Prisma.Decimal | null;
                maintenanceAmount: Prisma.Decimal | null;
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
        monthlyMaintenance: Prisma.Decimal | null;
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
                rentAmount: Prisma.Decimal | null;
                maintenanceAmount: Prisma.Decimal | null;
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
        monthlyMaintenance: Prisma.Decimal | null;
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
                rentAmount: Prisma.Decimal | null;
                maintenanceAmount: Prisma.Decimal | null;
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
        monthlyMaintenance: Prisma.Decimal | null;
        maintenanceSince: Date | null;
    }>;
    private impactOf;
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
                rentAmount: Prisma.Decimal | null;
                maintenanceAmount: Prisma.Decimal | null;
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
        monthlyMaintenance: Prisma.Decimal | null;
        maintenanceSince: Date | null;
    }>;
    flats(societyId: string): Promise<{
        number: string;
        id: string;
        towerId: string;
        floor: number;
    }[]>;
}
