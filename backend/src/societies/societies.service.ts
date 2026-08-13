import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { AuthUser } from '../auth/decorators/current-user.decorator';
import { applyPlanExpiry } from '../platform/plan';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSocietyDto, TowerSpecDto } from './dto/create-society.dto';
import { UpdateSocietyDto } from './dto/update-society.dto';
import { UpdateSocietyProfileDto } from './dto/update-society-profile.dto';

/// Flat numbers are `{letter}{floor}{index:2}` — e.g. Tower A, floor 1, flat 3
/// → `A103`. A society without towers has an empty letter, so its flats read
/// `103`. Both create and update derive numbers here so they cannot drift.
function flatNumbersFor(letter: string, spec: TowerSpecDto): string[] {
  const numbers: string[] = [];
  for (let floor = 1; floor <= spec.flatsPerFloor.length; floor++) {
    for (let k = 1; k <= spec.flatsPerFloor[floor - 1]; k++) {
      numbers.push(`${letter}${floor}${k.toString().padStart(2, '0')}`);
    }
  }
  return numbers;
}

/// The letters a society's towers use, in order. A society without towers has
/// exactly one, unlettered.
function lettersFor(hasTowers: boolean, count: number): string[] {
  if (!hasTowers) return [''];
  return Array.from({ length: count }, (_, i) => String.fromCharCode(65 + i));
}

/// Reads the floor back out of a flat number: strip any leading letters, drop
/// the trailing 2-digit index, and what's left is the floor.
///
/// Must not assume a single leading letter — `'103'.slice(1, -2)` is empty and
/// parses to NaN, which would have written garbage floors for tower-less
/// societies.
function floorOf(number: string): number {
  const digits = number.replace(/^[A-Za-z]*/, '');
  return parseInt(digits.slice(0, -2), 10);
}

/// Default amenities seeded for every new society (name → Material icon key,
/// matching the Flutter client).
const DEFAULT_AMENITIES: { name: string; icon: string }[] = [
  { name: 'Clubhouse', icon: 'deck' },
  { name: 'Swimming Pool', icon: 'pool' },
  { name: 'Gym', icon: 'fitness_center' },
  { name: 'Party Hall', icon: 'celebration' },
  { name: 'Tennis Court', icon: 'sports_tennis' },
  { name: 'Garden Lawn', icon: 'grass' },
];

@Injectable()
export class SocietiesService {
  constructor(private prisma: PrismaService) {}

