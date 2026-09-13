const queue = document.querySelector('#queue');
const detail = document.querySelector('#detail');
const stats = document.querySelector('#stats');
const updated = document.querySelector('#updated');
let results = [];

const label = (status) => status.replaceAll('_', ' ');
function renderStats() {
  const counts = results.reduce((acc, item) => { acc[item.status] = (acc[item.status] || 0) + 1; return acc; }, {});
  const cards = [
    ['total', 'Items', 'neutral'],
    ['ready_for_brief', 'Ready', 'ready'],
    ['needs_review', 'Human review', 'review'],
    ['needs_evidence', 'Needs evidence', 'review'],
    ['rejected', 'Rejected', 'blocked']
  ];
  stats.innerHTML = cards.map(([key, text, tone]) => `<div class="stat ${tone}"><strong>${key === 'total' ? results.length : counts[key] || 0}</strong><span>${text}</span></div>`).join('');
}
function renderQueue() {
  queue.innerHTML = results.map((item, index) => `<button class="item" data-index="${index}"><div class="item-head"><h3>${item.normalized?.topic || item.trendId || 'Invalid record'}</h3><span class="pill ${item.status}">${label(item.status)}</span></div><div class="item-meta"><span>${item.normalized?.region || '—'}</span><span>${item.normalized?.channels?.join(' · ') || '—'}</span><span class="score">score ${item.score}</span></div></button>`).join('');
  queue.querySelectorAll('.item').forEach((button) => button.addEventListener('click', () => renderDetail(results[Number(button.dataset.index)])));
}
function renderDetail(item) {
  queue.querySelectorAll('.item').forEach((button) => button.classList.toggle('active', Number(button.dataset.index) === results.indexOf(item)));
  const breakdown = item.scoreBreakdown || {};
  const brief = item.brief ? `<div class="brief"><p><strong>Angle:</strong> ${item.brief.angle}</p><p><strong>CTA:</strong> ${item.brief.cta}</p><strong>Hooks</strong><ul>${item.brief.hooks.map((hook) => `<li>${hook}</li>`).join('')}</ul></div>` : '<p class="trace">No brief generated until the flags are resolved.</p>';
  detail.classList.remove('empty');
  const reviewKey = `signalbrief-review-${item.trendId}`;
  const saved = JSON.parse(localStorage.getItem(reviewKey) || '{}');
  detail.innerHTML = `<h2>${item.normalized?.topic || item.trendId || 'Invalid record'}</h2><span class="pill ${item.status}">${label(item.status)}</span><p class="trace">trace ${item.traceId}</p><h3>Score ${item.score}/100</h3><div class="scorebar"><i style="width:${item.score}%"></i></div><p class="trace">freshness ${breakdown.freshness ?? 0} · evidence ${breakdown.evidence ?? 0} · audience ${breakdown.audience ?? 0} · novelty ${breakdown.novelty ?? 0} · safety ${breakdown.safety ?? 0}</p><h3>Flags</h3><div class="flags">${item.flags.length ? item.flags.map((flag) => `<span class="flag">${flag}</span>`).join('') : '<span class="trace">No flags</span>'}</div><h3>Brief</h3>${brief}<h3>Reviewer decision</h3><label class="review-field">Decision<select id="review-decision"><option value="pending">Pending</option><option value="approved">Approved</option><option value="changes_requested">Changes requested</option><option value="rejected">Rejected</option></select></label><label class="review-field">Notes<textarea id="review-notes" rows="3" placeholder="What should be fixed or checked?"></textarea></label><p class="trace" id="saved-note">Saved only in this browser</p>`;
  const decision = detail.querySelector('#review-decision'); const notes = detail.querySelector('#review-notes');
  decision.value = saved.decision || 'pending'; notes.value = saved.notes || '';
  const persist = () => { localStorage.setItem(reviewKey, JSON.stringify({ decision: decision.value, notes: notes.value })); detail.querySelector('#saved-note').textContent = 'Reviewer note saved locally'; };
  decision.addEventListener('change', persist); notes.addEventListener('input', persist);
}
async function load() {
  const response = await fetch('/api/trends');
  const payload = await response.json();
  results = payload.results || [];
  renderStats(); renderQueue(); updated.textContent = `${results.length} records loaded locally`;
}
load().catch((error) => { queue.textContent = `Could not load local queue: ${error.message}`; });
