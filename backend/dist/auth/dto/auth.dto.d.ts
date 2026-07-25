import { Role } from '@prisma/client';
export declare class RegisterDto {
    phone: string;
    password: string;
    name: string;
    role: Role;
    societyId?: string;
    flatId?: string;
    staffLabel?: string;
}
export declare class LoginDto {
    phone: string;
    password: string;
}
export declare class DevLoginDto {
    phone: string;
    name?: string;
    role?: Role;
    trades?: string[];
}
export declare class FirebaseLoginDto {
    idToken: string;
    name?: string;
    role?: Role;
    trades?: string[];
}
