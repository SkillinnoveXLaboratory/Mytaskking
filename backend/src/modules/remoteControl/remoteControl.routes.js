'use strict';

const { Router } = require('express');
const Joi = require('joi');
const asyncHandler = require('../../utils/asyncHandler');
const validate = require('../../middleware/validate');
const { requireAuth, requireInternal } = require('../../middleware/auth');
const service = require('./remoteControl.service');

const router = Router();
router.use(requireAuth, requireInternal);

const tenantIdFor = (req) => req.user.tenantId || 'default';

router.get('/sessions', asyncHandler(async (req, res) => {
  res.json({ items: await service.listForUser(req.user.id, tenantIdFor(req)) });
}));

router.get('/computers', asyncHandler(async (req, res) => {
  const platform = ['WINDOWS', 'LINUX'].includes(req.query.platform)
    ? req.query.platform
    : undefined;
  res.json({ items: await service.listComputers(req.user.id, tenantIdFor(req), platform) });
}));

router.post('/register', validate({ body: Joi.object({
  computerId: Joi.string().trim().min(4).max(64).required(),
  computerName: Joi.string().trim().max(120).allow('', null),
  platform: Joi.string().valid('WINDOWS', 'LINUX').default('WINDOWS'),
}) }), asyncHandler(async (req, res) => {
  res.status(201).json(await service.registerComputer({
    ...req.body, hostUserId: req.user.id, tenantId: tenantIdFor(req),
  }));
}));

router.patch('/computers/:id', validate({
  params: Joi.object({ id: Joi.string().trim().required() }),
  body: Joi.object({ computerName: Joi.string().trim().min(1).max(120).required() }),
}), asyncHandler(async (req, res) => {
  const computer = await service.renameComputer({
    id: req.params.id,
    computerName: req.body.computerName,
    hostUserId: req.user.id,
    tenantId: tenantIdFor(req),
  });
  if (!computer) return res.status(404).json({ error: 'Computer not found' });
  res.json(computer);
}));

router.post('/request', validate({ body: Joi.object({
  computerId: Joi.string().trim().min(4).max(64).required(),
}) }), asyncHandler(async (req, res) => {
  const session = await service.requestSession({
    ...req.body, controllerUserId: req.user.id, tenantId: tenantIdFor(req),
  });
  if (!session) return res.status(404).json({ error: 'Computer is offline or unavailable' });
  req.app.get('io')?.to(`user:${session.hostUserId}`).emit('remote.request', session);
  res.status(201).json(session);
}));

router.post('/:id/approve', asyncHandler(async (req, res) => {
  const session = await service.approve(req.params.id, req.user.id);
  if (!session) return res.status(403).json({ error: 'Remote request is invalid or expired' });
  req.app.get('io')?.to(`user:${session.controllerUserId}`).emit('remote.approved', session);
  res.json(session);
}));

router.post('/:id/stop', asyncHandler(async (req, res) => {
  const session = await service.stop(req.params.id, req.user.id);
  if (!session) return res.status(404).json({ error: 'Remote session not found' });
  req.app.get('io')?.to(`user:${session.hostUserId}`).to(`user:${session.controllerUserId}`).emit('remote.stopped', session);
  res.json(session);
}));

module.exports = router;
