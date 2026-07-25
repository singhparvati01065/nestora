-- AlterEnum
ALTER TYPE "BillKind" ADD VALUE 'OTHER';

-- AlterTable
ALTER TABLE "Bill" ADD COLUMN     "title" TEXT;

