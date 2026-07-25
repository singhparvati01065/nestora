-- CreateEnum
CREATE TYPE "BillKind" AS ENUM ('RENT', 'MANUAL');

-- DropIndex
DROP INDEX "Bill_flatId_period_key";

-- AlterTable
ALTER TABLE "Bill" ADD COLUMN     "kind" "BillKind" NOT NULL DEFAULT 'MANUAL';

-- CreateIndex
CREATE UNIQUE INDEX "Bill_flatId_period_kind_key" ON "Bill"("flatId", "period", "kind");

