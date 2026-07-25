import { Role } from '@prisma/client';
export interface AuthUser {
    sub: string;
    phone: string;
    name: string;
    photoUrl: string | null;
    role: Role;
    societyId: string | null;
    flatId: string | null;
    staffLabel: string | null;
    trades: string[];
}
export declare const CurrentUser: (...dataOrPipes: unknown[]) => ParameterDecorator;
