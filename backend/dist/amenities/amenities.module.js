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
exports.AmenitiesModule = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const class_validator_1 = require("class-validator");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const society_scope_1 = require("../common/society-scope");
const prisma_service_1 = require("../prisma/prisma.service");
class BookAmenityDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], BookAmenityDto.prototype, "amenityId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], BookAmenityDto.prototype, "day", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], BookAmenityDto.prototype, "slot", void 0);
class AmenityDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], AmenityDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], AmenityDto.prototype, "icon", void 0);
class UpdateAmenityDto {
}
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateAmenityDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateAmenityDto.prototype, "icon", void 0);
class BookingStatusDto {
}
__decorate([
    (0, class_validator_1.IsIn)(['PENDING', 'APPROVED', 'REJECTED']),
    __metadata("design:type", String)
], BookingStatusDto.prototype, "status", void 0);
const ACTIVE = { not: client_1.BookingStatus.REJECTED };
let AmenitiesController = class AmenitiesController {
    constructor(prisma) {
        this.prisma = prisma;
    }
    list(user) {
        return this.prisma.amenity.findMany({
            where: { societyId: (0, society_scope_1.resolveSocietyId)(user) },
            orderBy: { name: 'asc' },
        });
    }
    create(user, dto) {
        return this.prisma.amenity.create({
            data: {
                societyId: (0, society_scope_1.resolveSocietyId)(user),
                name: dto.name.trim(),
                icon: dto.icon,
            },
        });
    }
    async update(user, id, dto) {
        await this.ownAmenity(user, id);
        return this.prisma.amenity.update({
            where: { id },
            data: {
                ...(dto.name != null ? { name: dto.name.trim() } : {}),
                ...(dto.icon != null ? { icon: dto.icon } : {}),
            },
        });
    }
    async remove(user, id) {
        await this.ownAmenity(user, id);
        await this.prisma.amenity.delete({ where: { id } });
        return { ok: true };
    }
    bookings(user) {
        if (!user.flatId)
            throw new common_1.ForbiddenException('No flat on account');
        return this.prisma.amenityBooking.findMany({
            where: { flatId: user.flatId },
            include: { amenity: { select: { name: true } } },
            orderBy: { createdAt: 'desc' },
        });
    }
    allBookings(user) {
        return this.prisma.amenityBooking.findMany({
            where: { societyId: (0, society_scope_1.resolveSocietyId)(user) },
            include: {
                amenity: { select: { name: true } },
                flat: { select: { number: true } },
            },
            orderBy: { createdAt: 'desc' },
        });
    }
    async booked(user, amenityId, day) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const rows = await this.prisma.amenityBooking.findMany({
            where: { societyId, amenityId, day, status: ACTIVE },
            select: { slot: true },
        });
        return rows.map((r) => r.slot);
    }
    async book(user, dto) {
        if (!user.flatId)
            throw new common_1.ForbiddenException('No flat on account');
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const clash = await this.prisma.amenityBooking.findFirst({
            where: {
                societyId,
                amenityId: dto.amenityId,
                day: dto.day,
                slot: dto.slot,
                status: ACTIVE,
            },
            select: { id: true },
        });
        if (clash) {
            throw new common_1.BadRequestException('That slot is already booked.');
        }
        return this.prisma.amenityBooking.create({
            data: {
                societyId,
                amenityId: dto.amenityId,
                flatId: user.flatId,
                day: dto.day,
                slot: dto.slot,
            },
        });
    }
    async cancel(user, id) {
        const booking = await this.prisma.amenityBooking.findUnique({
            where: { id },
            select: { flatId: true, societyId: true },
        });
        if (!booking)
            throw new common_1.BadRequestException('Booking not found');
        const isOwner = user.role === client_1.Role.RESIDENT && booking.flatId === user.flatId;
        const isAdmin = (user.role === client_1.Role.SOCIETY_ADMIN || user.role === client_1.Role.SUPER_ADMIN) &&
            booking.societyId === (0, society_scope_1.resolveSocietyId)(user);
        if (!isOwner && !isAdmin) {
            throw new common_1.ForbiddenException('Not your booking');
        }
        await this.prisma.amenityBooking.delete({ where: { id } });
        return { ok: true };
    }
    async setStatus(user, id, dto) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const booking = await this.prisma.amenityBooking.findFirst({
            where: { id, societyId },
            select: { id: true },
        });
        if (!booking)
            throw new common_1.BadRequestException('Booking not found');
        return this.prisma.amenityBooking.update({
            where: { id },
            data: { status: dto.status },
            include: {
                amenity: { select: { name: true } },
                flat: { select: { number: true } },
            },
        });
    }
    async ownAmenity(user, id) {
        const found = await this.prisma.amenity.findFirst({
            where: { id, societyId: (0, society_scope_1.resolveSocietyId)(user) },
            select: { id: true },
        });
        if (!found)
            throw new common_1.BadRequestException('Amenity not found');
    }
};
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AmenitiesController.prototype, "list", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, AmenityDto]),
    __metadata("design:returntype", void 0)
], AmenitiesController.prototype, "create", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, UpdateAmenityDto]),
    __metadata("design:returntype", Promise)
], AmenitiesController.prototype, "update", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Delete)(':id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AmenitiesController.prototype, "remove", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.RESIDENT),
    (0, common_1.Get)('bookings'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AmenitiesController.prototype, "bookings", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Get)('bookings/all'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AmenitiesController.prototype, "allBookings", null);
__decorate([
    (0, common_1.Get)('booked'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('amenityId')),
    __param(2, (0, common_1.Query)('day')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", Promise)
], AmenitiesController.prototype, "booked", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.RESIDENT),
    (0, common_1.Post)('book'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, BookAmenityDto]),
    __metadata("design:returntype", Promise)
], AmenitiesController.prototype, "book", null);
__decorate([
    (0, common_1.Delete)('bookings/:id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AmenitiesController.prototype, "cancel", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)('bookings/:id/status'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, BookingStatusDto]),
    __metadata("design:returntype", Promise)
], AmenitiesController.prototype, "setStatus", null);
AmenitiesController = __decorate([
    (0, common_1.Controller)('amenities'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], AmenitiesController);
let AmenitiesModule = class AmenitiesModule {
};
exports.AmenitiesModule = AmenitiesModule;
exports.AmenitiesModule = AmenitiesModule = __decorate([
    (0, common_1.Module)({ controllers: [AmenitiesController] })
], AmenitiesModule);
//# sourceMappingURL=amenities.module.js.map