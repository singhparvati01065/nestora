"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveSocietyId = resolveSocietyId;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
function resolveSocietyId(user, explicit) {
    if (user.role === client_1.Role.SUPER_ADMIN) {
        if (!explicit) {
            throw new common_1.BadRequestException('societyId is required for super admin');
        }
        return explicit;
    }
    if (!user.societyId) {
        throw new common_1.ForbiddenException('No society associated with this account');
    }
    return user.societyId;
}
//# sourceMappingURL=society-scope.js.map