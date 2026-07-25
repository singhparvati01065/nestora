-- AlterTable
ALTER TABLE "Flat" ADD COLUMN     "billingSince" TIMESTAMP(3),
ADD COLUMN     "maintenanceAmount" DECIMAL(10,2),
ADD COLUMN     "rentAmount" DECIMAL(10,2);

