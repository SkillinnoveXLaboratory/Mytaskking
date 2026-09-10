ALTER TABLE "RemoteControlSession"
ADD COLUMN "lastHeartbeatAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX "RemoteControlSession_status_lastHeartbeatAt_idx"
ON "RemoteControlSession"("status", "lastHeartbeatAt");
