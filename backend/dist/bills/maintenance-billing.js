"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureRecurringBills = ensureRecurringBills;
exports.dueDateForPeriod = dueDateForPeriod;
exports.parseStartDate = parseStartDate;
exports.monthLabelOf = monthLabelOf;
const client_1 = require("@prisma/client");
const MONTHS = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
async function ensureRecurringBills(prisma, societyId) {
    const now = new Date();
    const nowY = now.getFullYear();
    const nowM = now.getMonth();
    const flats = await prisma.flat.findMany({
        where: { societyId, billingSince: { not: null } },
        select: {
            id: true,
            rentAmount: true,
            maintenanceAmount: true,
            billingSince: true,
        },
    });
    if (flats.length === 0)
        return;
    const existing = await prisma.bill.findMany({
        where: { societyId },
        select: { flatId: true, period: true, kind: true },
    });
    const have = new Set(existing.map((b) => `${b.flatId}|${b.period}|${b.kind}`));
    const data = [];
    const add = (flatId, period, amount, due, kind) => {
        const key = `${flatId}|${period}|${kind}`;
        if (have.has(key))
            return;
        have.add(key);
        data.push({ societyId, flatId, period, amount, dueDate: due, kind });
    };
    for (const f of flats) {
        const since = f.billingSince;
        const sY = since.getFullYear();
        const sM = since.getMonth();
        const sD = since.getDate();
        const span = Math.max(0, (nowY - sY) * 12 + (nowM - sM));
        for (let i = 0; i <= span; i++) {
            const y = sY + Math.floor((sM + i) / 12);
            const m = (sM + i) % 12;
            const period = `${MONTHS[m]} ${y}`;
            const day = Math.min(sD, lastDayOfMonth(y, m));
            const due = new Date(Date.UTC(y, m, day));
            if (f.rentAmount)
                add(f.id, period, f.rentAmount, due, client_1.BillKind.RENT);
            if (f.maintenanceAmount) {
                add(f.id, period, f.maintenanceAmount, due, client_1.BillKind.MANUAL);
            }
        }
    }
    if (data.length) {
        await prisma.bill.createMany({ data, skipDuplicates: true });
    }
}
function lastDayOfMonth(year, month) {
    return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
}
function dueDateForPeriod(period, day) {
    const parts = period.trim().split(/\s+/);
    if (parts.length !== 2)
        return null;
    const m = MONTHS.indexOf(parts[0]);
    const y = Number(parts[1]);
    if (m < 0 || !Number.isFinite(y))
        return null;
    return new Date(Date.UTC(y, m, Math.min(day, lastDayOfMonth(y, m))));
}
function parseStartDate(iso) {
    const parts = iso.trim().split('-').map(Number);
    if (parts.length < 3)
        return null;
    const [y, m, d] = parts;
    if (!y || !m || !d)
        return null;
    return new Date(Date.UTC(y, m - 1, d));
}
const MONTHS_LABEL = MONTHS;
function monthLabelOf(date) {
    return `${MONTHS_LABEL[date.getMonth()]} ${date.getFullYear()}`;
}
//# sourceMappingURL=maintenance-billing.js.map