"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const core_1 = require("@nestjs/core");
const app_version_module_1 = require("./app-version/app-version.module");
const amenities_module_1 = require("./amenities/amenities.module");
const auth_module_1 = require("./auth/auth.module");
const jwt_auth_guard_1 = require("./auth/guards/jwt-auth.guard");
const roles_guard_1 = require("./auth/guards/roles.guard");
const bills_module_1 = require("./bills/bills.module");
const content_module_1 = require("./content/content.module");
const complaints_module_1 = require("./complaints/complaints.module");
const deliveries_module_1 = require("./gate/deliveries.module");
const pre_approved_module_1 = require("./gate/pre-approved.module");
const visitors_module_1 = require("./gate/visitors.module");
const notices_module_1 = require("./notices/notices.module");
const notifications_module_1 = require("./notifications/notifications.module");
const prisma_module_1 = require("./prisma/prisma.module");
const residents_module_1 = require("./residents/residents.module");
const societies_module_1 = require("./societies/societies.module");
const staff_module_1 = require("./staff/staff.module");
const support_module_1 = require("./support/support.module");
const uploads_module_1 = require("./uploads/uploads.module");
const users_module_1 = require("./users/users.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({ isGlobal: true }),
            prisma_module_1.PrismaModule,
            auth_module_1.AuthModule,
            societies_module_1.SocietiesModule,
            uploads_module_1.UploadsModule,
            users_module_1.UsersModule,
            residents_module_1.ResidentsModule,
            staff_module_1.StaffModule,
            support_module_1.SupportModule,
            notices_module_1.NoticesModule,
            notifications_module_1.NotificationsModule,
            bills_module_1.BillsModule,
            complaints_module_1.ComplaintsModule,
            visitors_module_1.VisitorsModule,
            pre_approved_module_1.PreApprovedModule,
            deliveries_module_1.DeliveriesModule,
            amenities_module_1.AmenitiesModule,
            app_version_module_1.AppVersionModule,
            content_module_1.ContentModule,
        ],
        providers: [
            { provide: core_1.APP_GUARD, useClass: jwt_auth_guard_1.JwtAuthGuard },
            { provide: core_1.APP_GUARD, useClass: roles_guard_1.RolesGuard },
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map