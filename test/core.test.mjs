import test from 'node:test';
import assert from 'node:assert/strict';
import { auditTrends, decideTrend, duplicateKey, parseCsv } from '../src/core.mjs';

const now = new Date('2026-09-13T12:00:00Z');
const valid = {
  id: 'lead-like-001', topic: 'budget-friendly cafe reels', capturedAt: '2026-09-13T10:00:00Z', region: 'Bhagalpur',
  channels: ['instagram', 'linkedin'], signalType: 'keyword', signalValue: 82, keywords: ['cafe', 'reels'],
  evidenceUrl: 'https://example.test/trends/1', draftClaim: 'People are asking for menu details', rightsChecked: true
};

test('valid trend gets deterministic ready brief', () => {
  const first = decideTrend(valid, { now });
  const second = decideTrend(valid, { now });
  assert.equal(first.status, 'ready_for_brief');
  assert.equal(first.score, 96);
  assert.deepEqual(first, second);
  assert.equal(first.brief.channels[0], 'instagram');
});

test('missing evidence is readable and cannot produce a brief', () => {
  const result = decideTrend({ ...valid, id: 'missing-evidence', evidenceUrl: '' }, { now });
  assert.equal(result.status, 'needs_evidence');
  assert.match(result.flags.join(','), /evidence:missing/);
  assert.equal(result.brief, null);
});

test('missing topic is rejected', () => {
  const result = decideTrend({ ...valid, id: 'missing-topic', topic: '' }, { now });
  assert.equal(result.status, 'rejected');
  assert.match(result.flags.join(','), /missing topic/);
});

test('stale and unsupported claims reach review', () => {
  const result = decideTrend({ ...valid, id: 'stale', capturedAt: '2026-09-08T10:00:00Z', draftClaim: 'Guaranteed viral growth' }, { now });
  assert.equal(result.status, 'needs_review');
  assert.ok(result.flags.includes('freshness:stale'));
  assert.ok(result.flags.some((flag) => flag.startsWith('claim:')));
});

test('duplicate snapshots are idempotent in a batch', () => {
  const results = auditTrends([valid, { ...valid, id: 'same-snapshot-different-id' }], { now });
  assert.equal(results[0].status, 'ready_for_brief');
  assert.equal(results[1].status, 'duplicate');
  assert.equal(duplicateKey(results[0].normalized), duplicateKey(results[1].normalized));
});

test('CSV and JSON-shaped data normalize to the same decision', () => {
  const csv = `id,topic,capturedAt,region,channels,signalType,signalValue,keywords,evidenceUrl,draftClaim,rightsChecked\n${valid.id},${valid.topic},${valid.capturedAt},${valid.region},instagram|linkedin,keyword,82,cafe|reels,${valid.evidenceUrl},${valid.draftClaim},true`;
  const parsed = parseCsv(csv)[0];
  assert.equal(decideTrend(parsed, { now }).score, decideTrend(valid, { now }).score);
});
