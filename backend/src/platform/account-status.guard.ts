import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { AuthUser } from '../auth/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { applyPlanExpiry } from './plan';

/// How long an account's standing is reused before it is read again. A ban or
/// a suspension takes effect within this window without adding a database
/// round-trip to every single request.
const TTL_MS = 15_000;

/// Keeps the cache from growing without bound on a long-lived process.
const MAX_ENTRIES = 5_000;

type Status = { blocked: string | null; missing: boolean };

/// A JWT stays valid for its full lifetime, so the token alone cannot say
/// whether the account behind it is still allowed in. This re-checks, per
/// request, that the user has not been banned or removed and that their
/// society has not been suspended from the super-admin panel — and lets an
/// expired premium plan lapse while the society is in hand.
@Injectable()
export class AccountStatusGuard implements CanActivate {
  private cache = new Map<string, { at: number; status: Status }>();

  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const user = context.switchToHttp().getRequest().user as
      | AuthUser
      | undefined;
    // Public routes carry no user; there is nothing to re-check.
    if (!user?.sub) return true;
    // The super admin lives outside societies and is managed in the panel.
    if (user.role === Role.SUPER_ADMIN) return true;

    const status = await this.statusOf(user.sub);
    if (status.missing) throw new UnauthorizedException('Account not found');
    if (status.blocked) throw new ForbiddenException(status.blocked);
    return true;
  }

  private async statusOf(userId: string): Promise<Status> {
    const hit = this.cache.get(userId);
    if (hit && Date.now() - hit.at < TTL_MS) return hit.status;

    const status = await this.load(userId);
    if (this.cache.size >= MAX_ENTRIES) this.cache.clear();
    this.cache.set(userId, { at: Date.now(), status });
    return status;
  }

  private async load(userId: string): Promise<Status> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        banned: true,
        archivedAt: true,
        society: {
          select: {
            id: true,
            suspended: true,
            plan: true,
            planExpiresAt: true,
          },
        },
      },
    });
    if (!user) return { blocked: null, missing: true };
    if (user.banned) {
      return { blocked: 'This account has been blocked.', missing: false };
    }
    if (user.archivedAt) {
      return {
        blocked: 'This account has been removed. Ask your society admin.',
        missing: false,
      };
    }
    if (user.society) {
      if (user.society.suspended) {
        return {
          blocked:
            'This society has been suspended. Please contact Nestora support.',
          missing: false,
        };
      }
      await applyPlanExpiry(this.prisma, user.society);
    }
    return { blocked: null, missing: false };
  }
}
