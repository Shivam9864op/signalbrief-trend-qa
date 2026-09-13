import fs from 'node:fs/promises';
import { performance } from 'node:perf_hooks';
import { auditTrends, parseCsv, summary } from './core.mjs';

const NOW = new Date('2026-09-13T12:00:00.000Z');

async function loadInputs(file) {
  const text = await fs.readFile(file, 'utf8');
  if (file.toLowerCase().endsWith('.csv')) return parseCsv(text);
  const parsed = JSON.parse(text);
  return Array.isArray(parsed) ? parsed : [parsed];
}

function printAudit(results) {
  const counts = summary(results);
  console.log('SIGNALBRIEF TREND-TO-POST EVIDENCE DESK');
  console.log(`items=${counts.total} ready=${counts.ready_for_brief || 0} review=${counts.needs_review || 0} evidence=${counts.needs_evidence || 0} rejected=${counts.rejected || 0} duplicate=${counts.duplicate || 0}`);
  for (const result of results) {
    console.log(`${String(result.trendId).padEnd(13)} ${result.status.padEnd(16)} score=${String(result.score).padStart(3)} flags=${result.flags.length} trace=${result.traceId}`);
    for (const reason of result.reasons.slice(0, 2)) console.log(`  - ${reason}`);
  }
  console.log('boundary=synthetic_data_only local_run=true no_platform_login=true');
}

async function main() {
  const [, , command = 'audit', file = 'fixtures/trends.json', flag] = process.argv;
  if (command === 'benchmark') {
    const records = Array.from({ length: 10_000 }, (_, index) => ({
      id: `bench-${String(index).padStart(5, '0')}`,
      topic: `topic ${index % 500}`,
      capturedAt: '2026-09-13T10:00:00Z',
      region: index % 2 ? 'Bhagalpur' : 'Patna',
      channels: [index % 2 ? 'instagram' : 'linkedin'],
      signalType: 'keyword',
      signalValue: 50 + (index % 50),
      keywords: ['synthetic', 'benchmark'],
      evidenceUrl: `https://example.test/trends/${index}`,
      draftClaim: 'People are comparing practical workflow ideas',
      rightsChecked: true
    }));
    const start = performance.now();
    const results = auditTrends(records, { now: NOW });
    const elapsedMs = Math.round((performance.now() - start) * 100) / 100;
    console.log(JSON.stringify({ records: results.length, elapsedMs, counts: summary(results), syntheticData: true }, null, 2));
    return;
  }
  const inputs = await loadInputs(file);
  const results = auditTrends(inputs, { now: NOW });
  if (flag === '--json') console.log(JSON.stringify({ results, summary: summary(results) }, null, 2));
  else if (command === 'brief') {
    for (const result of results.filter((item) => item.brief)) console.log(JSON.stringify(result, null, 2));
    if (!results.some((item) => item.brief)) printAudit(results);
  } else printAudit(results);
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
