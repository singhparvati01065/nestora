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
var PushService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PushService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const app_1 = require("firebase-admin/app");
const messaging_1 = require("firebase-admin/messaging");
const fs_1 = require("fs");
const prisma_service_1 = require("../prisma/prisma.service");
let PushService = PushService_1 = class PushService {
    constructor(prisma, config) {
        this.prisma = prisma;
        this.logger = new common_1.Logger(PushService_1.name);
        this.app = this.initApp(config);
        if (!this.app) {
            this.logger.warn('FIREBASE_SERVICE_ACCOUNT is not set — push notifications are disabled.');
        }
    }
    get enabled() {
        return this.app !== null;
    }
    initApp(config) {
        const raw = config.get('FIREBASE_SERVICE_ACCOUNT');
        if (!raw)
            return null;
        try {
            const json = raw.trimStart().startsWith('{')
                ? raw
                : (0, fs_1.readFileSync)(raw, 'utf8');
            const account = JSON.parse(json);
            const existing = (0, app_1.getApps)().find((a) => a.name === 'nestora-push');
            return (existing ??
                (0, app_1.initializeApp)({ credential: (0, app_1.cert)(account) }, 'nestora-push'));
        }
        catch (e) {
            this.logger.error(`Could not read FIREBASE_SERVICE_ACCOUNT: ${e.message}`);
            return null;
        }
    }
    async sendToUsers(userIds, title, body, data = {}) {
        if (!this.app || userIds.length === 0)
            return 0;
        const devices = await this.prisma.deviceToken.findMany({
            where: { userId: { in: userIds } },
            select: { token: true },
        });
        if (devices.length === 0)
            return 0;
        const tokens = devices.map((d) => d.token);
        try {
            const res = await (0, messaging_1.getMessaging)(this.app).sendEachForMulticast({
                tokens,
                notification: { title, body },
                data,
                android: { priority: 'high' },
            });
            const dead = [];
            res.responses.forEach((r, i) => {
                const code = r.error?.code;
                if (code === 'messaging/registration-token-not-registered' ||
                    code === 'messaging/invalid-registration-token' ||
                    code === 'messaging/invalid-argument') {
                    dead.push(tokens[i]);
                }
            });
            if (dead.length) {
                await this.prisma.deviceToken
                    .deleteMany({ where: { token: { in: dead } } })
                    .catch(() => null);
            }
            return res.successCount;
        }
        catch (e) {
            this.logger.error(`Push failed: ${e.message}`);
            return 0;
        }
    }
    async sendToSocietyAdmins(societyIds, title, body, data = {}) {
        if (!this.app || societyIds.length === 0)
            return 0;
        const admins = await this.prisma.user.findMany({
            where: {
                societyId: { in: societyIds },
                role: 'SOCIETY_ADMIN',
                banned: false,
                archivedAt: null,
            },
            select: { id: true },
        });
        return this.sendToUsers(admins.map((a) => a.id), title, body, data);
    }
};
exports.PushService = PushService;
exports.PushService = PushService = PushService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        config_1.ConfigService])
], PushService);
//# sourceMappingURL=push.service.js.map