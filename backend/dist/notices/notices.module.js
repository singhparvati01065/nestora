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
exports.NoticesModule = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const class_validator_1 = require("class-validator");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const society_scope_1 = require("../common/society-scope");
const prisma_service_1 = require("../prisma/prisma.service");
class CreateNoticeDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateNoticeDto.prototype, "title", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateNoticeDto.prototype, "body", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], CreateNoticeDto.prototype, "pinned", void 0);
let NoticesController = class NoticesController {
    constructor(prisma) {
        this.prisma = prisma;
    }
    list(user) {
        return this.prisma.notice.findMany({
            where: { societyId: (0, society_scope_1.resolveSocietyId)(user) },
            orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
        });
    }
    create(user, dto) {
        return this.prisma.notice.create({
            data: {
                title: dto.title,
                body: dto.body,
                pinned: dto.pinned ?? false,
                societyId: (0, society_scope_1.resolveSocietyId)(user),
            },
        });
    }
    async togglePin(id) {
        const notice = await this.prisma.notice.findUniqueOrThrow({ where: { id } });
        return this.prisma.notice.update({
            where: { id },
            data: { pinned: !notice.pinned },
        });
    }
    remove(id) {
        return this.prisma.notice.delete({ where: { id } });
    }
};
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], NoticesController.prototype, "list", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, CreateNoticeDto]),
    __metadata("design:returntype", void 0)
], NoticesController.prototype, "create", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id/pin'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], NoticesController.prototype, "togglePin", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], NoticesController.prototype, "remove", null);
NoticesController = __decorate([
    (0, common_1.Controller)('notices'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], NoticesController);
let NoticesModule = class NoticesModule {
};
exports.NoticesModule = NoticesModule;
exports.NoticesModule = NoticesModule = __decorate([
    (0, common_1.Module)({ controllers: [NoticesController] })
], NoticesModule);
//# sourceMappingURL=notices.module.js.map