import { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { FeatureFlagsService } from './feature-flags.service';
export declare class FeatureGuard implements CanActivate {
    private reflector;
    private flags;
    constructor(reflector: Reflector, flags: FeatureFlagsService);
    canActivate(context: ExecutionContext): Promise<boolean>;
}
