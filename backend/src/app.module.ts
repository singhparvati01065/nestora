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
import { PrismaModule } from './prisma/prisma.module';
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
  ],
})
export class AppModule {}
