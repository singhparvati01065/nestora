-- AlterTable
ALTER TABLE "Bill" ADD COLUMN     "dueDate" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "Resident" ADD COLUMN     "monthlyRent" DECIMAL(10,2),
ADD COLUMN     "moveInDate" TIMESTAMP(3);

