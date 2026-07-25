-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- AlterTable
ALTER TABLE "AmenityBooking" ADD COLUMN     "status" "BookingStatus" NOT NULL DEFAULT 'PENDING';

