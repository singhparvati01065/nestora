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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PushModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const class_validator_1 = require("class-validator");
const public_decorator_1 = require("../auth/decorators/public.decorator");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const prisma_service_1 = require("../prisma/prisma.service");
const push_service_1 = require("./push.service");
class RegisterDeviceDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RegisterDeviceDto.prototype, "token", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RegisterDeviceDto.prototype, "platform", void 0);
class UnregisterDeviceDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UnregisterDeviceDto.prototype, "token", void 0);
class InternalPushDto {
}
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], InternalPushDto.prototype, "societyIds", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], InternalPushDto.prototype, "title", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], InternalPushDto.prototype, "body", void 0);
let DevicesController = class DevicesController {
    constructor(prisma, push) {
        this.prisma = prisma;
        this.push = push;
    }
    async register(user, dto) {
        const token = dto.token.trim();
        if (!token)
            return { ok: false };
        await this.prisma.deviceToken.upsert({
            where: { token },
            update: { userId: user.sub, platform: dto.platform ?? null },
            create: { token, userId: user.sub, platform: dto.platform ?? null },
        });
        return { ok: true, pushEnabled: this.push.enabled };
    }
    async unregister(user, dto) {
        await this.prisma.deviceToken
            .deleteMany({ where: { token: dto.token, userId: user.sub } })
            .catch(() => null);
        return { ok: true };
    }
};
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, RegisterDeviceDto]),
    __metadata("design:returntype", Promise)
], DevicesController.prototype, "register", null);
__decorate([
    (0, common_1.Delete)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, UnregisterDeviceDto]),
    __metadata("design:returntype", Promise)
], DevicesController.prototype, "unregister", null);
DevicesController = __decorate([
    (0, common_1.Controller)('devices'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        push_service_1.PushService])
], DevicesController);
let InternalPushController = class InternalPushController {
    constructor(push, config) {
        this.push = push;
        this.config = config;
    }
    async send(key, dto) {
        const expected = this.config.get('INTERNAL_API_KEY');
        if (!expected || key !== expected) {
            throw new common_1.UnauthorizedException('Bad internal key');
        }
        const sent = await this.push.sendToSocietyAdmins(dto.societyIds, dto.title, dto.body);
        return { sent, enabled: this.push.enabled };
    }
};
__decorate([
    (0, public_decorator_1.Public)(),
    (0, common_1.Post)(),
    __param(0, (0, common_1.Headers)('x-internal-key')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, InternalPushDto]),
    __metadata("design:returntype", Promise)
], InternalPushController.prototype, "send", null);
InternalPushController = __decorate([
    (0, common_1.Controller)('internal/push'),
    __metadata("design:paramtypes", [push_service_1.PushService,
        config_1.ConfigService])
], InternalPushController);
let PushModule = class PushModule {
};
exports.PushModule = PushModule;
exports.PushModule = PushModule = __decorate([
    (0, common_1.Global)(),
    (0, common_1.Module)({
        controllers: [DevicesController, InternalPushController],
        providers: [push_service_1.PushService],
        exports: [push_service_1.PushService],
    })
], PushModule);
//# sourceMappingURL=push.module.js.map