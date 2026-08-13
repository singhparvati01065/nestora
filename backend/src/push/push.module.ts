import {
  Body,
  Controller,
  Delete,
  Global,
  Headers,
  Module,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IsArray, IsOptional, IsString } from 'class-validator';
import { Public } from '../auth/decorators/public.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../auth/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from './push.service';

class RegisterDeviceDto {
  @IsString() token: string;
  @IsOptional() @IsString() platform?: string;
}

class UnregisterDeviceDto {
  @IsString() token: string;
}

class InternalPushDto {
  @IsArray() @IsString({ each: true }) societyIds: string[];
  @IsString() title: string;
  @IsString() body: string;
}

@Controller('devices')
class DevicesController {
  constructor(
    private prisma: PrismaService,
    private push: PushService,
  ) {}

  /// Registers this install's FCM token against the signed-in user.
  ///
  /// Upserts on the token, not on the user: a phone that changes hands must
  /// follow its new owner rather than keep delivering their notifications to
  /// the previous one.
  @Post()
  async register(
    @CurrentUser() user: AuthUser,
    @Body() dto: RegisterDeviceDto,
  ) {
    const token = dto.token.trim();
    if (!token) return { ok: false };
    await this.prisma.deviceToken.upsert({
      where: { token },
      update: { userId: user.sub, platform: dto.platform ?? null },
      create: { token, userId: user.sub, platform: dto.platform ?? null },
    });
    return { ok: true, pushEnabled: this.push.enabled };
  }

  /// Drops the token on sign-out, so the next person on this phone does not
  /// receive the last one's notifications.
  @Delete()
  async unregister(
    @CurrentUser() user: AuthUser,
    @Body() dto: UnregisterDeviceDto,
  ) {
    await this.prisma.deviceToken
      .deleteMany({ where: { token: dto.token, userId: user.sub } })
      .catch(() => null);
    return { ok: true };
  }
}

/**
 * Lets the super-admin panel send a push without holding Firebase credentials
 * of its own: it posts here with a shared key, and this service does the
 * sending. Public to the JWT guard because the caller is a service, not a
 * user — the key is the whole authentication.
 */
@Controller('internal/push')
class InternalPushController {
  constructor(
    private push: PushService,
    private config: ConfigService,
  ) {}

  @Public()
  @Post()
  async send(
    @Headers('x-internal-key') key: string,
    @Body() dto: InternalPushDto,
  ) {
    const expected = this.config.get<string>('INTERNAL_API_KEY');
    if (!expected || key !== expected) {
      throw new UnauthorizedException('Bad internal key');
    }
    const sent = await this.push.sendToSocietyAdmins(
      dto.societyIds,
      dto.title,
      dto.body,
    );
    return { sent, enabled: this.push.enabled };
  }
}

/// Push delivery, available to any module that needs to notify someone.
@Global()
@Module({
  controllers: [DevicesController, InternalPushController],
  providers: [PushService],
  exports: [PushService],
})
export class PushModule {}
