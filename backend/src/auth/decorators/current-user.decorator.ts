import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Role } from '@prisma/client';

export interface AuthUser {
  sub: string;
  phone: string;
  name: string;
  /// Carried so the client can render the avatar straight after sign-in. It can
  /// go stale inside a long-lived JWT — the client refreshes it from the
  /// PATCH /users/me response, which is the authority.
  photoUrl: string | null;
  role: Role;
  societyId: string | null;
  flatId: string | null;
  staffLabel: string | null;
  trades: string[];
}

/// Injects the authenticated user (JWT payload) into a controller handler.
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthUser => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);
