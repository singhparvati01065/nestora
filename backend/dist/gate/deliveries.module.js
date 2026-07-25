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
exports.DeliveriesModule = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const class_validator_1 = require("class-validator");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const society_scope_1 = require("../common/society-scope");
const prisma_service_1 = require("../prisma/prisma.service");
class CreateDeliveryDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateDeliveryDto.prototype, "courier", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateDeliveryDto.prototype, "flatId", void 0);
let DeliveriesController = class DeliveriesController {
    constructor(prisma) {
        this.prisma = prisma;
    }
    list(user) {
        return this.prisma.delivery.findMany({
            where: { societyId: (0, society_scope_1.resolveSocietyId)(user) },
            include: { flat: { select: { number: true } } },
            orderBy: { inAt: 'desc' },
        });
    }
    create(user, dto) {
        return this.prisma.delivery.create({
            data: {
                societyId: (0, society_scope_1.resolveSocietyId)(user),
                courier: dto.courier,
                flatId: dto.flatId,
            },
        });
    }
    async toggleCollected(id) {
        const d = await this.prisma.delivery.findUniqueOrThrow({ where: { id } });
        return this.prisma.delivery.update({
            where: { id },
            data: { collected: !d.collected },
        });
    }
};
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], DeliveriesController.prototype, "list", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SECURITY_GUARD, client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, CreateDeliveryDto]),
    __metadata("design:returntype", void 0)
], DeliveriesController.prototype, "create", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SECURITY_GUARD, client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id/collected'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], DeliveriesController.prototype, "toggleCollected", null);
DeliveriesController = __decorate([
    (0, common_1.Controller)('deliveries'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], DeliveriesController);
let DeliveriesModule = class DeliveriesModule {
};
exports.DeliveriesModule = DeliveriesModule;
exports.DeliveriesModule = DeliveriesModule = __decorate([
    (0, common_1.Module)({ controllers: [DeliveriesController] })
], DeliveriesModule);
//# sourceMappingURL=deliveries.module.js.map