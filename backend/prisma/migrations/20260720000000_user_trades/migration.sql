-- AlterTable
ALTER TABLE "User" ADD COLUMN     "trades" TEXT[] DEFAULT ARRAY[]::TEXT[];

