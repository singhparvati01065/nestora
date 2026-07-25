-- Backfill any null titles, then make title required with an empty default.
UPDATE "Bill" SET "title" = '' WHERE "title" IS NULL;
ALTER TABLE "Bill" ALTER COLUMN "title" SET DEFAULT '';
ALTER TABLE "Bill" ALTER COLUMN "title" SET NOT NULL;

-- Swap the uniqueness key to include title (lets multiple OTHER charges share a month).
DROP INDEX "Bill_flatId_period_kind_key";
CREATE UNIQUE INDEX "Bill_flatId_period_kind_title_key" ON "Bill"("flatId", "period", "kind", "title");
