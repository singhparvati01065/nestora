import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { readFileSync } from 'fs';

/// A verified Firebase phone-OTP identity.
export interface FirebaseIdentity {
  uid: string;
  phone: string;
}

/**
 * Verifies Firebase ID tokens.
 *
 * Checking a token's signature needs nothing but Google's public certs. Asking
 * whether it has been *revoked* is an API call, and that needs credentials —
 * so when `FIREBASE_SERVICE_ACCOUNT` is configured this app is built with it
 * and the revocation check stays on. Without a key the app still verifies
 * signature, expiry, issuer and audience; it just cannot see a revocation.
 * That is a fair trade for local development, and it is loud in the log rather
 * than silently downgraded.
 */
@Injectable()
export class FirebaseAdminService {
  private readonly logger = new Logger(FirebaseAdminService.name);
  private readonly app: App;

  /// Whether revocation can be checked — false when there is no service account.
  private readonly hasCredential: boolean;

  constructor(config: ConfigService) {
    const projectId = config.get<string>('FIREBASE_PROJECT_ID');
    if (!projectId) {
      throw new Error('FIREBASE_PROJECT_ID is not set — see backend/.env');
    }

    const account = this.readServiceAccount(config);
    this.hasCredential = account !== null;
    if (!this.hasCredential) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT is not set — ID tokens will be verified ' +
          'without the revocation check.',
      );
    }

    // Nest can instantiate this more than once (tests, hot reload) but the
    // Firebase SDK throws on a duplicate app name.
    this.app =
      getApps().find((a) => a.name === 'nestora') ??
      initializeApp(
        account ? { projectId, credential: cert(account) } : { projectId },
        'nestora',
      );
  }

  /// The key file, or the JSON pasted straight into the variable.
  private readServiceAccount(config: ConfigService): Record<
    string,
    unknown
  > | null {
    const raw = config.get<string>('FIREBASE_SERVICE_ACCOUNT');
    if (!raw) return null;
    try {
      const json = raw.trimStart().startsWith('{')
        ? raw
        : readFileSync(raw, 'utf8');
      return JSON.parse(json) as Record<string, unknown>;
    } catch (e) {
      this.logger.error(
        `Could not read FIREBASE_SERVICE_ACCOUNT: ${(e as Error).message}`,
      );
      return null;
    }
  }

  /// Verifies [idToken] and returns the phone identity it proves.
  async verify(idToken: string): Promise<FirebaseIdentity> {
    let decoded;
    try {
      decoded = await getAuth(this.app).verifyIdToken(
        idToken,
        this.hasCredential,
      );
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
