'use strict';

const prisma = require('../../database/prisma');
const { BadRequest, Conflict } = require('../../utils/errors');

const ACTIVE_SESSION_TTL_MS = 90 * 1000;

function activeSessionCutoff() {
  return new Date(Date.now() - ACTIVE_SESSION_TTL_MS);
}

async function expireStaleSessions() {
  return prisma.remoteControlSession.updateMany({
    where: { status: 'ACTIVE', lastHeartbeatAt: { lt: activeSessionCutoff() } },
    data: { status: 'STOPPED', stoppedAt: new Date() },
  });
}

function idForComputer(computerId) {
  return String(computerId || '').trim().toUpperCase();
}

function publicComputer(computer) {
  return {
    id: computer.id,
    computerId: computer.computerId,
    computerName: computer.computerName,
    hostUserId: computer.hostUserId,
    tenantId: computer.tenantId,
    platform: computer.platform,
    lastSeenAt: computer.lastSeenAt,
    createdAt: computer.createdAt,
    updatedAt: computer.updatedAt,
  };
}

function publicSession(session) {
  return {
    id: session.id,
    computerId: session.computer.computerId,
    computerName: session.computer.computerName,
    hostUserId: session.hostUserId,
    controllerUserId: session.controllerUserId,
    status: session.status,
    createdAt: session.createdAt,
    approvedAt: session.approvedAt,
    stoppedAt: session.stoppedAt,
    lastHeartbeatAt: session.lastHeartbeatAt,
    lastSeenAt: session.computer.lastSeenAt,
  };
}

async function listComputers(hostUserId, tenantId, platform) {
  const computers = await prisma.remoteComputer.findMany({
    where: { hostUserId, tenantId, ...(platform ? { platform } : {}) },
    orderBy: { updatedAt: 'desc' },
  });
  return computers.map(publicComputer);
}

async function registerComputer({ computerId, computerName, platform, hostUserId, tenantId }) {
  const normalizedId = idForComputer(computerId);
  if (!normalizedId) throw BadRequest('computerId is required');

  const existing = await prisma.remoteComputer.findUnique({
    where: { tenantId_computerId: { tenantId, computerId: normalizedId } },
  });
  if (existing && existing.hostUserId !== hostUserId) {
    throw Conflict('Computer ID is already registered to another host');
  }

  const computer = await prisma.remoteComputer.upsert({
    where: { tenantId_computerId: { tenantId, computerId: normalizedId } },
    create: {
      computerId: normalizedId,
      computerName: computerName || 'Windows computer',
      hostUserId,
      tenantId,
      platform,
    },
    update: {
      computerName: computerName || undefined,
      platform,
      lastSeenAt: new Date(),
    },
  });
  return publicComputer(computer);
}

async function renameComputer({ id, computerName, hostUserId, tenantId }) {
  const result = await prisma.remoteComputer.updateMany({
    where: { id, hostUserId, tenantId },
    data: { computerName, lastSeenAt: new Date() },
  });
  if (result.count === 0) return null;
  const computer = await prisma.remoteComputer.findUnique({ where: { id } });
  return publicComputer(computer);
}

async function requestSession({ computerId, controllerUserId, tenantId }) {
  const normalizedId = idForComputer(computerId);
  await expireStaleSessions();
  return prisma.$transaction(async (tx) => {
    const computer = await tx.remoteComputer.findUnique({
      where: { tenantId_computerId: { tenantId, computerId: normalizedId } },
    });
    if (!computer) return null;
    if (computer.hostUserId === controllerUserId) {
      throw BadRequest('You cannot control your own computer');
    }

    const existing = await tx.remoteControlSession.findFirst({
      where: {
        computerDbId: computer.id,
        status: { in: ['PENDING', 'ACTIVE'] },
      },
    });
    if (existing) throw Conflict('Computer already has a remote-control session');

    const session = await tx.remoteControlSession.create({
      data: {
        computerDbId: computer.id,
        hostUserId: computer.hostUserId,
        controllerUserId,
      },
      include: { computer: true },
    });
    await tx.remoteComputer.update({
      where: { id: computer.id },
      data: { lastSeenAt: new Date() },
    });
    return publicSession(session);
  });
}

async function approve(id, hostUserId) {
  const result = await prisma.remoteControlSession.updateMany({
    where: { id, hostUserId, status: 'PENDING' },
    data: { status: 'ACTIVE', approvedAt: new Date(), lastHeartbeatAt: new Date() },
  });
  if (result.count === 0) return null;
  const session = await prisma.remoteControlSession.findUnique({
    where: { id },
    include: { computer: true },
  });
  return publicSession(session);
}

async function stop(id, userId) {
  const result = await prisma.remoteControlSession.updateMany({
    where: {
      id,
      status: { in: ['PENDING', 'ACTIVE'] },
      OR: [{ hostUserId: userId }, { controllerUserId: userId }],
    },
    data: { status: 'STOPPED', stoppedAt: new Date() },
  });
  if (result.count === 0) return null;
  const session = await prisma.remoteControlSession.findUnique({
    where: { id },
    include: { computer: true },
  });
  return publicSession(session);
}

async function canUse(id, userId, status = 'ACTIVE') {
  const session = await prisma.remoteControlSession.findFirst({
    where: {
      id,
      status,
      ...(status === 'ACTIVE' ? { lastHeartbeatAt: { gte: activeSessionCutoff() } } : {}),
      OR: [{ hostUserId: userId }, { controllerUserId: userId }],
    },
    select: { id: true },
  });
  return session !== null;
}

async function heartbeat(id, userId) {
  const result = await prisma.remoteControlSession.updateMany({
    where: {
      id,
      status: 'ACTIVE',
      OR: [{ hostUserId: userId }, { controllerUserId: userId }],
    },
    data: { lastHeartbeatAt: new Date() },
  });
  return result.count > 0;
}

async function listForUser(userId, tenantId) {
  await expireStaleSessions();
  const sessions = await prisma.remoteControlSession.findMany({
    where: {
      computer: { is: { tenantId } },
      OR: [{ hostUserId: userId }, { controllerUserId: userId }],
    },
    include: { computer: true },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });
  return sessions.map(publicSession);
}

module.exports = {
  listComputers,
  registerComputer,
  renameComputer,
  requestSession,
  approve,
  stop,
  canUse,
  heartbeat,
  expireStaleSessions,
  listForUser,
};
