'use strict';

const { Router } = require('express');
const Joi = require('joi');
const asyncHandler = require('../../utils/asyncHandler');
const validate = require('../../middleware/validate');
const { requireAuth, requireInternal } = require('../../middleware/auth');
const service = require('./remoteControl.service');

const router = Router();
router.use(requireAuth, requireInternal);

router.get('/sessions', asyncHandler(async (req, res) => {
  res.json({ items: service.listForUser(req.user.id, req.user.tenantId) });
}));

router.post('/register', validate({ body: Joi.object({
  computerId: Joi.string().trim().min(4).max(64).required(),
  computerName: Joi.string().trim().max(120).allow('', null),
}) }), asyncHandler(async (req, res) => {
  res.status(201).json(service.registerComputer({
    ...req.body, hostUserId: req.user.id, tenantId: req.user.tenantId,
  }));
}));

router.post('/request', validate({ body: Joi.object({
  computerId: Joi.string().trim().min(4).max(64).required(),
}) }), asyncHandler(async (req, res) => {
  const session = service.requestSession({
    ...req.body, controllerUserId: req.user.id, tenantId: req.user.tenantId,
  });
  if (!session) return res.status(404).json({ error: 'Computer is offline or unavailable' });
  req.app.get('io')?.to(`user:${session.hostUserId}`).emit('remote.request', session);
  res.status(201).json(session);
}));

router.post('/:id/approve', asyncHandler(async (req, res) => {
  const session = service.approve(req.params.id, req.user.id);
  if (!session) return res.status(403).json({ error: 'Remote request is invalid or expired' });
  req.app.get('io')?.to(`user:${session.controllerUserId}`).emit('remote.approved', session);
  res.json(session);
}));

router.post('/:id/stop', asyncHandler(async (req, res) => {
  const session = service.stop(req.params.id, req.user.id);
  if (!session) return res.status(404).json({ error: 'Remote session not found' });
  req.app.get('io')?.to(`user:${session.hostUserId}`).to(`user:${session.controllerUserId}`).emit('remote.stopped', session);
  res.json(session);
}));

module.exports = router;
