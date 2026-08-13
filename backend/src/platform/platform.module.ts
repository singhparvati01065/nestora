import { Controller, Get, Global, Module } from '@nestjs/common';
import { Public } from '../auth/decorators/public.decorator';
import { FeatureFlagsService } from './feature-flags.service';

@Controller('feature-flags')
class FeatureFlagsController {
  constructor(private flags: FeatureFlagsService) {}

  /// The platform's module switches, as `{ key: enabled }`. The app reads this
  /// on launch to hide what the super admin has turned off — the API refuses
  /// those routes regardless, via @RequiresFeature. Public, because the app
  /// needs it before a session exists.
  @Public()
  @Get()
  all() {
    return this.flags.all();
  }
}

/// Platform-level concerns owned by the super-admin panel: feature flags,
/// account standing (ban / suspension) and subscription expiry.
@Global()
@Module({
  controllers: [FeatureFlagsController],
  providers: [FeatureFlagsService],
  exports: [FeatureFlagsService],
})
export class PlatformModule {}
