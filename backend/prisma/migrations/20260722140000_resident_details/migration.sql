-- AlterTable
ALTER TABLE "Resident" ADD COLUMN     "documentUrls" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "familyMembers" INTEGER,
ADD COLUMN     "occupation" TEXT;

