ALTER TABLE "RemoteComputer"
  ADD COLUMN "platform" TEXT NOT NULL DEFAULT 'WINDOWS';

CREATE INDEX "RemoteComputer_hostUserId_tenantId_platform_idx"
  ON "RemoteComputer"("hostUserId", "tenantId", "platform");
