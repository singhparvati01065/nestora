import { Role } from '@prisma/client';
import {
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';


export class RegisterDto {
  @IsString()
  @MinLength(10)
  phone: string;

  @IsString()
  @MinLength(4)
  password: string;

  @IsString()
  name: string;

  @IsEnum(Role)
  role: Role;

  @IsOptional()
  @IsString()
  societyId?: string;

  @IsOptional()
  @IsString()
  flatId?: string;

  @IsOptional()
  @IsString()
  staffLabel?: string;
}

export class LoginDto {
  @IsString()
  phone: string;

  @IsString()
  password: string;
}

/// TEMPORARY — signs in as [phone] with no proof of ownership at all.
/// Only exists so the app can be built while Firebase phone auth is not yet
/// enabled in the console. See `AuthService.devLogin`.
export class DevLoginDto {
  @IsString()
  @MinLength(10)
  phone: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  trades?: string[];
}

/// Exchanges a Firebase phone-OTP ID token for a Nestora JWT.
///
/// `name`/`role` are only read when the phone has never been seen before — an
/// existing user's stored name and role always win, so a client cannot
/// re-role itself by replaying signup.
export class FirebaseLoginDto {
  @IsString()
  idToken: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  trades?: string[];
}
