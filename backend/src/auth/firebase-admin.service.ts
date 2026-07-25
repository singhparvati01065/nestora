import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

/// A verified Firebase phone-OTP identity.
export interface FirebaseIdentity {
  uid: string;
  phone: string;
}

/**
 * Verifies Firebase ID tokens.
 *
 * Only the project id is configured — no service account key. Verification just
 * checks Google's public signing certs, which the SDK fetches over HTTPS, so
 * there is no secret to store. Minting custom tokens WOULD need a key; we don't.
 */
@Injectable()
export class FirebaseAdminService {
  private readonly logger = new Logger(FirebaseAdminService.name);
  private readonly app: App;

  constructor(config: ConfigService) {
    const projectId = config.get<string>('FIREBASE_PROJECT_ID');
    if (!projectId) {
      throw new Error('FIREBASE_PROJECT_ID is not set — see backend/.env');
    }
    // Nest can instantiate this more than once (tests, hot reload) but the
    // Firebase SDK throws on a duplicate app name.
    this.app =
      getApps().find((a) => a.name === 'nestora') ??
      initializeApp({ projectId }, 'nestora');
  }

  /// Verifies [idToken] and returns the phone identity it proves.
  ///
  /// `checkRevoked` is on so a signed-out or disabled user cannot keep using a
  /// token that has not expired yet.
  async verify(idToken: string): Promise<FirebaseIdentity> {
    let decoded;
    try {
      decoded = await getAuth(this.app).verifyIdToken(idToken, true);
    } catch (e) {
      this.logger.warn(`Rejected Firebase ID token: ${(e as Error).message}`);
      throw new UnauthorizedException('Invalid Firebase token');
    }

    // A token minted by any other provider (or with phone auth misconfigured)
    // has no phone_number, and this endpoint's whole contract is phone identity.
    const phone = decoded.phone_number;
    if (!phone) {
      throw new UnauthorizedException('Firebase token has no phone number');
    }
    return { uid: decoded.uid, phone };
  }
}
