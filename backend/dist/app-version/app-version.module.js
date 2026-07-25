"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppVersionModule = void 0;
const common_1 = require("@nestjs/common");
const public_decorator_1 = require("../auth/decorators/public.decorator");
const prisma_service_1 = require("../prisma/prisma.service");
let AppVersionController = class AppVersionController {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async get() {
        const [cfg, settings] = await Promise.all([
            this.prisma.appConfig.upsert({
                where: { id: 'app' },
                update: {},
                create: { id: 'app' },
            }),
            this.prisma.platformSettings.findUnique({ where: { id: 'main' } }),
        ]);
        return {
            androidVersion: cfg.androidVersion,
            iosVersion: cfg.iosVersion,
            forceUpdate: cfg.forceUpdate,
            releaseNotes: cfg.releaseNotes,
            maintenanceMode: settings?.maintenanceMode ?? false,
            appName: settings?.appName ?? 'Nestora',
        };
    }
};
__decorate([
    (0, public_decorator_1.Public)(),
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], AppVersionController.prototype, "get", null);
AppVersionController = __decorate([
    (0, common_1.Controller)('app-version'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], AppVersionController);
let AppVersionModule = class AppVersionModule {
};
exports.AppVersionModule = AppVersionModule;
exports.AppVersionModule = AppVersionModule = __decorate([
    (0, common_1.Module)({ controllers: [AppVersionController] })
], AppVersionModule);
//# sourceMappingURL=app-version.module.js.map