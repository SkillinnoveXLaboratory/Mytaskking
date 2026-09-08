CREATE TYPE "RemoteControlSessionStatus" AS ENUM ('PENDING', 'ACTIVE', 'STOPPED');

CREATE TABLE "RemoteComputer" (
  "id" TEXT NOT NULL,
  "computerId" TEXT NOT NULL,
  "computerName" TEXT NOT NULL DEFAULT 'Windows computer',
  "hostUserId" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL DEFAULT 'default',
  "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "RemoteComputer_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "RemoteControlSession" (
  "id" TEXT NOT NULL,
  "computerDbId" TEXT NOT NULL,
  "hostUserId" TEXT NOT NULL,
  "controllerUserId" TEXT NOT NULL,
  "status" "RemoteControlSessionStatus" NOT NULL DEFAULT 'PENDING',
  "approvedAt" TIMESTAMP(3),
  "stoppedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "RemoteControlSession_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "RemoteComputer_tenantId_computerId_key"
  ON "RemoteComputer"("tenantId", "computerId");
CREATE INDEX "RemoteComputer_hostUserId_tenantId_idx"
  ON "RemoteComputer"("hostUserId", "tenantId");
CREATE INDEX "RemoteControlSession_computerDbId_status_idx"
  ON "RemoteControlSession"("computerDbId", "status");
CREATE INDEX "RemoteControlSession_hostUserId_createdAt_idx"
  ON "RemoteControlSession"("hostUserId", "createdAt");
CREATE INDEX "RemoteControlSession_controllerUserId_createdAt_idx"
  ON "RemoteControlSession"("controllerUserId", "createdAt");

ALTER TABLE "RemoteComputer"
  ADD CONSTRAINT "RemoteComputer_hostUserId_fkey"
  FOREIGN KEY ("hostUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "RemoteControlSession"
  ADD CONSTRAINT "RemoteControlSession_computerDbId_fkey"
  FOREIGN KEY ("computerDbId") REFERENCES "RemoteComputer"("id") ON DELETE CASCADE ON UPDATE CASCADE;
