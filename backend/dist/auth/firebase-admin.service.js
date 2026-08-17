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
var FirebaseAdminService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.FirebaseAdminService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const app_1 = require("firebase-admin/app");
const auth_1 = require("firebase-admin/auth");
const fs_1 = require("fs");
let FirebaseAdminService = FirebaseAdminService_1 = class FirebaseAdminService {
    constructor(config) {
        this.logger = new common_1.Logger(FirebaseAdminService_1.name);
        const projectId = config.get('FIREBASE_PROJECT_ID');
        if (!projectId) {
            throw new Error('FIREBASE_PROJECT_ID is not set — see backend/.env');
        }
        const account = this.readServiceAccount(config);
        this.hasCredential = account !== null;
        if (!this.hasCredential) {
            this.logger.warn('FIREBASE_SERVICE_ACCOUNT is not set — ID tokens will be verified ' +
                'without the revocation check.');
        }
        this.app =
            (0, app_1.getApps)().find((a) => a.name === 'nestora') ??
                (0, app_1.initializeApp)(account ? { projectId, credential: (0, app_1.cert)(account) } : { projectId }, 'nestora');
    }
    readServiceAccount(config) {
        const raw = config.get('FIREBASE_SERVICE_ACCOUNT');
        if (!raw)
            return null;
        try {
            const json = raw.trimStart().startsWith('{')
                ? raw
                : (0, fs_1.readFileSync)(raw, 'utf8');
            return JSON.parse(json);
        }
        catch (e) {
            this.logger.error(`Could not read FIREBASE_SERVICE_ACCOUNT: ${e.message}`);
            return null;
        }
    }
    async verify(idToken) {
        let decoded;
        try {
            decoded = await (0, auth_1.getAuth)(this.app).verifyIdToken(idToken, this.hasCredential);
        }
        catch (e) {
            this.logger.warn(`Rejected Firebase ID token: ${e.message}`);
            throw new common_1.UnauthorizedException('Invalid Firebase token');
        }
        const phone = decoded.phone_number;
        if (!phone) {
            throw new common_1.UnauthorizedException('Firebase token has no phone number');
        }
        return { uid: decoded.uid, phone };
    }
};
exports.FirebaseAdminService = FirebaseAdminService;
exports.FirebaseAdminService = FirebaseAdminService = FirebaseAdminService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], FirebaseAdminService);
//# sourceMappingURL=firebase-admin.service.js.map