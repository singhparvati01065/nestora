import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { readFileSync } from 'fs';
import { PrismaService } from '../prisma/prisma.service';

/// What a push carries beyond its text — the app uses it to decide where to
/// open. Keep the keys short: FCM data values must be strings.
export type PushData = Record<string, string>;

/**
 * Sends FCM messages to a user's devices.
 *
 * Sending needs a service account, unlike verifying ID tokens (which only
 * needs Google's public certs — see FirebaseAdminService). Point
 * `FIREBASE_SERVICE_ACCOUNT` at the JSON key file, or paste the JSON itself
 * into the variable. With neither, pushes are skipped and said so out loud
 * rather than silently pretending to deliver.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private readonly app: App | null;

  constructor(
    private prisma: PrismaService,
    config: ConfigService,
  ) {
    this.app = this.initApp(config);
    if (!this.app) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT is not set — push notifications are disabled.',
      );
    }
  }

  /// True when a service account is configured and pushes can actually go out.
  get enabled(): boolean {
    return this.app !== null;
  }

  private initApp(config: ConfigService): App | null {
    const raw = config.get<string>('FIREBASE_SERVICE_ACCOUNT');
    if (!raw) return null;
    try {
      // Either the JSON itself or a path to the key file.
      const json = raw.trimStart().startsWith('{')
        ? raw
        : readFileSync(raw, 'utf8');
      const account = JSON.parse(json);
      const existing = getApps().find((a) => a.name === 'nestora-push');
      return (
        existing ??
        initializeApp({ credential: cert(account) }, 'nestora-push')
      );
    } catch (e) {
      this.logger.error(
        `Could not read FIREBASE_SERVICE_ACCOUNT: ${(e as Error).message}`,
      );
      return null;
    }
  }

  /// Pushes to every device of every listed user. Returns how many devices
  /// accepted it. Never throws — a failed push must not fail the action that
  /// triggered it.
  async sendToUsers(
    userIds: string[],
    title: string,
    body: string,
    data: PushData = {},
  ): Promise<number> {
    if (!this.app || userIds.length === 0) return 0;

    const devices = await this.prisma.deviceToken.findMany({
      where: { userId: { in: userIds } },
      select: { token: true },
    });
    if (devices.length === 0) return 0;

    const tokens = devices.map((d) => d.token);
    try {
      const res = await getMessaging(this.app).sendEachForMulticast({
        tokens,
        notification: { title, body },
        data,
        android: { priority: 'high' },
      });

      // A token FCM rejects as unregistered belongs to an app that was
      // uninstalled or reinstalled; keeping it only slows future sends.
      const dead: string[] = [];
      res.responses.forEach((r, i) => {
        const code = (r.error as { code?: string } | undefined)?.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/invalid-argument'
        ) {
          dead.push(tokens[i]);
        }
      });
      if (dead.length) {
        await this.prisma.deviceToken
          .deleteMany({ where: { token: { in: dead } } })
          .catch(() => null);
      }
      return res.successCount;
    } catch (e) {
      this.logger.error(`Push failed: ${(e as Error).message}`);
      return 0;
    }
  }

  /// Pushes to the admins of the given societies — the people who act on
  /// payments, replies and platform notices.
  async sendToSocietyAdmins(
    societyIds: string[],
    title: string,
    body: string,
    data: PushData = {},
  ): Promise<number> {
    if (!this.app || societyIds.length === 0) return 0;
    const admins = await this.prisma.user.findMany({
      where: {
        societyId: { in: societyIds },
        role: 'SOCIETY_ADMIN',
        banned: false,
        archivedAt: null,
      },
      select: { id: true },
    });
    return this.sendToUsers(
      admins.map((a) => a.id),
      title,
      body,
      data,
    );
  }
}
