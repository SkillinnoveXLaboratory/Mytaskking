'use strict';

const crypto = require('node:crypto');

const sessions = new Map();

function publicSession(session) {
  return {
    id: session.id,
    computerId: session.computerId,
    computerName: session.computerName,
    hostUserId: session.hostUserId,
    controllerUserId: session.controllerUserId,
    status: session.status,
    createdAt: session.createdAt,
    approvedAt: session.approvedAt || null,
    stoppedAt: session.stoppedAt || null,
    lastSeenAt: session.lastSeenAt,
  };
}

function idForComputer(computerId) {
  return String(computerId || '').trim().toUpperCase();
}

function registerComputer({ computerId, computerName, hostUserId, tenantId }) {
  const id = idForComputer(computerId);
  if (!id) throw new Error('computerId is required');
  const existing = [...sessions.values()].find(
    (s) => s.computerId === id && s.hostUserId === hostUserId && s.status !== 'STOPPED',
  );
  if (existing) {
    existing.computerName = computerName || existing.computerName;
    existing.lastSeenAt = new Date().toISOString();
    return publicSession(existing);
  }
  const session = {
    id: crypto.randomUUID(),
    computerId: id,
    computerName: computerName || 'Windows computer',
    hostUserId,
    tenantId: tenantId || null,
    controllerUserId: null,
    status: 'AVAILABLE',
    createdAt: new Date().toISOString(),
    lastSeenAt: new Date().toISOString(),
  };
  sessions.set(session.id, session);
  return publicSession(session);
}

function findComputer(computerId, tenantId) {
  const id = idForComputer(computerId);
  return [...sessions.values()].find(
    (s) => s.computerId === id && (!tenantId || !s.tenantId || s.tenantId === tenantId) && s.status !== 'STOPPED',
  );
}

function requestSession({ computerId, controllerUserId, tenantId }) {
  const host = findComputer(computerId, tenantId);
  if (!host) return null;
  if (host.hostUserId === controllerUserId) throw new Error('You cannot control your own computer');
  if (host.status === 'PENDING' || host.status === 'ACTIVE') throw new Error('Computer already has a remote-control session');
  host.controllerUserId = controllerUserId;
  host.status = 'PENDING';
  host.lastSeenAt = new Date().toISOString();
  return publicSession(host);
}

function approve(id, hostUserId) {
  const session = sessions.get(id);
  if (!session || session.hostUserId !== hostUserId || session.status !== 'PENDING') return null;
  session.status = 'ACTIVE';
  session.approvedAt = new Date().toISOString();
  session.lastSeenAt = session.approvedAt;
  return publicSession(session);
}

function stop(id, userId) {
  const session = sessions.get(id);
  if (!session || (session.hostUserId !== userId && session.controllerUserId !== userId)) return null;
  session.status = 'STOPPED';
  session.stoppedAt = new Date().toISOString();
  return publicSession(session);
}

function get(id) {
  const session = sessions.get(id);
  return session ? publicSession(session) : null;
}

function canUse(id, userId, status = 'ACTIVE') {
  const session = sessions.get(id);
  return !!session && session.status === status &&
    (session.hostUserId === userId || session.controllerUserId === userId);
}

function listForUser(userId, tenantId) {
  return [...sessions.values()]
    .filter((s) => s.tenantId === tenantId && (s.hostUserId === userId || s.controllerUserId === userId) && s.status !== 'STOPPED')
    .map(publicSession);
}

module.exports = { registerComputer, requestSession, approve, stop, get, canUse, listForUser };
