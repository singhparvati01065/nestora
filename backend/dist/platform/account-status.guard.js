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
exports.AccountStatusGuard = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../prisma/prisma.service");
const plan_1 = require("./plan");
const TTL_MS = 15_000;
const MAX_ENTRIES = 5_000;
let AccountStatusGuard = class AccountStatusGuard {
    constructor(prisma) {
        this.prisma = prisma;
        this.cache = new Map();
    }
    async canActivate(context) {
        const user = context.switchToHttp().getRequest().user;
        if (!user?.sub)
            return true;
        if (user.role === client_1.Role.SUPER_ADMIN)
            return true;
        const status = await this.statusOf(user.sub);
        if (status.missing)
            throw new common_1.UnauthorizedException('Account not found');
        if (status.blocked)
            throw new common_1.ForbiddenException(status.blocked);
        return true;
    }
    async statusOf(userId) {
        const hit = this.cache.get(userId);
        if (hit && Date.now() - hit.at < TTL_MS)
            return hit.status;
        const status = await this.load(userId);
        if (this.cache.size >= MAX_ENTRIES)
            this.cache.clear();
        this.cache.set(userId, { at: Date.now(), status });
        return status;
    }
    async load(userId) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: {
                banned: true,
                archivedAt: true,
                society: {
                    select: {
                        id: true,
                        suspended: true,
                        plan: true,
                        planExpiresAt: true,
                    },
                },
            },
        });
        if (!user)
            return { blocked: null, missing: true };
        if (user.banned) {
            return { blocked: 'This account has been blocked.', missing: false };
        }
        if (user.archivedAt) {
            return {
                blocked: 'This account has been removed. Ask your society admin.',
                missing: false,
            };
        }
        if (user.society) {
            if (user.society.suspended) {
                return {
                    blocked: 'This society has been suspended. Please contact Nestora support.',
                    missing: false,
                };
            }
            await (0, plan_1.applyPlanExpiry)(this.prisma, user.society);
        }
        return { blocked: null, missing: false };
    }
};
exports.AccountStatusGuard = AccountStatusGuard;
exports.AccountStatusGuard = AccountStatusGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], AccountStatusGuard);
//# sourceMappingURL=account-status.guard.js.map