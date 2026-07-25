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
exports.ComplaintsModule = exports.STAFF_MEMBERS = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const class_validator_1 = require("class-validator");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const society_scope_1 = require("../common/society-scope");
const prisma_service_1 = require("../prisma/prisma.service");
exports.STAFF_MEMBERS = [
    'Suresh (Plumber)',
    'Ramesh (Electrician)',
    'Vijay (Housekeeping)',
    'Anil (Handyman)',
];
class CreateComplaintDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateComplaintDto.prototype, "flatId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateComplaintDto.prototype, "title", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateComplaintDto.prototype, "description", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateComplaintDto.prototype, "category", void 0);
class UpdateStatusDto {
}
__decorate([
    (0, class_validator_1.IsEnum)(client_1.ComplaintStatus),
    __metadata("design:type", String)
], UpdateStatusDto.prototype, "status", void 0);
class AssignDto {
}
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", Object)
], AssignDto.prototype, "assignedTo", void 0);
let ComplaintsController = class ComplaintsController {
    constructor(prisma) {
        this.prisma = prisma;
    }
    list(user, flatId, assignedTo, unassigned) {
        if (user.role === client_1.Role.RESIDENT) {
            if (!user.flatId)
                throw new common_1.ForbiddenException('No flat on account');
            flatId = user.flatId;
        }
        return this.prisma.complaint.findMany({
            where: {
                societyId: (0, society_scope_1.resolveSocietyId)(user),
                ...(flatId ? { flatId } : {}),
                ...(assignedTo ? { assignedTo } : {}),
                ...(unassigned === 'true' ? { assignedTo: null } : {}),
            },
            include: { flat: { select: { number: true } } },
            orderBy: { createdAt: 'desc' },
        });
    }
    async staff(user) {
        return this.prisma.user.findMany({
            where: {
                societyId: (0, society_scope_1.resolveSocietyId)(user),
                role: client_1.Role.MAINTENANCE_STAFF,
            },
            select: { id: true, name: true, trades: true },
            orderBy: { name: 'asc' },
        });
    }
    create(user, dto) {
        if (user.role === client_1.Role.RESIDENT && dto.flatId !== user.flatId) {
            throw new common_1.ForbiddenException('Can only file for your own flat');
        }
        return this.prisma.complaint.create({
            data: { ...dto, societyId: (0, society_scope_1.resolveSocietyId)(user) },
        });
    }
    updateStatus(id, dto) {
        return this.prisma.complaint.update({
            where: { id },
            data: { status: dto.status },
        });
    }
    assign(dto, id) {
        return this.prisma.complaint.update({
            where: { id },
            data: { assignedTo: dto.assignedTo ?? null },
        });
    }
};
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('flatId')),
    __param(2, (0, common_1.Query)('assignedTo')),
    __param(3, (0, common_1.Query)('unassigned')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String, String]),
    __metadata("design:returntype", void 0)
], ComplaintsController.prototype, "list", null);
__decorate([
    (0, common_1.Get)('staff'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ComplaintsController.prototype, "staff", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, CreateComplaintDto]),
    __metadata("design:returntype", void 0)
], ComplaintsController.prototype, "create", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN, client_1.Role.MAINTENANCE_STAFF),
    (0, common_1.Patch)(':id/status'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, UpdateStatusDto]),
    __metadata("design:returntype", void 0)
], ComplaintsController.prototype, "updateStatus", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN, client_1.Role.MAINTENANCE_STAFF),
    (0, common_1.Patch)(':id/assign'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [AssignDto, String]),
    __metadata("design:returntype", void 0)
], ComplaintsController.prototype, "assign", null);
ComplaintsController = __decorate([
    (0, common_1.Controller)('complaints'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], ComplaintsController);
let ComplaintsModule = class ComplaintsModule {
};
exports.ComplaintsModule = ComplaintsModule;
exports.ComplaintsModule = ComplaintsModule = __decorate([
    (0, common_1.Module)({ controllers: [ComplaintsController] })
], ComplaintsModule);
//# sourceMappingURL=complaints.module.js.map