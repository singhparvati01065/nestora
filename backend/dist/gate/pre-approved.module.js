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
exports.PreApprovedModule = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const class_validator_1 = require("class-validator");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const society_scope_1 = require("../common/society-scope");
const prisma_service_1 = require("../prisma/prisma.service");
const feature_decorator_1 = require("../platform/feature.decorator");
class CreatePreApprovedDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreatePreApprovedDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreatePreApprovedDto.prototype, "purpose", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreatePreApprovedDto.prototype, "validLabel", void 0);
let PreApprovedController = class PreApprovedController {
    constructor(prisma) {
        this.prisma = prisma;
    }
    list(user) {
        const where = user.role === client_1.Role.RESIDENT
            ? { societyId: (0, society_scope_1.resolveSocietyId)(user), flatId: user.flatId ?? '' }
            : { societyId: (0, society_scope_1.resolveSocietyId)(user) };
        return this.prisma.preApprovedVisitor.findMany({
            where,
            include: { flat: { select: { number: true } } },
            orderBy: { createdAt: 'desc' },
        });
    }
    create(user, dto) {
        if (!user.flatId)
            throw new common_1.ForbiddenException('No flat on account');
        return this.prisma.preApprovedVisitor.create({
            data: {
                societyId: (0, society_scope_1.resolveSocietyId)(user),
                flatId: user.flatId,
                name: dto.name,
                purpose: dto.purpose,
                validLabel: dto.validLabel,
            },
        });
    }
    async checkIn(id) {
        const pre = await this.prisma.preApprovedVisitor.findUniqueOrThrow({
            where: { id },
        });
        await this.prisma.visitor.create({
            data: {
                societyId: pre.societyId,
                flatId: pre.flatId,
                name: pre.name,
                purpose: pre.purpose,
                status: client_1.VisitorStatus.INSIDE,
            },
        });
        return this.prisma.preApprovedVisitor.update({
            where: { id },
            data: { checkedIn: true },
        });
    }
};
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], PreApprovedController.prototype, "list", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.RESIDENT),
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, CreatePreApprovedDto]),
    __metadata("design:returntype", void 0)
], PreApprovedController.prototype, "create", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SECURITY_GUARD, client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id/check-in'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], PreApprovedController.prototype, "checkIn", null);
PreApprovedController = __decorate([
    (0, feature_decorator_1.RequiresFeature)('visitors'),
    (0, common_1.Controller)('pre-approved'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], PreApprovedController);
let PreApprovedModule = class PreApprovedModule {
};
exports.PreApprovedModule = PreApprovedModule;
exports.PreApprovedModule = PreApprovedModule = __decorate([
    (0, common_1.Module)({ controllers: [PreApprovedController] })
], PreApprovedModule);
//# sourceMappingURL=pre-approved.module.js.map