import crypto from 'node:crypto';

export const STALE_AFTER_HOURS = 72;
export const VALID_CHANNELS = new Set(['instagram', 'linkedin', 'youtube', 'facebook']);
export const HARD_CLAIM_PATTERNS = [
  /\bguarantee(?:d|s)?\b/i,
  /\bviral\b/i,
  /\b\d{2,3}\s*%\b/i,
  /\b(cure|treat|diagnos|regulated|medical|financial advice)\w*\b/i
];

const REQUIRED = ['id', 'topic', 'capturedAt', 'region', 'channels'];

export function canonicalTopic(topic = '') {
  return String(topic).toLowerCase().trim().replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ');
}

export function normalizeTrend(input) {
  const raw = input && typeof input === 'object' ? input : {};
  const channels = Array.isArray(raw.channels)
    ? [...new Set(raw.channels.map((channel) => String(channel).toLowerCase().trim()).filter(Boolean))].sort()
    : [];
  const keywords = Array.isArray(raw.keywords)
    ? [...new Set(raw.keywords.map((keyword) => String(keyword).toLowerCase().trim()).filter(Boolean))].sort()
    : [];
  const captured = new Date(raw.capturedAt);
  const signalValue = Number(raw.signalValue);
  return {
    id: String(raw.id ?? '').trim(),
    topic: String(raw.topic ?? '').trim(),
    canonicalTopic: canonicalTopic(raw.topic),
    capturedAt: Number.isNaN(captured.getTime()) ? '' : captured.toISOString(),
    region: String(raw.region ?? '').trim(),
    channels,
    signalType: String(raw.signalType ?? 'unknown').trim().toLowerCase(),
    signalValue: Number.isFinite(signalValue) ? Math.max(0, Math.min(100, signalValue)) : 0,
    keywords,
    evidenceUrl: String(raw.evidenceUrl ?? '').trim(),
    draftClaim: String(raw.draftClaim ?? '').trim(),
    rightsChecked: raw.rightsChecked === true
  };
}

export function validateTrend(trend) {
  const errors = [];
  for (const field of REQUIRED) {
    const value = trend[field];
    if (value === '' || value == null || (Array.isArray(value) && value.length === 0)) errors.push(`missing ${field}`);
  }
  if (trend.capturedAt && Number.isNaN(new Date(trend.capturedAt).getTime())) errors.push('invalid capturedAt');
  if (trend.channels.some((channel) => !VALID_CHANNELS.has(channel))) errors.push('unsupported channel');
  // Evidence failures are represented as needs_evidence by decideTrend so the
  // operator can repair the record instead of losing the trace entirely.
  return errors;
}

export function duplicateKey(trend) {
  return [trend.canonicalTopic, trend.region.toLowerCase(), trend.channels.join(','), trend.capturedAt].join('|');
}

export function traceIdFor(trend) {
  return crypto.createHash('sha256').update(`${trend.id}|${duplicateKey(trend)}`).digest('hex').slice(0, 16);
}

function claimFlags(trend) {
  const text = `${trend.topic} ${trend.draftClaim}`;
  return HARD_CLAIM_PATTERNS.filter((pattern) => pattern.test(text)).map((pattern) => `claim:${pattern.source}`);
}

function scoreTrend(trend, now) {
  const ageHours = Math.max(0, (now.getTime() - new Date(trend.capturedAt).getTime()) / 3_600_000);
  const freshness = ageHours <= 24 ? 20 : ageHours <= STALE_AFTER_HOURS ? 15 : 0;
  const evidence = /^https?:\/\//i.test(trend.evidenceUrl) ? 20 : 0;
  const audience = trend.region && trend.channels.length > 0 ? 20 : 0;
  const novelty = Math.round(trend.signalValue * 0.2);
  const safety = trend.rightsChecked && claimFlags(trend).length === 0 ? 20 : 0;
  return {
    total: Math.min(100, freshness + evidence + audience + novelty + safety),
    freshness,
    evidence,
    audience,
    novelty,
    safety,
    ageHours: Math.round(ageHours * 10) / 10
  };
}

