import { SetMetadata } from '@nestjs/common';

export const FEATURE_KEY = 'feature';

/// Marks a controller (or a single route) as belonging to a platform feature
/// flag. When the super-admin panel turns that flag off, every route under it
/// answers 403 instead of running.
export const RequiresFeature = (key: string) => SetMetadata(FEATURE_KEY, key);
