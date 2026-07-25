import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
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
}