export function makeBrief(trend) {
  const topic = trend.topic || 'this topic';
  const region = trend.region || 'your local audience';
  const primary = trend.channels[0] || 'social';
  const keyword = trend.keywords[0] || topic.split(/\s+/)[0] || 'this idea';
  return {
    angle: `A practical ${keyword} idea for ${region}, grounded in the captured signal.`,
    hooks: [
      `What would make ${topic} easier for people in ${region}?`,
      `A simple ${keyword} test before you publish your next post.`
    ],
    cta: 'Ask for one specific response, then review replies before publishing a follow-up.',
    channels: trend.channels.length ? trend.channels : [primary]
  };
}

export function decideTrend(input, { now = new Date(), seen = new Set() } = {}) {
  const trend = normalizeTrend(input);
  const errors = validateTrend(trend);
  const traceId = traceIdFor(trend);
  if (errors.length) {
    return { trendId: trend.id || null, status: 'rejected', score: 0, flags: errors, reasons: errors, traceId, normalized: trend };
  }
  const key = duplicateKey(trend);
  if (seen.has(key)) {
    return { trendId: trend.id, status: 'duplicate', score: 0, flags: ['duplicate:snapshot'], reasons: ['same topic, region, channels, and capture time already processed'], traceId, normalized: trend };
  }
  const score = scoreTrend(trend, now);
  const flags = [];
  const reasons = [];
  if (score.ageHours > STALE_AFTER_HOURS) {
    flags.push('freshness:stale');
    reasons.push(`captured ${score.ageHours} hours ago; refresh before use`);
  }
  let evidenceValid = false;
  try { evidenceValid = Boolean(trend.evidenceUrl) && ['http:', 'https:'].includes(new URL(trend.evidenceUrl).protocol); } catch { evidenceValid = false; }
  if (!evidenceValid) {
    flags.push(trend.evidenceUrl ? 'evidence:invalid' : 'evidence:missing');
    reasons.push('a valid evidence URL is required before a brief can be used');
  }
  if (!trend.rightsChecked) {
    flags.push('rights:unchecked');
    reasons.push('rights/ownership check is not marked complete');
  }
  for (const flag of claimFlags(trend)) {
    flags.push(flag);
    reasons.push('claim needs a human check before publication');
  }
  let status = 'needs_review';
  if (flags.some((flag) => flag.startsWith('evidence:'))) status = 'needs_evidence';
  else if (flags.length === 0 && score.total >= 75) status = 'ready_for_brief';
  else if (flags.length === 0 && score.total < 50) status = 'rejected';
  return {
    trendId: trend.id,
    status,
    score: score.total,
    scoreBreakdown: score,
    flags,
    reasons,
    brief: status === 'ready_for_brief' ? makeBrief(trend) : null,
    traceId,
    normalized: trend
  };
}

export function auditTrends(inputs, options = {}) {
  const seen = new Set();
  const results = [];
  for (const input of inputs) {
    const normalized = normalizeTrend(input);
    const result = decideTrend(normalized, { ...options, seen });
    if (result.status !== 'rejected' || result.flags.length === 0) seen.add(duplicateKey(normalized));
    results.push(result);
  }
  return results.sort((a, b) => String(a.trendId).localeCompare(String(b.trendId)));
}

export function summary(results) {
  return results.reduce((acc, result) => {
    acc.total += 1;
    acc[result.status] = (acc[result.status] || 0) + 1;
    return acc;
  }, { total: 0 });
}

export function parseCsv(text) {
  const lines = String(text).trim().split(/\r?\n/).filter(Boolean);
  if (lines.length < 2) return [];
  const headers = lines[0].split(',').map((header) => header.trim());
  return lines.slice(1).map((line) => {
    const values = line.split(',').map((value) => value.trim());
    const row = Object.fromEntries(headers.map((header, index) => [header, values[index] ?? '']));
    return {
      ...row,
      channels: row.channels ? row.channels.split('|') : [],
      keywords: row.keywords ? row.keywords.split('|') : [],
      signalValue: Number(row.signalValue),
      rightsChecked: row.rightsChecked === 'true'
    };
  });
}
