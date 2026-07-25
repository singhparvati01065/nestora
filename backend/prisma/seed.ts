import {
  ComplaintStatus,
  PrismaClient,
  ResidentType,
  Role,
  VisitorStatus,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const DEFAULT_AMENITIES = [
  { name: 'Clubhouse', icon: 'deck' },
  { name: 'Swimming Pool', icon: 'pool' },
  { name: 'Gym', icon: 'fitness_center' },
  { name: 'Party Hall', icon: 'celebration' },
  { name: 'Tennis Court', icon: 'sports_tennis' },
  { name: 'Garden Lawn', icon: 'grass' },
];

// Per-tower per-floor flat counts. Tower A: 3 floors × 3, Tower B: 2 floors × 2.
const TOWER_SPECS = [[3, 3, 3], [2, 2]];

async function main() {
  console.log('Clearing existing data…');
  // Delete in FK-safe order.
  await prisma.amenityBooking.deleteMany();
  await prisma.amenity.deleteMany();
  await prisma.delivery.deleteMany();
  await prisma.preApprovedVisitor.deleteMany();
  await prisma.visitor.deleteMany();
  await prisma.complaint.deleteMany();
  await prisma.bill.deleteMany();
  await prisma.notice.deleteMany();
  await prisma.resident.deleteMany();
  await prisma.user.deleteMany();
  await prisma.flat.deleteMany();
  await prisma.tower.deleteMany();
  await prisma.society.deleteMany();

  console.log('Creating society + towers + flats…');
  const society = await prisma.society.create({
    data: { name: 'Green Valley Residency', address: 'Sector 21, Gurugram 122001' },
  });

  for (let t = 0; t < TOWER_SPECS.length; t++) {
    const letter = String.fromCharCode(65 + t);
    const tower = await prisma.tower.create({
      data: { societyId: society.id, name: `Tower ${letter}`, letter },
    });
    const spec = TOWER_SPECS[t];
    for (let floor = 1; floor <= spec.length; floor++) {
      for (let k = 1; k <= spec[floor - 1]; k++) {
        const idx = k.toString().padStart(2, '0');
        await prisma.flat.create({
          data: {
            societyId: society.id,
            towerId: tower.id,
            number: `${letter}${floor}${idx}`,
            floor,
          },
        });
      }
    }
  }

  await prisma.amenity.createMany({
    data: DEFAULT_AMENITIES.map((a) => ({ ...a, societyId: society.id })),
  });

  const flats = await prisma.flat.findMany({
    where: { societyId: society.id },
    orderBy: { number: 'asc' },
  });
  const flatByNumber = Object.fromEntries(flats.map((f) => [f.number, f]));

  console.log('Creating users (one per role)…');
  const hash = (pw: string) => bcrypt.hash(pw, 10);
  await prisma.user.createMany({
    data: [
      {
        phone: '9999999999',
        password: await hash('super123'),
        name: 'Super Admin',
        role: Role.SUPER_ADMIN,
      },
      {
        phone: '9876543210',
        password: await hash('admin123'),
        name: 'Society Admin',
        role: Role.SOCIETY_ADMIN,
        societyId: society.id,
      },
      {
        phone: '9876500001',
        password: await hash('guard123'),
        name: 'Gate Guard',
        role: Role.SECURITY_GUARD,
        societyId: society.id,
      },
      {
        phone: '9876500002',
        password: await hash('resident123'),
        name: 'Rahul Sharma',
        role: Role.RESIDENT,
        societyId: society.id,
        flatId: flatByNumber['A101'].id,
      },
      {
        phone: '9876500003',
        password: await hash('staff123'),
        name: 'Suresh',
        role: Role.MAINTENANCE_STAFF,
        societyId: society.id,
        staffLabel: 'Suresh (Plumber)',
      },
    ],
  });

  console.log('Creating residents, notices, bills, complaints, gate data…');
  const residentSeed: [string, string, string, ResidentType][] = [
    ['Rahul Sharma', '9876543210', 'A101', ResidentType.OWNER],
    ['Priya Nair', '9812345678', 'A102', ResidentType.OWNER],
    ['Amit Verma', '9900011122', 'A103', ResidentType.TENANT],
    ['Sneha Iyer', '9765432109', 'A201', ResidentType.OWNER],
  ];
  await prisma.resident.createMany({
    data: residentSeed.map(([name, phone, flat, type]) => ({
      societyId: society.id,
      flatId: flatByNumber[flat].id,
      name,
      phone,
      type,
    })),
  });

  await prisma.notice.createMany({
    data: [
      {
        societyId: society.id,
        title: 'Water supply maintenance',
        body: 'Water supply will be interrupted on Saturday from 10 AM to 2 PM for tank cleaning.',
        pinned: true,
      },
      {
        societyId: society.id,
        title: 'Diwali celebration',
        body: 'Join us in the clubhouse this Sunday at 6 PM for the society get-together!',
      },
      {
        societyId: society.id,
        title: 'Parking rules reminder',
        body: 'Kindly park only in your allotted slot. Visitors must register at the gate.',
      },
    ],
  });

  await prisma.bill.createMany({
    data: flats.map((f, i) => ({
      societyId: society.id,
      flatId: f.id,
      period: 'Jul 2026',
      amount: 2500,
      paid: i % 3 !== 0,
    })),
  });

  await prisma.complaint.createMany({
    data: [
      {
        societyId: society.id,
        flatId: flatByNumber['A201'].id,
        title: 'Lift not working',
        description: 'The elevator has been stuck on the ground floor since morning.',
        category: 'Elevator',
        status: ComplaintStatus.OPEN,
      },
      {
        societyId: society.id,
        flatId: flatByNumber['A102'].id,
        title: 'Water leakage in ceiling',
        description: 'There is a leak from the ceiling in the bedroom.',
        category: 'Plumbing',
        status: ComplaintStatus.IN_PROGRESS,
        assignedTo: 'Suresh (Plumber)',
      },
      {
        societyId: society.id,
        flatId: flatByNumber['A103'].id,
        title: 'Corridor light fused',
        description: 'The light in the 2nd floor corridor is not working.',
        category: 'Electrical',
        status: ComplaintStatus.RESOLVED,
        assignedTo: 'Ramesh (Electrician)',
      },
    ],
  });

  await prisma.preApprovedVisitor.createMany({
    data: [
      {
        societyId: society.id,
        flatId: flatByNumber['A201'].id,
        name: 'Anjali (Sister)',
        purpose: 'Guest',
        validLabel: 'Today, till 8 PM',
      },
      {
        societyId: society.id,
        flatId: flatByNumber['A102'].id,
        name: 'Swiggy Genie',
        purpose: 'Delivery',
        validLabel: 'Today, till 6 PM',
      },
    ],
  });

  await prisma.visitor.createMany({
    data: [
      {
        societyId: society.id,
        flatId: flatByNumber['A101'].id,
        name: 'Ravi Kumar',
        purpose: 'Guest',
        status: VisitorStatus.INSIDE,
      },
      {
        societyId: society.id,
        flatId: flatByNumber['A102'].id,
        name: 'Zomato Delivery',
        purpose: 'Delivery',
        status: VisitorStatus.EXITED,
        outAt: new Date(),
      },
    ],
  });

  await prisma.delivery.createMany({
    data: [
      { societyId: society.id, flatId: flatByNumber['A103'].id, courier: 'Amazon' },
      {
        societyId: society.id,
        flatId: flatByNumber['A201'].id,
        courier: 'Flipkart',
        collected: true,
      },
    ],
  });

  console.log('✅ Seed complete.');
  console.log('Logins (phone / password):');
  console.log('  Super Admin       9999999999 / super123');
  console.log('  Society Admin     9876543210 / admin123');
  console.log('  Security Guard    9876500001 / guard123');
  console.log('  Resident (A101)   9876500002 / resident123');
  console.log('  Maintenance Staff 9876500003 / staff123');
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
