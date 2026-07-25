"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureRentBills = ensureRentBills;
const client_1 = require("@prisma/client");
const MONTHS = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
function lastDayOfMonth(year, month) {
    return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
}
async function ensureRentBills(prisma, societyId) {
    const now = new Date();
    const todayY = now.getFullYear();
    const todayM = now.getMonth();
    const todayD = now.getDate();
    const tenants = await prisma.resident.findMany({
        where: {
            societyId,
            archivedAt: null,
            monthlyRent: { not: null },
            moveInDate: { not: null },
        },
        select: { flatId: true, monthlyRent: true, moveInDate: true },
    });
    if (tenants.length === 0)
        return;
    const existing = await prisma.bill.findMany({
        where: { societyId, kind: client_1.BillKind.RENT },
        select: { flatId: true, period: true },
    });
    const have = new Set(existing.map((b) => `${b.flatId}|${b.period}`));
    const data = [];
    for (const t of tenants) {
        const mv = t.moveInDate;
        const baseY = mv.getFullYear();
        const baseM = mv.getMonth();
        const baseD = mv.getDate();
        let current = null;
        for (let i = 0; i < 600; i++) {
            const y = baseY + Math.floor((baseM + i) / 12);
            const m = (baseM + i) % 12;
            const d = Math.min(baseD, lastDayOfMonth(y, m));
            const dueInFuture = y > todayY ||
                (y === todayY && (m > todayM || (m === todayM && d > todayD)));
            if (dueInFuture)
                break;
            current = {
                period: `${MONTHS[m]} ${y}`,
                due: new Date(Date.UTC(y, m, d)),
            };
        }
        if (current === null)
            continue;
        const key = `${t.flatId}|${current.period}`;
        if (have.has(key))
            continue;
        have.add(key);
        data.push({
            societyId,
            flatId: t.flatId,
            period: current.period,
            amount: t.monthlyRent,
            dueDate: current.due,
            kind: client_1.BillKind.RENT,
        });
    }
    if (data.length) {
        await prisma.bill.createMany({ data, skipDuplicates: true });
    }
}
//# sourceMappingURL=rent-billing.js.map