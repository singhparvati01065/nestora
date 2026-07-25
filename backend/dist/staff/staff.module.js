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
exports.StaffModule = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const class_validator_1 = require("class-validator");
const auth_service_1 = require("../auth/auth.service");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const society_scope_1 = require("../common/society-scope");
const prisma_service_1 = require("../prisma/prisma.service");
const STAFF_ROLES = [client_1.Role.SECURITY_GUARD, client_1.Role.MAINTENANCE_STAFF];
class CreateStaffDto {
}
__decorate([
    (0, class_validator_1.IsIn)(['SECURITY_GUARD', 'MAINTENANCE_STAFF']),
    __metadata("design:type", String)
], CreateStaffDto.prototype, "role", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateStaffDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateStaffDto.prototype, "phone", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateStaffDto.prototype, "address", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsISO8601)(),
    __metadata("design:type", String)
], CreateStaffDto.prototype, "joinedAt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], CreateStaffDto.prototype, "salary", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], CreateStaffDto.prototype, "trades", void 0);
class UpdateStaffDto {
}
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateStaffDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateStaffDto.prototype, "phone", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateStaffDto.prototype, "address", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsISO8601)(),
    __metadata("design:type", String)
], UpdateStaffDto.prototype, "joinedAt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    __metadata("design:type", Number)
], UpdateStaffDto.prototype, "salary", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], UpdateStaffDto.prototype, "trades", void 0);
const STAFF_FIELDS = {
    id: true,
    name: true,
    phone: true,
    address: true,
    joinedAt: true,
    salary: true,
    role: true,
    trades: true,
};
let StaffController = class StaffController {
    constructor(prisma) {
        this.prisma = prisma;
    }
    list(user) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        return this.prisma.user.findMany({
            where: { societyId, role: { in: STAFF_ROLES }, archivedAt: null },
            select: STAFF_FIELDS,
            orderBy: { name: 'asc' },
        });
    }
    history(user) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        return this.prisma.user.findMany({
            where: {
                societyId,
                role: { in: STAFF_ROLES },
                archivedAt: { not: null },
            },
            select: STAFF_FIELDS,
            orderBy: { archivedAt: 'desc' },
        });
    }
    async create(user, dto) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const phone = (0, auth_service_1.toLocalPhone)(dto.phone);
        if (phone.length < 10) {
            throw new common_1.BadRequestException('Enter a valid phone number');
        }
        const role = dto.role;
        const trades = role === client_1.Role.MAINTENANCE_STAFF ? dto.trades ?? [] : [];
        const address = dto.address?.trim() || null;
        const joinedAt = dto.joinedAt ? new Date(dto.joinedAt) : new Date();
        const salary = dto.salary ?? null;
        const existing = await this.prisma.user.findUnique({ where: { phone } });
        if (existing && !STAFF_ROLES.includes(existing.role)) {
            throw new common_1.BadRequestException('This number already belongs to another account');
        }
        if (existing) {
            return this.prisma.user.update({
                where: { id: existing.id },
                data: {
                    name: dto.name.trim(),
                    role,
                    societyId,
                    trades,
                    address,
                    joinedAt,
                    salary,
                    archivedAt: null,
                },
                select: STAFF_FIELDS,
            });
        }
        return this.prisma.user.create({
            data: {
                phone,
                name: dto.name.trim(),
                role,
                societyId,
                trades,
                address,
                joinedAt,
                salary,
            },
            select: STAFF_FIELDS,
        });
    }
    async update(user, id, dto) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const staff = await this.prisma.user.findFirst({
            where: { id, societyId, role: { in: STAFF_ROLES } },
            select: { id: true, role: true },
        });
        if (!staff)
            throw new common_1.BadRequestException('Staff member not found');
        const data = {};
        if (dto.name != null)
            data.name = dto.name.trim();
        if (dto.address !== undefined)
            data.address = dto.address?.trim() || null;
        if (dto.joinedAt)
            data.joinedAt = new Date(dto.joinedAt);
        if (dto.salary !== undefined)
            data.salary = dto.salary || null;
        if (staff.role === client_1.Role.MAINTENANCE_STAFF && dto.trades != null) {
            data.trades = dto.trades;
        }
        if (dto.phone != null) {
            const phone = (0, auth_service_1.toLocalPhone)(dto.phone);
            if (phone.length < 10) {
                throw new common_1.BadRequestException('Enter a valid phone number');
            }
            const clash = await this.prisma.user.findFirst({
                where: { phone, id: { not: id } },
                select: { id: true },
            });
            if (clash) {
                throw new common_1.BadRequestException('This number already belongs to another account');
            }
            data.phone = phone;
        }
        return this.prisma.user.update({
            where: { id },
            data,
            select: STAFF_FIELDS,
        });
    }
    async archive(user, id) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const staff = await this.prisma.user.findFirst({
            where: { id, societyId, role: { in: STAFF_ROLES } },
            select: { id: true },
        });
        if (!staff)
            throw new common_1.BadRequestException('Staff member not found');
        return this.prisma.user.update({
            where: { id },
            data: { archivedAt: new Date() },
            select: STAFF_FIELDS,
        });
    }
    async remove(user, id) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const staff = await this.prisma.user.findFirst({
            where: { id, societyId, role: { in: STAFF_ROLES } },
            select: { id: true },
        });
        if (!staff)
            throw new common_1.BadRequestException('Staff member not found');
        await this.prisma.user.delete({ where: { id } });
        return { ok: true };
    }
};
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Get)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], StaffController.prototype, "list", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Get)('archived'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], StaffController.prototype, "history", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, CreateStaffDto]),
    __metadata("design:returntype", Promise)
], StaffController.prototype, "create", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, UpdateStaffDto]),
    __metadata("design:returntype", Promise)
], StaffController.prototype, "update", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id/archive'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], StaffController.prototype, "archive", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Delete)(':id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], StaffController.prototype, "remove", null);
StaffController = __decorate([
    (0, common_1.Controller)('staff'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], StaffController);
let StaffModule = class StaffModule {
};
exports.StaffModule = StaffModule;
exports.StaffModule = StaffModule = __decorate([
    (0, common_1.Module)({ controllers: [StaffController] })
], StaffModule);
//# sourceMappingURL=staff.module.js.map