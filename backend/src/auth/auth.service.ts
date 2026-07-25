import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from './decorators/current-user.decorator';
import {
  DevLoginDto,
  FirebaseLoginDto,
  LoginDto,
  RegisterDto,
} from './dto/auth.dto';
import { FirebaseAdminService } from './firebase-admin.service';

/// Firebase reports E.164 (`+919876543210`); `User.phone` holds the 10-digit
/// local form the app has always sent (`9876543210`). Without this the two
/// never match and every OTP login would fork a duplicate user.
export function toLocalPhone(e164: string): string {
  const digits = e164.replace(/\D/g, '');
  return digits.length > 10 ? digits.slice(-10) : digits;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private firebase: FirebaseAdminService,
  ) {}

  private tokenFor(user: AuthUser) {
    return this.jwt.sign(user);
  }

  private toAuthUser(u: {
    id: string;
    phone: string;
    name: string;
    photoUrl: string | null;
    role: any;
    societyId: string | null;
    flatId: string | null;
    staffLabel: string | null;
    trades: string[];
  }): AuthUser {
    return {
      sub: u.id,
      phone: u.phone,
      name: u.name,
      photoUrl: u.photoUrl,
      role: u.role,
      societyId: u.societyId,
      flatId: u.flatId,
      staffLabel: u.staffLabel,
      trades: u.trades,
    };
  }

  async register(dto: RegisterDto) {
    // Self-registration is for society admins only; residents / staff accounts
    // are created by an admin, not signed up.
    if (dto.role !== Role.SOCIETY_ADMIN) {
      throw new ForbiddenException(
        'Only society admins can create an account. Ask your admin to add you.',
      );
    }
    const existing = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });
    if (existing) throw new ConflictException('Phone already registered');

    const password = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        phone: dto.phone,
        password,
        name: dto.name,
        role: dto.role,
        societyId: dto.societyId ?? null,
        flatId: dto.flatId ?? null,
        staffLabel: dto.staffLabel ?? null,
      },
    });

    const authUser = this.toAuthUser(user);
    return { accessToken: this.tokenFor(authUser), user: authUser };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });
    if (!user) throw new UnauthorizedException('Invalid credentials');
    // An OTP-only user has no password to compare against.
    if (!user.password) throw new UnauthorizedException('Invalid credentials');

    const ok = await bcrypt.compare(dto.password, user.password);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    const authUser = this.toAuthUser(user);
    return { accessToken: this.tokenFor(authUser), user: authUser };
  }

  /**
   * Exchanges a verified Firebase phone-OTP token for a Nestora JWT.
   *
   * Matching is by phone, not by uid, so an OTP login lands on the user that
   * already exists for that number (the seeded accounts included) and adopts
   * its role from the database rather than trusting the client.
   */
  async firebaseLogin(dto: FirebaseLoginDto) {
    const identity = await this.firebase.verify(dto.idToken);
    const phone = toLocalPhone(identity.phone);

    const existing = await this.prisma.user.findUnique({ where: { phone } });

    if (existing) {
      // A removed (archived) account can't sign back in until re-added.
      if (existing.archivedAt) {
        throw new ForbiddenException(
          'This account has been removed. Ask your society admin.',
        );
      }
      // Someone else's row already claims this uid, or this row is bound to a
      // different one — either way the number is not safely ours to hand over.
      if (existing.firebaseUid && existing.firebaseUid !== identity.uid) {
        throw new UnauthorizedException('Phone is linked to another account');
      }
      const user = existing.firebaseUid
        ? existing
        : await this.prisma.user.update({
            where: { id: existing.id },
            data: { firebaseUid: identity.uid },
          });
      const authUser = this.toAuthUser(user);
      return { accessToken: this.tokenFor(authUser), user: authUser };
    }

    // First time this number is seen. Only a society admin may create their own
    // account here; residents / staff are added by their admin (which creates
    // their account), then they simply log in — never self-register.
    if (dto.role !== Role.SOCIETY_ADMIN) {
      throw new ForbiddenException(
        'No account for this number. Ask your society admin to register you.',
      );
    }
    const created = await this.prisma.user.create({
      data: {
        phone,
        firebaseUid: identity.uid,
        name: dto.name?.trim() || 'Member',
        role: Role.SOCIETY_ADMIN,
        trades: [],
      },
    });
    const authUser = this.toAuthUser(created);
    return { accessToken: this.tokenFor(authUser), user: authUser };
  }

  /**
   * TEMPORARY — issues a JWT for any phone number, with NO verification.
   *
   * This exists only so the app's role flows can be built before phone auth is
   * enabled in the Firebase console. Anyone who can reach this route can sign
   * in as anyone, including SOCIETY_ADMIN, so it is fenced twice: it refuses
   * unless DEV_LOGIN_ENABLED is set, and always refuses in production.
   *
   * Delete this method, its route, its DTO, and DEV_LOGIN_ENABLED once
   * /auth/firebase works end to end.
   */
  async devLogin(dto: DevLoginDto) {
    if (
      process.env.NODE_ENV === 'production' ||
      process.env.DEV_LOGIN_ENABLED !== 'true'
    ) {
      throw new NotFoundException('Cannot POST /api/auth/dev-login');
    }
    this.logger.warn(
      `DEV LOGIN — issuing an unverified token for ${dto.phone}. ` +
        'This must never be reachable outside local development.',
    );

    const phone = toLocalPhone(dto.phone);
    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing?.archivedAt) {
      throw new ForbiddenException(
        'This account has been removed. Ask your society admin.',
      );
    }
    // Same rule as real login: only a society admin may self-register; everyone
    // else must already have an account (created by their admin) and just logs in.
    if (!existing && dto.role !== Role.SOCIETY_ADMIN) {
      throw new ForbiddenException(
        'No account for this number. Ask your society admin to register you.',
      );
    }
    const user =
      existing ??
      (await this.prisma.user.create({
        data: {
          phone,
          name: dto.name?.trim() || 'Member',
          role: Role.SOCIETY_ADMIN,
          trades: [],
        },
      }));

    const authUser = this.toAuthUser(user);
    return { accessToken: this.tokenFor(authUser), user: authUser };
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { society: true, flat: true },
    });
    if (!user) throw new UnauthorizedException();
    const { password: _pw, ...safe } = user;
    return safe;
  }

  /// Re-issues the token from the current DB row. Needed after something changes
  /// a claim baked into the JWT — e.g. an admin creating their first society,
  /// which sets `societyId` that the old token still has as null.
  async refresh(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();
    const authUser = this.toAuthUser(user);
    return { accessToken: this.tokenFor(authUser), user: authUser };
  }
}
