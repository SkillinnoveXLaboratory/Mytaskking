'use strict';

const { Router } = require('express');
const Joi = require('joi');
const asyncHandler = require('../../utils/asyncHandler');
const validate = require('../../middleware/validate');
const { requireAuth, requireAdmin } = require('../../middleware/auth');
const prisma = require('../../database/prisma');
const audit = require('../../services/audit');
const notifications = require('../notifications/notifications.service');
const tenant = require('../../services/tenant');
const { Forbidden } = require('../../utils/errors');

const router = Router();
router.use(requireAuth);

const Scope = Joi.string().valid('GLOBAL', 'CHANNEL', 'CLIENTS_ONLY', 'EMPLOYEES_ONLY');
const Priority = Joi.string().valid('INFO', 'IMPORTANT', 'URGENT');

const include = {
  author: { select: { id: true, name: true, avatarUrl: true, isClient: true, role: true } },
  channel: { select: { id: true, name: true, kind: true } },
};

function visibleToUserWhere(user, now) {
  return {
    publishAt: { lte: now },
    AND: [
      { OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] },
      {
        OR: [
          { scope: 'GLOBAL' },
          { scope: user.isClient ? 'CLIENTS_ONLY' : 'EMPLOYEES_ONLY' },
          {
            scope: 'CHANNEL',
            channel: { members: { some: { userId: user.id } } },
          },
        ],
      },
    ],
  };
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const now = new Date();
    const where = {
      ...visibleToUserWhere(req.user, now),
      ...(tenant.MULTI_TENANT
          ? { author: { tenantId: tenant.userTenantId(req.user) } }
          : {}),
    };
    const items = await prisma.announcement.findMany({
      where,
      orderBy: [{ priority: 'desc' }, { publishAt: 'desc' }],
      include,
      take: 50,
    });
    res.json({ items });
  })
);

// The popup intentionally considers only the newest visible announcement. If
// that item was acknowledged, older announcements do not reappear on login.
router.get(
  '/latest',
  asyncHandler(async (req, res) => {
    const now = new Date();
    const ann = await prisma.announcement.findFirst({
      where: {
        ...visibleToUserWhere(req.user, now),
        ...(tenant.MULTI_TENANT
            ? { author: { tenantId: tenant.userTenantId(req.user) } }
            : {}),
      },
      orderBy: { publishAt: 'desc' },
      include,
    });
    const acknowledged = ann?.acknowledgedBy.includes(req.user.id) ?? false;
    res.json({ item: acknowledged ? null : ann });
  })
);

router.post(
  '/',
  requireAdmin,
  validate({
    body: Joi.object({
      title: Joi.string().min(1).max(240).required(),
      body: Joi.string().min(1).max(8000).required(),
      scope: Scope.default('GLOBAL'),
      priority: Priority.default('INFO'),
      channelId: Joi.string().allow(null, ''),
      publishAt: Joi.date().iso(),
      expiresAt: Joi.date().iso().allow(null),
      pinned: Joi.boolean(),
      notify: Joi.boolean().default(true),
    }),
  }),
  asyncHandler(async (req, res) => {
    const ann = await prisma.announcement.create({
      data: {
        title: req.body.title,
        body: req.body.body,
        scope: req.body.scope,
        priority: req.body.priority,
        channelId: req.body.channelId || null,
        publishAt: req.body.publishAt ? new Date(req.body.publishAt) : new Date(),
        expiresAt: req.body.expiresAt ? new Date(req.body.expiresAt) : null,
        pinned: req.body.pinned ?? true,
        authorId: req.user.id,
      },
      include,
    });

    audit.record({
      kind: 'announcement.published',
      entity: 'announcement',
      entityId: ann.id,
      payload: { scope: ann.scope, priority: ann.priority },
      req,
    });

    if (ann.publishAt <= new Date()) {
      // Deliver only to the matching audience. Channel content must never be
      // broadcast globally because non-members could receive its payload.
      (async () => {
        const scopeWhere =
          ann.scope === 'CLIENTS_ONLY' ? { isClient: true }
          : ann.scope === 'EMPLOYEES_ONLY' ? { isClient: false }
          : ann.scope === 'CHANNEL' && ann.channelId
            ? { channelMembers: { some: { channelId: ann.channelId } } }
            : {};
        const targets = await prisma.user.findMany({
          where: tenant.scopedWhere(req, { status: 'ACTIVE', ...scopeWhere }),
          select: { id: true },
        });
        const io = req.app.get('io');
        await Promise.all(
          targets.map(async (u) => {
            io?.to(`user:${u.id}`).emit('announcement.published', { id: ann.id });
            if (req.body.notify) {
              await notifications.notify({
                userId: u.id,
                kind: 'SYSTEM',
                title: ann.title,
                body: ann.body.slice(0, 240),
                data: { announcementId: ann.id, priority: ann.priority },
                io,
              }).catch(() => {});
            }
          })
        );
      })();
    }

    res.status(201).json(ann);
  })
);

router.post(
  '/:id/ack',
  asyncHandler(async (req, res) => {
    const now = new Date();
    const ann = await prisma.announcement.findFirst({
      where: {
        id: req.params.id,
        ...visibleToUserWhere(req.user, now),
        ...(tenant.MULTI_TENANT
            ? { author: { tenantId: tenant.userTenantId(req.user) } }
            : {}),
      },
    });
    if (!ann) return res.status(204).end();
    if (!ann.acknowledgedBy.includes(req.user.id)) {
      await prisma.announcement.update({
        where: { id: req.params.id },
        data: { acknowledgedBy: { set: [...ann.acknowledgedBy, req.user.id] } },
      });
    }
    res.json({ ok: true });
  })
);

router.delete(
  '/:id',
  requireAdmin,
  asyncHandler(async (req, res) => {
    const ann = await prisma.announcement.findUnique({
      where: { id: req.params.id },
      include: { author: { select: { tenantId: true } } },
    });
    if (!ann) return res.status(204).end();
    if (
      tenant.MULTI_TENANT &&
      ann.author.tenantId !== tenant.userTenantId(req.user) &&
      !tenant.isPlatformSuperAdmin(req.user)
    ) {
      throw Forbidden('Announcement belongs to another organisation');
    }
    await prisma.announcement.delete({ where: { id: req.params.id } }).catch(() => {});
    res.status(204).end();
  })
);

module.exports = router;
