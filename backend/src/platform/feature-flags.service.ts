import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/// How long a read of the flag table is reused. The super-admin panel is a
/// separate process writing the same database, so a toggle there takes effect
/// here within this window.
const TTL_MS = 30_000;

/// Platform-wide feature toggles, owned by the super-admin panel.
///
/// Unknown keys read as enabled: a flag row that was never seeded must not
/// silently switch a working module off.
@Injectable()
export class FeatureFlagsService {
  private cache: Record<string, boolean> = {};
  private loadedAt = 0;
  private inFlight: Promise<Record<string, boolean>> | null = null;

  constructor(private prisma: PrismaService) {}

  async all(): Promise<Record<string, boolean>> {
    if (Date.now() - this.loadedAt < TTL_MS) return this.cache;
    // Collapse the stampede when several requests miss the cache together.
    this.inFlight ??= this.load().finally(() => {
      this.inFlight = null;
    });
    return this.inFlight;
  }

  async isEnabled(key: string): Promise<boolean> {
    const flags = await this.all();
    return flags[key] ?? true;
  }

  private async load(): Promise<Record<string, boolean>> {
    try {
      const rows = await this.prisma.featureFlag.findMany({
        select: { key: true, enabled: true },
      });
      this.cache = Object.fromEntries(rows.map((r) => [r.key, r.enabled]));
      this.loadedAt = Date.now();
    } catch {
      // Keep serving the last known flags rather than failing every request.
    }
    return this.cache;
  }
}
