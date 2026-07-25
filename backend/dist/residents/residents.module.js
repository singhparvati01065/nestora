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
exports.ResidentsModule = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const class_validator_1 = require("class-validator");
const auth_service_1 = require("../auth/auth.service");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const rent_billing_1 = require("../bills/rent-billing");
const society_scope_1 = require("../common/society-scope");
const prisma_service_1 = require("../prisma/prisma.service");
class CreateResidentDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateResidentDto.prototype, "flatId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateResidentDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateResidentDto.prototype, "phone", void 0);
__decorate([
    (0, class_validator_1.IsEnum)(client_1.ResidentType),
    __metadata("design:type", String)
], CreateResidentDto.prototype, "type", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], CreateResidentDto.prototype, "monthlyRent", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsISO8601)(),
    __metadata("design:type", String)
], CreateResidentDto.prototype, "moveInDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], CreateResidentDto.prototype, "advanceAmount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], CreateResidentDto.prototype, "maintenanceAmount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateResidentDto.prototype, "occupation", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], CreateResidentDto.prototype, "familyMembers", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], CreateResidentDto.prototype, "documentUrls", void 0);
class UpdateResidentDto {
}
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateResidentDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateResidentDto.prototype, "phone", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsEnum)(client_1.ResidentType),
    __metadata("design:type", String)
], UpdateResidentDto.prototype, "type", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], UpdateResidentDto.prototype, "monthlyRent", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsISO8601)(),
    __metadata("design:type", String)
], UpdateResidentDto.prototype, "moveInDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], UpdateResidentDto.prototype, "advanceAmount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], UpdateResidentDto.prototype, "maintenanceAmount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateResidentDto.prototype, "occupation", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], UpdateResidentDto.prototype, "familyMembers", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], UpdateResidentDto.prototype, "documentUrls", void 0);
let ResidentsController = class ResidentsController {
    constructor(prisma) {
        this.prisma = prisma;
    }
    list(user) {
        return this.prisma.resident.findMany({
            where: { societyId: (0, society_scope_1.resolveSocietyId)(user), archivedAt: null },
            include: { flat: { select: { number: true } } },
            orderBy: { createdAt: 'asc' },
        });
    }
    history(user) {
        return this.prisma.resident.findMany({
            where: { societyId: (0, society_scope_1.resolveSocietyId)(user), archivedAt: { not: null } },
            include: { flat: { select: { number: true } } },
            orderBy: { archivedAt: 'desc' },
        });
    }
    async create(user, dto) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const occupied = await this.prisma.resident.findFirst({
            where: { flatId: dto.flatId, societyId, archivedAt: null },
            select: { id: true },
        });
        if (occupied) {
            throw new common_1.BadRequestException('This flat already has a resident. Remove them before adding a new one.');
        }
        const resident = await this.prisma.resident.create({
            data: {
                societyId,
                flatId: dto.flatId,
                name: dto.name,
                phone: dto.phone,
                type: dto.type,
                monthlyRent: dto.monthlyRent,
                moveInDate: dto.moveInDate ? new Date(dto.moveInDate) : undefined,
                advanceAmount: dto.advanceAmount,
                maintenanceAmount: dto.maintenanceAmount,
                occupation: dto.occupation,
                familyMembers: dto.familyMembers,
                documentUrls: dto.documentUrls,
            },
        });
        await this.linkUserToFlat(dto.phone, dto.flatId, societyId, dto.name);
        await (0, rent_billing_1.ensureRentBills)(this.prisma, societyId);
        return resident;
    }
    async linkUserToFlat(phone, flatId, societyId, name) {
        const local = phone ? (0, auth_service_1.toLocalPhone)(phone) : '';
        if (!local)
            return;
        const existing = await this.prisma.user.findUnique({
            where: { phone: local },
        });
        if (existing) {
            if (existing.role !== client_1.Role.RESIDENT)
                return;
            await this.prisma.user.update({
                where: { id: existing.id },
                data: { flatId, societyId },
            });
        }
        else {
            await this.prisma.user.create({
                data: { phone: local, name, role: client_1.Role.RESIDENT, flatId, societyId },
            });
        }
    }
    async unlinkUserFromFlat(phone) {
        const local = phone ? (0, auth_service_1.toLocalPhone)(phone) : '';
        if (!local)
            return;
        await this.prisma.user.updateMany({
            where: { phone: local, role: client_1.Role.RESIDENT },
            data: { flatId: null },
        });
    }
    async update(user, id, dto) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const resident = await this.prisma.resident.update({
            where: { id },
            data: {
                name: dto.name,
                phone: dto.phone,
                type: dto.type,
                monthlyRent: dto.monthlyRent,
                moveInDate: dto.moveInDate ? new Date(dto.moveInDate) : undefined,
                advanceAmount: dto.advanceAmount,
                maintenanceAmount: dto.maintenanceAmount,
                occupation: dto.occupation,
                familyMembers: dto.familyMembers,
                documentUrls: dto.documentUrls,
            },
        });
        await this.linkUserToFlat(resident.phone, resident.flatId, societyId, resident.name);
        await (0, rent_billing_1.ensureRentBills)(this.prisma, societyId);
        return resident;
    }
    async archive(id) {
        const resident = await this.prisma.resident.update({
            where: { id },
            data: { archivedAt: new Date() },
        });
        await this.unlinkUserFromFlat(resident.phone);
        return resident;
    }
    async remove(id) {
        const resident = await this.prisma.resident.delete({ where: { id } });
        await this.unlinkUserFromFlat(resident.phone);
        return resident;
    }
};
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], ResidentsController.prototype, "list", null);
__decorate([
    (0, common_1.Get)('archived'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], ResidentsController.prototype, "history", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, CreateResidentDto]),
    __metadata("design:returntype", Promise)
], ResidentsController.prototype, "create", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, UpdateResidentDto]),
    __metadata("design:returntype", Promise)
], ResidentsController.prototype, "update", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id/archive'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], ResidentsController.prototype, "archive", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], ResidentsController.prototype, "remove", null);
ResidentsController = __decorate([
    (0, common_1.Controller)('residents'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], ResidentsController);
let ResidentsModule = class ResidentsModule {
};
exports.ResidentsModule = ResidentsModule;
exports.ResidentsModule = ResidentsModule = __decorate([
    (0, common_1.Module)({ controllers: [ResidentsController] })
], ResidentsModule);
//# sourceMappingURL=residents.module.js.map