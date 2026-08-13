import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { AppVersionModule } from './app-version/app-version.module';
import { AmenitiesModule } from './amenities/amenities.module';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { RolesGuard } from './auth/guards/roles.guard';
import { BillsModule } from './bills/bills.module';
import { ContentModule } from './content/content.module';
import { ComplaintsModule } from './complaints/complaints.module';
import { DeliveriesModule } from './gate/deliveries.module';
import { PreApprovedModule } from './gate/pre-approved.module';
import { VisitorsModule } from './gate/visitors.module';
import { NoticesModule } from './notices/notices.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AccountStatusGuard } from './platform/account-status.guard';
import { FeatureGuard } from './platform/feature.guard';
import { PlatformModule } from './platform/platform.module';
import { PrismaModule } from './prisma/prisma.module';
import { PushModule } from './push/push.module';
import { ResidentsModule } from './residents/residents.module';
import { SocietiesModule } from './societies/societies.module';
import { StaffModule } from './staff/staff.module';
import { SupportModule } from './support/support.module';
import { UploadsModule } from './uploads/uploads.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    PlatformModule,
    PushModule,
    AuthModule,
    SocietiesModule,
    UploadsModule,
    UsersModule,
    ResidentsModule,
    StaffModule,
    SupportModule,
    NoticesModule,
    NotificationsModule,
    BillsModule,
    ComplaintsModule,
    VisitorsModule,
    PreApprovedModule,
    DeliveriesModule,
    AmenitiesModule,
    AppVersionModule,
    ContentModule,
  ],
  providers: [
    // Global auth: every route needs a valid JWT unless @Public().
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    // Global RBAC: @Roles(...) is enforced after authentication.
    { provide: APP_GUARD, useClass: RolesGuard },
    // A valid token is not enough: the account must still be in good standing
    // and its society must not be suspended.
    { provide: APP_GUARD, useClass: AccountStatusGuard },
    // Modules switched off in the super-admin panel are closed here too.
    { provide: APP_GUARD, useClass: FeatureGuard },
  ],
})
export class AppModule {}
