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
exports.SocietiesService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../prisma/prisma.service");
function flatNumbersFor(letter, spec) {
    const numbers = [];
    for (let floor = 1; floor <= spec.flatsPerFloor.length; floor++) {
        for (let k = 1; k <= spec.flatsPerFloor[floor - 1]; k++) {
            numbers.push(`${letter}${floor}${k.toString().padStart(2, '0')}`);
        }
    }
    return numbers;
}
function lettersFor(hasTowers, count) {
    if (!hasTowers)
        return [''];
    return Array.from({ length: count }, (_, i) => String.fromCharCode(65 + i));
}
function floorOf(number) {
    const digits = number.replace(/^[A-Za-z]*/, '');
    return parseInt(digits.slice(0, -2), 10);
}
const DEFAULT_AMENITIES = [
    { name: 'Clubhouse', icon: 'deck' },
    { name: 'Swimming Pool', icon: 'pool' },
    { name: 'Gym', icon: 'fitness_center' },
    { name: 'Party Hall', icon: 'celebration' },
    { name: 'Tennis Court', icon: 'sports_tennis' },
    { name: 'Garden Lawn', icon: 'grass' },
];
let SocietiesService = class SocietiesService {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async create(user, dto) {
        const hasTowers = dto.hasTowers ?? true;
        if (!hasTowers && dto.towers.length !== 1) {
            throw new common_1.BadRequestException('A society without towers takes exactly one set of floors');
        }
        const letters = lettersFor(hasTowers, dto.towers.length);
        const society = await this.prisma.$transaction(async (tx) => {
            const created = await tx.society.create({
                data: { name: dto.name, address: dto.address, hasTowers },
            });
            for (let t = 0; t < letters.length; t++) {
                const letter = letters[t];
                const tower = await tx.tower.create({
                    data: {
                        societyId: created.id,
                        name: hasTowers ? `Tower ${letter}` : 'Building',
                        letter,
                    },
                });
                const spec = dto.towers[t];
                const flats = flatNumbersFor(letter, spec).map((number) => ({
                    societyId: created.id,
                    towerId: tower.id,
                    number,
                    floor: floorOf(number),
                }));
                if (flats.length)
                    await tx.flat.createMany({ data: flats });
            }
            await tx.amenity.createMany({
                data: DEFAULT_AMENITIES.map((a) => ({
                    societyId: created.id,
                    name: a.name,
                    icon: a.icon,
                })),
            });
            if (user.role === client_1.Role.SOCIETY_ADMIN && !user.societyId) {
                await tx.user.update({
                    where: { id: user.sub },
                    data: { societyId: created.id },
                });
            }
            return created;
        });
        return this.findOne(society.id);
    }
    async update(user, id, dto) {
        if (user.role !== client_1.Role.SUPER_ADMIN && user.societyId !== id) {
            throw new common_1.ForbiddenException('Not your society');
        }
        const society = await this.prisma.society.findUnique({
            where: { id },
            include: { towers: { include: { flats: true } } },
        });
        if (!society)
            throw new common_1.NotFoundException('Society not found');
        const hasTowers = dto.hasTowers ?? society.hasTowers;
        if (!hasTowers && dto.towers.length !== 1) {
            throw new common_1.BadRequestException('A society without towers takes exactly one set of floors');
        }
        const letters = lettersFor(hasTowers, dto.towers.length);
        const desired = new Map();
        letters.forEach((letter, i) => desired.set(letter, flatNumbersFor(letter, dto.towers[i])));
        const doomed = society.towers.flatMap((tower) => {
            const keep = new Set(desired.get(tower.letter) ?? []);
            return tower.flats.filter((f) => !keep.has(f.number));
        });
        if (doomed.length && !dto.force) {
            const impact = await this.impactOf(doomed.map((f) => f.id));
            const losses = Object.values(impact).reduce((a, b) => a + b, 0);
            if (losses > 0) {
                throw new common_1.ConflictException({
                    message: 'This change would delete flats that still have data',
                    code: 'DESTRUCTIVE_STRUCTURE_CHANGE',
                    flats: doomed.length,
                    flatNumbers: doomed.map((f) => f.number).sort(),
                    impact,
                });
            }
        }
        await this.prisma.$transaction(async (tx) => {
            if (hasTowers !== society.hasTowers) {
                await tx.society.update({ where: { id }, data: { hasTowers } });
            }
            for (const [letter, numbers] of desired) {
                const tower = society.towers.find((t) => t.letter === letter) ??
                    (await tx.tower.create({
                        data: {
                            societyId: id,
                            name: hasTowers ? `Tower ${letter}` : 'Building',
                            letter,
                        },
                    }));
                const existing = new Set(society.towers
                    .find((t) => t.letter === letter)
                    ?.flats.map((f) => f.number) ?? []);
                const toAdd = numbers
                    .filter((n) => !existing.has(n))
                    .map((number) => ({
                    societyId: id,
                    towerId: tower.id,
                    number,
                    floor: floorOf(number),
                }));
                if (toAdd.length)
                    await tx.flat.createMany({ data: toAdd });
            }
            if (doomed.length) {
                await tx.flat.deleteMany({
                    where: { id: { in: doomed.map((f) => f.id) } },
                });
            }
            const dropped = society.towers.filter((t) => !desired.has(t.letter));
            if (dropped.length) {
                await tx.tower.deleteMany({
                    where: { id: { in: dropped.map((t) => t.id) } },
                });
            }
        });
        return this.findOne(id);
    }
    async updateProfile(user, id, dto) {
        if (user.role !== client_1.Role.SUPER_ADMIN && user.societyId !== id) {
            throw new common_1.ForbiddenException('Not your society');
        }
        const data = {};
        if (dto.name !== undefined)
            data.name = dto.name.trim();
        if (dto.address !== undefined)
            data.address = dto.address.trim();
        if (dto.logoUrl !== undefined)
            data.logoUrl = dto.logoUrl;
        await this.prisma.society.update({ where: { id }, data });
        return this.findOne(id);
    }
    async impactOf(flatIds) {
        const where = { flatId: { in: flatIds } };
        const [residents, bills, complaints, deliveries, preApproved, bookings] = await Promise.all([
            this.prisma.resident.count({ where }),
            this.prisma.bill.count({ where }),
            this.prisma.complaint.count({ where }),
            this.prisma.delivery.count({ where }),
            this.prisma.preApprovedVisitor.count({ where }),
            this.prisma.amenityBooking.count({ where }),
        ]);
        return { residents, bills, complaints, deliveries, preApproved, bookings };
    }
    async findOne(id) {
        const society = await this.prisma.society.findUnique({
            where: { id },
            include: {
                towers: {
                    orderBy: { letter: 'asc' },
                    include: {
                        flats: { orderBy: [{ floor: 'asc' }, { number: 'asc' }] },
                    },
                },
            },
        });
        if (!society)
            throw new common_1.NotFoundException('Society not found');
        const totalFlats = society.towers.reduce((n, t) => n + t.flats.length, 0);
        const floors = society.towers.map((t) => t.flats.reduce((mx, f) => Math.max(mx, f.floor), 0));
        return {
            ...society,
            stats: {
                towers: society.towers.length,
                flats: totalFlats,
                minFloors: floors.length ? Math.min(...floors) : 0,
                maxFloors: floors.length ? Math.max(...floors) : 0,
            },
        };
    }
    async flats(societyId) {
        return this.prisma.flat.findMany({
            where: { societyId },
            orderBy: [{ number: 'asc' }],
            select: { id: true, number: true, floor: true, towerId: true },
        });
    }
};
exports.SocietiesService = SocietiesService;
exports.SocietiesService = SocietiesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], SocietiesService);
//# sourceMappingURL=societies.service.js.map