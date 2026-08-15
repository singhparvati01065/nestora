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
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../prisma/prisma.service");
let UsersService = class UsersService {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async updateMe(userId, dto) {
        const data = {};
        if (dto.name !== undefined)
            data.name = dto.name.trim();
        if (dto.photoUrl !== undefined)
            data.photoUrl = dto.photoUrl;
        if (dto.trades !== undefined)
            data.trades = dto.trades;
        const user = await this.prisma.user.update({
            where: { id: userId },
            data,
        });
        const { password: _pw, ...safe } = user;
        return safe;
    }
    async deleteMe(userId, role) {
        if (role === client_1.Role.SOCIETY_ADMIN) {
            throw new common_1.ForbiddenException('A society admin account cannot be deleted from the app, because the ' +
                'whole society is attached to it. Raise a support ticket and we will ' +
                'handle it with you.');
        }
        await this.prisma.$transaction(async (tx) => {
            await tx.deviceToken.deleteMany({ where: { userId } });
            await tx.user.update({
                where: { id: userId },
                data: {
                    name: 'Deleted account',
                    phone: `deleted-${userId}`,
                    email: null,
                    password: null,
                    firebaseUid: null,
                    photoUrl: null,
                    address: null,
                    salary: null,
                    trades: [],
                    flatId: null,
                    archivedAt: new Date(),
                    banned: true,
                },
            });
        });
        return { deleted: true };
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], UsersService);
//# sourceMappingURL=users.service.js.map