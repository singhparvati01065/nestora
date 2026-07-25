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
var AuthService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
exports.toLocalPhone = toLocalPhone;
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const client_1 = require("@prisma/client");
const bcrypt = require("bcrypt");
const prisma_service_1 = require("../prisma/prisma.service");
const firebase_admin_service_1 = require("./firebase-admin.service");
function toLocalPhone(e164) {
    const digits = e164.replace(/\D/g, '');
    return digits.length > 10 ? digits.slice(-10) : digits;
}
let AuthService = AuthService_1 = class AuthService {
    constructor(prisma, jwt, firebase) {
        this.prisma = prisma;
        this.jwt = jwt;
        this.firebase = firebase;
        this.logger = new common_1.Logger(AuthService_1.name);
    }
    tokenFor(user) {
        return this.jwt.sign(user);
    }
    issueSession(authUser) {
        void this.prisma.loginEvent
            .create({ data: { userId: authUser.sub, role: authUser.role } })
            .catch(() => null);
        return { accessToken: this.tokenFor(authUser), user: authUser };
    }
    toAuthUser(u) {
        return {
            sub: u.id,
            phone: u.phone,
            name: u.name,
            photoUrl: u.photoUrl,
            role: u.role,
            societyId: u.societyId,
            flatId: u.flatId,
            staffLabel: u.staffLabel,
            trades: u.trades,
        };
    }
    async register(dto) {
        if (dto.role !== client_1.Role.SOCIETY_ADMIN) {
            throw new common_1.ForbiddenException('Only society admins can create an account. Ask your admin to add you.');
        }
        const existing = await this.prisma.user.findUnique({
            where: { phone: dto.phone },
        });
        if (existing)
            throw new common_1.ConflictException('Phone already registered');
        const password = await bcrypt.hash(dto.password, 10);
        const user = await this.prisma.user.create({
            data: {
                phone: dto.phone,
                password,
                name: dto.name,
                role: dto.role,
                societyId: dto.societyId ?? null,
                flatId: dto.flatId ?? null,
                staffLabel: dto.staffLabel ?? null,
            },
        });
        const authUser = this.toAuthUser(user);
        return this.issueSession(authUser);
    }
    async login(dto) {
        const user = await this.prisma.user.findUnique({
            where: { phone: dto.phone },
        });
        if (!user)
            throw new common_1.UnauthorizedException('Invalid credentials');
        if (!user.password)
            throw new common_1.UnauthorizedException('Invalid credentials');
        const ok = await bcrypt.compare(dto.password, user.password);
        if (!ok)
            throw new common_1.UnauthorizedException('Invalid credentials');
        const authUser = this.toAuthUser(user);
        return this.issueSession(authUser);
    }
    async firebaseLogin(dto) {
        const identity = await this.firebase.verify(dto.idToken);
        const phone = toLocalPhone(identity.phone);
        const existing = await this.prisma.user.findUnique({ where: { phone } });
        if (existing) {
            if (existing.banned) {
                throw new common_1.ForbiddenException('This account has been blocked.');
            }
            if (existing.archivedAt) {
                throw new common_1.ForbiddenException('This account has been removed. Ask your society admin.');
            }
            if (existing.firebaseUid && existing.firebaseUid !== identity.uid) {
                throw new common_1.UnauthorizedException('Phone is linked to another account');
            }
            const user = existing.firebaseUid
                ? existing
                : await this.prisma.user.update({
                    where: { id: existing.id },
                    data: { firebaseUid: identity.uid },
                });
            const authUser = this.toAuthUser(user);
            return this.issueSession(authUser);
        }
        if (dto.role !== client_1.Role.SOCIETY_ADMIN) {
            throw new common_1.ForbiddenException('No account for this number. Ask your society admin to register you.');
        }
        const created = await this.prisma.user.create({
            data: {
                phone,
                firebaseUid: identity.uid,
                name: dto.name?.trim() || 'Member',
                role: client_1.Role.SOCIETY_ADMIN,
                trades: [],
            },
        });
        const authUser = this.toAuthUser(created);
        return this.issueSession(authUser);
    }
    async devLogin(dto) {
        if (process.env.NODE_ENV === 'production' ||
            process.env.DEV_LOGIN_ENABLED !== 'true') {
            throw new common_1.NotFoundException('Cannot POST /api/auth/dev-login');
        }
        this.logger.warn(`DEV LOGIN — issuing an unverified token for ${dto.phone}. ` +
            'This must never be reachable outside local development.');
        const phone = toLocalPhone(dto.phone);
        const existing = await this.prisma.user.findUnique({ where: { phone } });
        if (existing?.banned) {
            throw new common_1.ForbiddenException('This account has been blocked.');
        }
        if (existing?.archivedAt) {
            throw new common_1.ForbiddenException('This account has been removed. Ask your society admin.');
        }
        if (!existing && dto.role !== client_1.Role.SOCIETY_ADMIN) {
            throw new common_1.ForbiddenException('No account for this number. Ask your society admin to register you.');
        }
        const user = existing ??
            (await this.prisma.user.create({
                data: {
                    phone,
                    name: dto.name?.trim() || 'Member',
                    role: client_1.Role.SOCIETY_ADMIN,
                    trades: [],
                },
            }));
        const authUser = this.toAuthUser(user);
        return this.issueSession(authUser);
    }
    async me(userId) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            include: { society: true, flat: true },
        });
        if (!user)
            throw new common_1.UnauthorizedException();
        const { password: _pw, ...safe } = user;
        return safe;
    }
    async refresh(userId) {
        const user = await this.prisma.user.findUnique({ where: { id: userId } });
        if (!user)
            throw new common_1.UnauthorizedException();
        const authUser = this.toAuthUser(user);
        return this.issueSession(authUser);
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = AuthService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        jwt_1.JwtService,
        firebase_admin_service_1.FirebaseAdminService])
], AuthService);
//# sourceMappingURL=auth.service.js.map