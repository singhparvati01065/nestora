import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateMeDto } from './dto/update-me.dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  /// Applies only the fields actually sent, so a name-only edit cannot wipe the
  /// photo. An explicit `photoUrl: null` still clears it.
  async updateMe(userId: string, dto: UpdateMeDto) {
    const data: Prisma.UserUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.photoUrl !== undefined) data.photoUrl = dto.photoUrl;
    if (dto.trades !== undefined) data.trades = dto.trades;

    const user = await this.prisma.user.update({
      where: { id: userId },
      data,
    });
    const { password: _pw, ...safe } = user;
    return safe;
  }

  /// Deletes your own account, as Play requires every app with accounts to
  /// offer.
  ///
  /// The row is kept but emptied: bills, complaints and gate entries reference
  /// it, and wiping those would rewrite a society's records rather than close
  /// one person's account. What identifies the person — name, photo, phone,
  /// address, salary — is removed, the phone is released so the number can be
  /// registered again, and the account can no longer sign in.
  ///
  /// A society admin cannot do this from the app: their account owns the
  /// society, and deleting it would take every resident's data with it. They
  /// are told to raise it with support instead.
  async deleteMe(userId: string, role: Role) {
    if (role === Role.SOCIETY_ADMIN) {
      throw new ForbiddenException(
        'A society admin account cannot be deleted from the app, because the ' +
          'whole society is attached to it. Raise a support ticket and we will ' +
          'handle it with you.',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      // Push must stop immediately — the account is gone.
      await tx.deviceToken.deleteMany({ where: { userId } });
      await tx.user.update({
        where: { id: userId },
        data: {
          name: 'Deleted account',
          // Keeps the unique constraint happy while freeing the real number.
          phone: `deleted-${userId}`,
          email: null,
          password: null,
          firebaseUid: null,
          photoUrl: null,
          address: null,
          salary: null,
          trades: [],
          flatId: null,
          archivedAt: new Date(),
          banned: true,
        },
      });
    });

    return { deleted: true };
  }
}
