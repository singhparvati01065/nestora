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
exports.BillsModule = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const class_validator_1 = require("class-validator");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const society_scope_1 = require("../common/society-scope");
const prisma_service_1 = require("../prisma/prisma.service");
const push_service_1 = require("../push/push.service");
const feature_decorator_1 = require("../platform/feature.decorator");
const maintenance_billing_1 = require("./maintenance-billing");
const rent_billing_1 = require("./rent-billing");
class GenerateBillsDto {
}
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], GenerateBillsDto.prototype, "startDate", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], GenerateBillsDto.prototype, "flatId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], GenerateBillsDto.prototype, "kind", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], GenerateBillsDto.prototype, "amount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], GenerateBillsDto.prototype, "title", void 0);
class PayBillsDto {
}
__decorate([
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], PayBillsDto.prototype, "ids", void 0);
class UpdateBillDto {
}
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], UpdateBillDto.prototype, "amount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateBillDto.prototype, "startDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateBillDto.prototype, "title", void 0);
let BillsController = class BillsController {
    constructor(prisma, push) {
        this.prisma = prisma;
        this.push = push;
    }
    async list(user, flatId) {
        if (user.role === client_1.Role.RESIDENT) {
            if (!user.flatId)
                throw new common_1.ForbiddenException('No flat on account');
            flatId = user.flatId;
        }
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        await (0, rent_billing_1.ensureRentBills)(this.prisma, societyId);
        await (0, maintenance_billing_1.ensureRecurringBills)(this.prisma, societyId);
        const where = {
            societyId,
            deletedAt: null,
            ...(flatId ? { flatId } : {}),
        };
        const bills = await this.prisma.bill.findMany({
            where,
            include: { flat: { select: { number: true } } },
            orderBy: { createdAt: 'asc' },
        });
        const num = (b) => Number(b.amount);
        return {
            bills,
            summary: {
                collected: bills.filter((b) => b.paid).reduce((s, b) => s + num(b), 0),
                pending: bills.filter((b) => !b.paid).reduce((s, b) => s + num(b), 0),
                paidCount: bills.filter((b) => b.paid).length,
                pendingCount: bills.filter((b) => !b.paid).length,
            },
        };
    }
    async ownBill(user, id) {
        const where = { id, deletedAt: null };
        if (user.role !== client_1.Role.SUPER_ADMIN) {
            where.societyId = (0, society_scope_1.resolveSocietyId)(user);
            if (user.role === client_1.Role.RESIDENT) {
                if (!user.flatId) {
                    throw new common_1.ForbiddenException('No flat linked to this account');
                }
                where.flatId = user.flatId;
            }
        }
        const bill = await this.prisma.bill.findFirst({ where, select: { id: true } });
        if (!bill)
            throw new common_1.NotFoundException('Bill not found');
        return bill;
    }
    async generate(user, dto) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const start = (0, maintenance_billing_1.parseStartDate)(dto.startDate);
        if (!start)
            throw new common_1.BadRequestException('Invalid start date');
        if (!dto.flatId)
            throw new common_1.BadRequestException('Choose a flat');
        if (!(dto.amount > 0))
            throw new common_1.BadRequestException('Enter an amount');
        const flat = await this.prisma.flat.findFirst({
            where: { id: dto.flatId, societyId },
            select: { id: true },
        });
        if (!flat)
            throw new common_1.BadRequestException('Unknown flat');
        if (dto.kind === client_1.BillKind.OTHER) {
            const title = (dto.title ?? '').trim();
            if (!title)
                throw new common_1.BadRequestException('Name the charge');
            const period = (0, maintenance_billing_1.monthLabelOf)(start);
            const existing = await this.prisma.bill.findFirst({
                where: { flatId: dto.flatId, period, kind: client_1.BillKind.OTHER, title },
                select: { id: true, deletedAt: true },
            });
            if (existing && existing.deletedAt == null) {
                throw new common_1.BadRequestException(`A "${title}" charge already exists for ${period}`);
            }
            if (existing) {
                await this.prisma.bill.update({
                    where: { id: existing.id },
                    data: {
                        amount: dto.amount,
                        dueDate: start,
                        deletedAt: null,
                        paid: false,
                        paidAt: null,
                    },
                });
            }
            else {
                await this.prisma.bill.create({
                    data: {
                        societyId,
                        flatId: dto.flatId,
                        period,
                        amount: dto.amount,
                        dueDate: start,
                        kind: client_1.BillKind.OTHER,
                        title,
                    },
                });
            }
            return { created: 1, period };
        }
        if (dto.kind !== client_1.BillKind.RENT && dto.kind !== client_1.BillKind.MANUAL) {
            throw new common_1.BadRequestException('Unknown bill type');
        }
        await this.prisma.flat.update({
            where: { id: dto.flatId },
            data: {
                billingSince: start,
                ...(dto.kind === client_1.BillKind.RENT
                    ? { rentAmount: dto.amount }
                    : { maintenanceAmount: dto.amount }),
            },
        });
        const before = await this.prisma.bill.count({ where: { societyId } });
        await (0, maintenance_billing_1.ensureRecurringBills)(this.prisma, societyId);
        const after = await this.prisma.bill.count({ where: { societyId } });
        const day = start.getUTCDate();
        const existing = await this.prisma.bill.findMany({
            where: {
                societyId,
                flatId: dto.flatId,
                deletedAt: null,
                paid: false,
                kind: dto.kind,
            },
            select: { id: true, period: true },
        });
        for (const b of existing) {
            const due = (0, maintenance_billing_1.dueDateForPeriod)(b.period, day);
            if (due) {
                await this.prisma.bill.update({
                    where: { id: b.id },
                    data: { dueDate: due },
                });
            }
        }
        return { created: after - before, period: (0, maintenance_billing_1.monthLabelOf)(start) };
    }
    async pay(user, id) {
        await this.ownBill(user, id);
        return this.prisma.bill.update({
            where: { id },
            data: { paid: true, paidAt: new Date() },
        });
    }
    async payMany(user, dto) {
        const paidAt = new Date();
        const where = {
            id: { in: dto.ids },
            deletedAt: null,
        };
        if (user.role !== client_1.Role.SUPER_ADMIN) {
            where.societyId = (0, society_scope_1.resolveSocietyId)(user);
            if (user.role === client_1.Role.RESIDENT) {
                if (!user.flatId) {
                    throw new common_1.ForbiddenException('No flat linked to this account');
                }
                where.flatId = user.flatId;
            }
        }
        const res = await this.prisma.bill.updateMany({
            where,
            data: { paid: true, paidAt },
        });
        if (res.count > 0) {
            const bills = await this.prisma.bill.findMany({
                where: { id: { in: dto.ids } },
                select: {
                    amount: true,
                    societyId: true,
                    flatId: true,
                    flat: { select: { number: true } },
                },
            });
            if (bills.length > 0) {
                const total = bills.reduce((s, b) => s + Number(b.amount), 0);
                const flatNumber = bills[0].flat.number;
                const who = user.name
                    ? `${user.name} (Flat ${flatNumber})`
                    : `Flat ${flatNumber}`;
                const body = `${who} paid ₹${total.toFixed(0)} for ${bills.length} ` +
                    `bill${bills.length === 1 ? '' : 's'}.`;
                await this.prisma.appNotification.create({
                    data: {
                        societyId: bills[0].societyId,
                        title: 'Payment received',
                        body,
                    },
                });
                void this.push.sendToSocietyAdmins([bills[0].societyId], 'Payment received', body);
            }
        }
        return { paid: res.count, paidAt };
    }
    async update(user, id, dto) {
        const societyId = (0, society_scope_1.resolveSocietyId)(user);
        const bill = await this.prisma.bill.findFirst({
            where: { id, societyId },
            select: { id: true, kind: true, flatId: true, period: true, title: true },
        });
        if (!bill)
            throw new common_1.BadRequestException('Bill not found');
        const data = {};
        if (dto.amount != null) {
            if (!(dto.amount > 0))
                throw new common_1.BadRequestException('Enter an amount');
            data.amount = dto.amount;
        }
        let period = bill.period;
        if (dto.startDate) {
            const d = (0, maintenance_billing_1.parseStartDate)(dto.startDate);
            if (!d)
                throw new common_1.BadRequestException('Invalid date');
            period = (0, maintenance_billing_1.monthLabelOf)(d);
            data.dueDate = d;
            data.period = period;
        }
        let title = bill.title;
        if (bill.kind === client_1.BillKind.OTHER && dto.title != null) {
            title = dto.title.trim();
            if (!title)
                throw new common_1.BadRequestException('Name the charge');
            data.title = title;
        }
        if (period !== bill.period || title !== bill.title) {
            const clash = await this.prisma.bill.findFirst({
                where: {
                    flatId: bill.flatId,
                    period,
                    kind: bill.kind,
                    title,
                    id: { not: bill.id },
                },
                select: { id: true },
            });
            if (clash) {
                throw new common_1.BadRequestException(bill.kind === client_1.BillKind.OTHER
                    ? `A "${title}" charge already exists for ${period}`
                    : `A ${bill.kind === client_1.BillKind.RENT ? 'rent' : 'maintenance'} ` +
                        `bill already exists for ${period}`);
            }
        }
        return this.prisma.bill.update({ where: { id }, data });
    }
    async unpay(user, id) {
        await this.ownBill(user, id);
        return this.prisma.bill.update({
            where: { id },
            data: { paid: false, paidAt: null },
        });
    }
    async remove(user, id) {
        await this.ownBill(user, id);
        return this.prisma.bill.update({
            where: { id },
            data: { deletedAt: new Date() },
        });
    }
};
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('flatId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], BillsController.prototype, "list", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Post)('generate'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, GenerateBillsDto]),
    __metadata("design:returntype", Promise)
], BillsController.prototype, "generate", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.RESIDENT, client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id/pay'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], BillsController.prototype, "pay", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.RESIDENT, client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Post)('pay'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, PayBillsDto]),
    __metadata("design:returntype", Promise)
], BillsController.prototype, "payMany", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, UpdateBillDto]),
    __metadata("design:returntype", Promise)
], BillsController.prototype, "update", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Patch)(':id/unpay'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], BillsController.prototype, "unpay", null);
__decorate([
    (0, roles_decorator_1.Roles)(client_1.Role.SOCIETY_ADMIN, client_1.Role.SUPER_ADMIN),
    (0, common_1.Delete)(':id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], BillsController.prototype, "remove", null);
BillsController = __decorate([
    (0, feature_decorator_1.RequiresFeature)('online_payments'),
    (0, common_1.Controller)('bills'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        push_service_1.PushService])
], BillsController);
let BillsModule = class BillsModule {
};
exports.BillsModule = BillsModule;
exports.BillsModule = BillsModule = __decorate([
    (0, common_1.Module)({ controllers: [BillsController] })
], BillsModule);
//# sourceMappingURL=bills.module.js.map