import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AuthUser } from '../auth/decorators/current-user.decorator';

/// Resolves the society a request operates on. Society-scoped roles use their
/// own societyId from the JWT; a super admin must pass one explicitly.
export function resolveSocietyId(user: AuthUser, explicit?: string): string {
  if (user.role === Role.SUPER_ADMIN) {
    if (!explicit) {
      throw new BadRequestException('societyId is required for super admin');
    }
    return explicit;
  }
  if (!user.societyId) {
    throw new ForbiddenException('No society associated with this account');
  }
  return user.societyId;
}