  /// Creates a society, generating its towers + flats from the specs, plus the
  /// default amenities. If the creator is a society admin without a society, it
  /// links them to the new society.
  async create(user: AuthUser, dto: CreateSocietyDto) {
    const hasTowers = dto.hasTowers ?? true;
    // One building means one unlettered tower. Anything else would be silently
    // dropped, so say so instead.
    if (!hasTowers && dto.towers.length !== 1) {
      throw new BadRequestException(
        'A society without towers takes exactly one set of floors',
      );
    }
    const letters = lettersFor(hasTowers, dto.towers.length);

    const society = await this.prisma.$transaction(async (tx) => {
      const created = await tx.society.create({
        data: {
          name: dto.name,
          address: dto.address,
          city: dto.city?.trim() || null,
          state: dto.state?.trim() || null,
          hasTowers,
        },
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
        const flats: Prisma.FlatCreateManyInput[] = flatNumbersFor(
          letter,
          spec,
        ).map((number) => ({
          societyId: created.id,
          towerId: tower.id,
          number,
          floor: floorOf(number),
        }));
        if (flats.length) await tx.flat.createMany({ data: flats });
      }

      await tx.amenity.createMany({
        data: DEFAULT_AMENITIES.map((a) => ({
          societyId: created.id,
          name: a.name,
          icon: a.icon,
        })),
      });

      if (user.role === Role.SOCIETY_ADMIN && !user.societyId) {
        await tx.user.update({
          where: { id: user.sub },
          data: { societyId: created.id },
        });
      }

      return created;
    });

    return this.findOne(society.id);
  }

  /**
   * Rewrites the tower/flat structure, preserving everything that survives.
   *
   * Flats are matched by number, so a flat that exists in both the old and new
   * spec is left completely untouched — its residents, bills and complaints
   * ride along. Only flats outside the new spec are deleted, and because most
   * of those relations cascade, that deletion is refused unless the caller has
   * seen the damage report and passed `force`.
   */
  async update(user: AuthUser, id: string, dto: UpdateSocietyDto) {
    if (user.role !== Role.SUPER_ADMIN && user.societyId !== id) {
      throw new ForbiddenException('Not your society');
    }

    const society = await this.prisma.society.findUnique({
      where: { id },
      include: { towers: { include: { flats: true } } },
    });
    if (!society) throw new NotFoundException('Society not found');

    // Omitted means "keep the current layout".
    const hasTowers = dto.hasTowers ?? society.hasTowers;
    if (!hasTowers && dto.towers.length !== 1) {
      throw new BadRequestException(
        'A society without towers takes exactly one set of floors',
      );
    }

    // What the new spec asks for, as tower letter → flat numbers. Switching
    // layout changes every letter, so every old flat falls outside the new spec
    // and the destructive-change guard below reports the full cost.
    const letters = lettersFor(hasTowers, dto.towers.length);
    const desired = new Map<string, string[]>();
    letters.forEach((letter, i) =>
      desired.set(letter, flatNumbersFor(letter, dto.towers[i])),
    );

    // Every flat not named by the new spec is on the chopping block. A tower
    // dropped entirely lands here too, via all of its flats.
    const doomed = society.towers.flatMap((tower) => {
      const keep = new Set(desired.get(tower.letter) ?? []);
      return tower.flats.filter((f) => !keep.has(f.number));
    });

    // Dropping empty flats costs nothing, so it needs no confirmation — only a
    // flat that would take real records down with it does.
    if (doomed.length && !dto.force) {
      const impact = await this.impactOf(doomed.map((f) => f.id));
      const losses = Object.values(impact).reduce((a, b) => a + b, 0);
      if (losses > 0) {
        throw new ConflictException({
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
        const tower =
          society.towers.find((t) => t.letter === letter) ??
          (await tx.tower.create({
            data: {
              societyId: id,
              name: hasTowers ? `Tower ${letter}` : 'Building',
              letter,
            },
          }));

        const existing = new Set(
          society.towers
            .find((t) => t.letter === letter)
            ?.flats.map((f) => f.number) ?? [],
        );
        const toAdd = numbers
          .filter((n) => !existing.has(n))
          .map((number) => ({
            societyId: id,
            towerId: tower.id,
            number,
            floor: floorOf(number),
          }));
        if (toAdd.length) await tx.flat.createMany({ data: toAdd });
      }

      if (doomed.length) {
        await tx.flat.deleteMany({
          where: { id: { in: doomed.map((f) => f.id) } },
        });
      }

      // Towers the new spec no longer names. Their flats are already gone.
      const dropped = society.towers.filter((t) => !desired.has(t.letter));
      if (dropped.length) {
        await tx.tower.deleteMany({
          where: { id: { in: dropped.map((t) => t.id) } },
        });
      }
    });

    return this.findOne(id);
  }

  /// Updates the society's name/address/logo. Structure is untouched here, so
  /// none of the destructive-change checks apply.
  async updateProfile(
    user: AuthUser,
    id: string,
    dto: UpdateSocietyProfileDto,
  ) {
    if (user.role !== Role.SUPER_ADMIN && user.societyId !== id) {
      throw new ForbiddenException('Not your society');
    }
    const data: Prisma.SocietyUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.address !== undefined) data.address = dto.address.trim();
    // Blank means "no longer set", not an empty string in the panel's column.
    if (dto.city !== undefined) data.city = dto.city.trim() || null;
    if (dto.state !== undefined) data.state = dto.state.trim() || null;
    if (dto.logoUrl !== undefined) data.logoUrl = dto.logoUrl;

    await this.prisma.society.update({ where: { id }, data });
    return this.findOne(id);
  }

  /// Counts what would be destroyed along with [flatIds]. Only the relations
  /// that cascade are counted — `User.flatId` and `Visitor.flatId` null out
  /// instead, so those rows survive.
  private async impactOf(flatIds: string[]) {
    const where = { flatId: { in: flatIds } };
    const [residents, bills, complaints, deliveries, preApproved, bookings] =
      await Promise.all([
        this.prisma.resident.count({ where }),
        this.prisma.bill.count({ where }),
        this.prisma.complaint.count({ where }),
        this.prisma.delivery.count({ where }),
        this.prisma.preApprovedVisitor.count({ where }),
        this.prisma.amenityBooking.count({ where }),
      ]);
    return { residents, bills, complaints, deliveries, preApproved, bookings };
  }

  async findOne(id: string) {
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
    if (!society) throw new NotFoundException('Society not found');
    // Never report a premium plan that has already run out.
    const current = await applyPlanExpiry(this.prisma, society);

    const totalFlats = society.towers.reduce((n, t) => n + t.flats.length, 0);
    const floors = society.towers.map((t) =>
      t.flats.reduce((mx, f) => Math.max(mx, f.floor), 0),
    );
    return {
      ...current,
      stats: {
        towers: society.towers.length,
        flats: totalFlats,
        minFloors: floors.length ? Math.min(...floors) : 0,
        maxFloors: floors.length ? Math.max(...floors) : 0,
      },
    };
  }

  async flats(societyId: string) {
    return this.prisma.flat.findMany({
      where: { societyId },
      orderBy: [{ number: 'asc' }],
      select: { id: true, number: true, floor: true, towerId: true },
    });
  }
}
