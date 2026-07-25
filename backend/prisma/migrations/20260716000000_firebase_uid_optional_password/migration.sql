-- AlterTable
ALTER TABLE "User" ADD COLUMN     "firebaseUid" TEXT,
ALTER COLUMN "password" DROP NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "User_firebaseUid_key" ON "User"("firebaseUid");

