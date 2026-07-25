# Nestora Backend

NestJS + Prisma + PostgreSQL API for the Nestora society-management app.

## Stack
- **NestJS 10** — modular REST API
- **Prisma** — ORM + migrations (`prisma/schema.prisma`)
- **PostgreSQL** — data store
- **JWT auth** — phone + password, role-based access control (RBAC)

## Setup

```bash
cd backend
npm install

# 1. Create the database (once)
createdb -U postgres nestora     # or: psql -U postgres -c "CREATE DATABASE nestora;"

# 2. Configure .env (already created for local dev — uses the unix socket, no password)
#    DATABASE_URL="postgresql://postgres@localhost:5432/nestora?host=/tmp&schema=public"

# 3. Apply migrations + generate client
npx prisma migrate dev

# 4. Seed demo data (society, flats, one user per role, sample records)
npx prisma db seed

# 5. Run
npm run start:dev        # watch mode
# or: npm run build && node dist/main.js
```

API is served at `http://localhost:3000/api`.

## Seeded logins (phone / password)

| Role              | Phone       | Password    |
|-------------------|-------------|-------------|
| Super Admin       | 9999999999  | super123    |
| Society Admin     | 9876543210  | admin123    |
| Security Guard    | 9876500001  | guard123    |
| Resident (A101)   | 9876500002  | resident123 |
| Maintenance Staff | 9876500003  | staff123    |

## Auth

`POST /api/auth/register`, `POST /api/auth/login` → `{ accessToken, user }`.
Send `Authorization: Bearer <token>` on every other request.
`GET /api/auth/me` returns the current user.

Roles: `SUPER_ADMIN`, `SOCIETY_ADMIN`, `SECURITY_GUARD`, `RESIDENT`, `MAINTENANCE_STAFF`.
Requests are scoped to the caller's society (super admin passes `?societyId=`).

## Endpoints (all under `/api`)

- **Societies** — `POST /societies` (admin, generates towers+flats+amenities), `GET /societies/mine`, `GET /societies/:id`, `GET /societies/:id/flats`
- **Residents** — `GET /residents`, `POST /residents` (admin), `DELETE /residents/:id` (admin)
- **Notices** — `GET /notices`, `POST /notices` (admin), `PATCH /notices/:id/pin` (admin), `DELETE /notices/:id` (admin)
- **Bills** — `GET /bills` (residents auto-scoped to their flat), `POST /bills/generate` (admin), `PATCH /bills/:id/pay`, `PATCH /bills/:id/unpay` (admin)
- **Complaints** — `GET /complaints` (`?flatId=`, `?assignedTo=`, `?unassigned=true`), `GET /complaints/staff`, `POST /complaints`, `PATCH /complaints/:id/status`, `PATCH /complaints/:id/assign`
- **Visitors** — `GET /visitors` (with summary), `POST /visitors` (guard), `PATCH /visitors/:id/checkout` (guard)
- **Pre-approved** — `GET /pre-approved` (guard sees all, resident sees own), `POST /pre-approved` (resident), `PATCH /pre-approved/:id/check-in` (guard → creates a Visitor)
- **Deliveries** — `GET /deliveries`, `POST /deliveries` (guard), `PATCH /deliveries/:id/collected` (guard)
- **Amenities** — `GET /amenities`, `GET /amenities/bookings` (resident), `POST /amenities/book` (resident)

## Notes
- `.env`, `dist/`, and `node_modules/` are git-ignored. The dev DB uses trust auth over the local unix socket; set a real user/password + `sslmode` for production, and change `JWT_SECRET`.
