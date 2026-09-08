'use strict';

const ExcelJS = require('exceljs');
const prisma = require('../database/prisma');
const tenant = require('./tenant');

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

const OUTCOME_LABELS = {
  REACHABLE: 'Connected',
  NO_ANSWER: 'Not connected',
  NOT_RESPONDED: 'Call not responded',
  BUSY: 'Busy',
  SWITCHED_OFF: 'Switched off',
  FOLLOWUP_REQUIRED: 'Follow-up required',
  WRONG_NUMBER: 'Wrong number',
  NOT_INTERESTED: 'Not interested',
  dialer_opened: 'Dialer opened',
};

function istDayRange(now = new Date()) {
  const ist = new Date(now.getTime() + IST_OFFSET_MS);
  const startIstUtcMs = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()) - IST_OFFSET_MS;
  return {
    from: new Date(startIstUtcMs),
    to: now,
    dateLabel: [
      ist.getUTCFullYear(),
      String(ist.getUTCMonth() + 1).padStart(2, '0'),
      String(ist.getUTCDate()).padStart(2, '0'),
    ].join('-'),
  };
}

function istRangeForDate(dateLabel, now = new Date()) {
  if (!dateLabel) return istDayRange(now);
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateLabel));
  if (!match) return istDayRange(now);

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const startUtcMs = Date.UTC(year, month - 1, day) - IST_OFFSET_MS;
  const endUtcMs = startUtcMs + 24 * 60 * 60 * 1000 - 1;
  return {
    from: new Date(startUtcMs),
    to: new Date(Math.min(endUtcMs, now.getTime())),
    dateLabel: `${match[1]}-${match[2]}-${match[3]}`,
  };
}

