"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.applyPlanExpiry = applyPlanExpiry;
const client_1 = require("@prisma/client");
async function applyPlanExpiry(prisma, society) {
    const expired = society.plan !== client_1.SubscriptionPlan.FREE &&
        society.planExpiresAt !== null &&
        society.planExpiresAt.getTime() <= Date.now();
    if (!expired)
        return society;
    await prisma.society
        .update({
        where: { id: society.id },
        data: { plan: client_1.SubscriptionPlan.FREE, planExpiresAt: null },
    })
        .catch(() => null);
    return { ...society, plan: client_1.SubscriptionPlan.FREE, planExpiresAt: null };
}
//# sourceMappingURL=plan.js.map