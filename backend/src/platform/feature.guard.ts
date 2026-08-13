import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { FEATURE_KEY } from './feature.decorator';
import { FeatureFlagsService } from './feature-flags.service';

/// Enforces @RequiresFeature(...) — a module switched off in the super-admin
/// panel is closed at the API too, not just hidden in the app.
@Injectable()
export class FeatureGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private flags: FeatureFlagsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const key = this.reflector.getAllAndOverride<string>(FEATURE_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!key) return true;
    if (await this.flags.isEnabled(key)) return true;
    throw new ForbiddenException(
      'This feature is currently unavailable. Please try again later.',
    );
  }
}