function formatIst(value) {
  if (!value) return '';
  return new Intl.DateTimeFormat('en-IN', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(new Date(value));
}

function formatDuration(seconds) {
  if (!seconds && seconds !== 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return h ? `${h}h ${m}m ${s}s` : `${m}m ${s}s`;
}

function connectedLabel(call) {
  // Recording present ⇒ call was connected; otherwise treat non-reachable outcomes as not connected.
  if (call.recordingUrl) return 'Connected';
  if (call.status === 'REACHABLE') return 'Connected';
  if (
    ['NO_ANSWER', 'NOT_RESPONDED', 'BUSY', 'SWITCHED_OFF', 'WRONG_NUMBER'].includes(
      call.status
    )
  ) {
    return 'Not connected';
  }
  if (!call.status || call.status === 'dialer_opened') return '';
  // Follow-up / not interested etc. without recording still count as connected conversation.
  if (['FOLLOWUP_REQUIRED', 'NOT_INTERESTED'].includes(call.status)) {
    return 'Connected';
  }
  return 'Not connected';
}

function outcomeLabel(status) {
  if (!status) return '';
  return OUTCOME_LABELS[status] || status;
}

async function fetchCalls({ from, to, tenantId = null }) {
  return prisma.telecallerCall.findMany({
    where: {
      createdAt: { gte: from, lte: to },
      ...(tenantId ? { agent: { tenantId } } : {}),
    },
    orderBy: { createdAt: 'asc' },
    include: {
      agent: { select: { id: true, name: true, userId: true, email: true, phone: true, tenantId: true } },
      lead: {
        select: {
          id: true,
          name: true,
          phone: true,
          company: true,
          status: true,
          email: true,
          source: true,
          tenantId: true,
        },
      },
    },
  });
}

async function buildWorkbook({ calls, title, from, to }) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'MyTaskKing';
  workbook.created = new Date();

  const summary = workbook.addWorksheet('Summary');
  const totalDuration = calls.reduce((sum, c) => sum + (c.durationSec || 0), 0);
  const uniqueAgents = new Set(calls.map((c) => c.agentId)).size;
  const recorded = calls.filter((c) => c.recordingUrl).length;
  const connected = calls.filter((c) => connectedLabel(c) === 'Connected').length;
  const notConnected = calls.filter((c) => connectedLabel(c) === 'Not connected').length;

  summary.addRows([
    ['Report', title],
    ['From', formatIst(from)],
    ['To', formatIst(to)],
    ['Total calls', calls.length],
    ['Telecallers', uniqueAgents],
    ['Connected calls', connected],
    ['Not connected calls', notConnected],
    ['Total duration', formatDuration(totalDuration)],
    ['Calls with recording', recorded],
  ]);
  summary.columns = [{ width: 24 }, { width: 48 }];
  summary.getColumn(1).font = { bold: true };

  const sheet = workbook.addWorksheet('Telecaller Calls');
  sheet.columns = [
    { header: 'Call Time (IST)', key: 'createdAt', width: 24 },
    { header: 'Started At (IST)', key: 'startedAt', width: 24 },
    { header: 'Ended At (IST)', key: 'endedAt', width: 24 },
    { header: 'Agent Name', key: 'agentName', width: 24 },
    { header: 'Agent User ID', key: 'agentUserId', width: 18 },
    { header: 'Agent Email', key: 'agentEmail', width: 28 },
    { header: 'Agent Phone', key: 'agentPhone', width: 18 },
    { header: 'Lead Name', key: 'leadName', width: 24 },
    { header: 'Lead Company', key: 'leadCompany', width: 24 },
    { header: 'Lead Phone', key: 'leadPhone', width: 18 },
    { header: 'Lead Email', key: 'leadEmail', width: 28 },
    { header: 'Lead Source', key: 'leadSource', width: 18 },
    { header: 'Lead Status', key: 'leadStatus', width: 16 },
    { header: 'Connected', key: 'connected', width: 14 },
    { header: 'Call Outcome', key: 'callOutcome', width: 22 },
    { header: 'Duration', key: 'duration', width: 14 },
    { header: 'Duration (sec)', key: 'durationSec', width: 14 },
    { header: 'Has Recording', key: 'hasRecording', width: 14 },
    { header: 'Notes', key: 'notes', width: 36 },
    { header: 'Direction', key: 'direction', width: 12 },
    { header: 'From Number', key: 'fromNumber', width: 18 },
    { header: 'To Number', key: 'toNumber', width: 18 },
    { header: 'Recording URL', key: 'recordingUrl', width: 48 },
    { header: 'Call ID', key: 'callId', width: 28 },
    { header: 'External Call ID', key: 'externalCallId', width: 28 },
  ];
  sheet.getRow(1).font = { bold: true };
  sheet.views = [{ state: 'frozen', ySplit: 1 }];

  for (const call of calls) {
    const durationSec =
      call.durationSec != null
        ? call.durationSec
        : call.startedAt && call.endedAt
          ? Math.max(
              0,
              Math.round(
                (new Date(call.endedAt).getTime() - new Date(call.startedAt).getTime()) / 1000
              )
            )
          : null;
    sheet.addRow({
      createdAt: formatIst(call.createdAt),
      startedAt: formatIst(call.startedAt || call.createdAt),
      endedAt: formatIst(call.endedAt),
      agentName: call.agent?.name || '',
      agentUserId: call.agent?.userId || '',
      agentEmail: call.agent?.email || '',
      agentPhone: call.agent?.phone || '',
      leadName: call.lead?.name || '',
      leadCompany: call.lead?.company || '',
      leadPhone: call.lead?.phone || call.toNumber || '',
      leadEmail: call.lead?.email || '',
      leadSource: call.lead?.source || '',
      leadStatus: call.lead?.status || '',
      connected: connectedLabel(call),
      callOutcome: outcomeLabel(call.status),
      duration: formatDuration(durationSec),
      durationSec: durationSec == null ? '' : durationSec,
      hasRecording: call.recordingUrl ? 'Yes' : 'No',
      notes: call.notes || '',
      direction: call.direction || 'OUTBOUND',
      fromNumber: call.fromNumber || '',
      toNumber: call.toNumber || '',
      recordingUrl: call.recordingUrl || '',
      callId: call.id || '',
      externalCallId: call.externalCallId || '',
    });
  }

  return Buffer.from(await workbook.xlsx.writeBuffer());
}

async function buildDailyReportForUser({ user, date, scope = 'org' }) {
  const { from, to, dateLabel } = istRangeForDate(date);
  const platformAll = tenant.isPlatformSuperAdmin(user) && scope === 'all';
  const tenantId = platformAll ? null : tenant.userTenantId(user);
  const calls = await fetchCalls({ from, to, tenantId });
  const title = platformAll
    ? `All organisations telecaller call report - ${dateLabel}`
    : `Telecaller call report - ${dateLabel}`;
  const buffer = await buildWorkbook({ calls, title, from, to });
  const filename = platformAll
    ? `telecaller-calls-all-organisations-${dateLabel}.xlsx`
    : `telecaller-calls-${tenantId || 'workspace'}-${dateLabel}.xlsx`;
  return { buffer, filename, calls: calls.length, from, to, dateLabel };
}

module.exports = {
  istDayRange,
  istRangeForDate,
  buildDailyReportForUser,
};
