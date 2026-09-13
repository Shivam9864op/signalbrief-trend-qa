import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { auditTrends, decideTrend, duplicateKey, normalizeTrend } from './core.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(root, '..');
const fixturePath = process.argv[2] || path.join(projectRoot, 'fixtures', 'trends.json');
const initial = JSON.parse(await fs.readFile(fixturePath, 'utf8'));
const store = new Map();
for (const result of auditTrends(initial)) store.set(result.trendId, result);

function send(res, status, payload, contentType = 'application/json; charset=utf-8') {
  res.writeHead(status, { 'content-type': contentType, 'cache-control': 'no-store' });
  res.end(contentType.startsWith('application/json') ? JSON.stringify(payload, null, 2) : payload);
}

async function body(req) {
  let text = '';
  for await (const chunk of req) text += chunk;
  return text ? JSON.parse(text) : {};
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (req.method === 'GET' && url.pathname === '/health') return send(res, 200, { ok: true, service: 'signalbrief', items: store.size });
    if (req.method === 'GET' && url.pathname === '/api/trends') return send(res, 200, { results: [...store.values()].sort((a, b) => String(a.trendId).localeCompare(String(b.trendId))) });
    if (req.method === 'GET' && url.pathname.startsWith('/api/brief/')) {
      const id = decodeURIComponent(url.pathname.slice('/api/brief/'.length));
      const result = store.get(id);
      return result ? send(res, 200, result) : send(res, 404, { error: 'trend not found' });
    }
    if (req.method === 'POST' && url.pathname === '/webhook/trends') {
      const input = normalizeTrend(await body(req));
      const existing = [...store.values()].find((result) => result.normalized && duplicateKey(result.normalized) === duplicateKey(input));
      if (existing) return send(res, 200, { ...existing, replay: true });
      const result = decideTrend(input);
      store.set(result.trendId || `invalid-${store.size + 1}`, result);
      return send(res, 201, result);
    }
    if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
      return send(res, 200, await fs.readFile(path.join(projectRoot, 'dashboard', 'index.html'), 'utf8'), 'text/html; charset=utf-8');
    }
    if (req.method === 'GET' && url.pathname === '/dashboard.css') return send(res, 200, await fs.readFile(path.join(projectRoot, 'dashboard', 'dashboard.css'), 'utf8'), 'text/css; charset=utf-8');
    if (req.method === 'GET' && url.pathname === '/dashboard.js') return send(res, 200, await fs.readFile(path.join(projectRoot, 'dashboard', 'dashboard.js'), 'utf8'), 'text/javascript; charset=utf-8');
    send(res, 404, { error: 'not found' });
  } catch (error) {
    send(res, 400, { error: error.message });
  }
});

const port = Number(process.env.PORT || 4173);
server.listen(port, () => console.log(`SignalBrief dashboard: http://localhost:${port}`));
