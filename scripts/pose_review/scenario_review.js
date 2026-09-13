'use strict';
const data = JSON.parse(document.getElementById('evidence').textContent);
const byId = id => document.getElementById(id);
const comparison = data.comparison;
const slider = byId('timeline');
const [start, end] = comparison.coverage.overlap;
slider.min = start; slider.max = end; slider.value = start;
const indexes = Object.fromEntries(['before', 'after'].map(side => [side, new Map(data[side].rows.map(row => [row.tick, row]))]));
let tick = start, timer = null;
const number = value => value === null || value === undefined ? 'unavailable' : Number(value).toFixed(4);
byId('issues').textContent = comparison.issues.length ? comparison.issues.join('\n') : 'Stimulus and coverage match. Review the observed differences below.';
byId('issues').className = comparison.issues.length ? 'caution' : 'matched';
byId('identity').textContent = JSON.stringify({coverage: comparison.coverage, first_divergence_tick: comparison.first_divergence_tick, first_divergence_fields: comparison.first_divergence_fields, state_tolerance: comparison.state_tolerance, maximum_position_difference_m: comparison.maximum_position_difference_m, source_changes: comparison.source_changes, unpaired_source_hashes: comparison.unpaired_source_hashes, tuning_changes: comparison.tuning_changes, excluded_fields: comparison.excluded_fields, stop_reasons: {before: data.before.stop_reason, after: data.after.stop_reason}}, null, 2);
byId('notes').textContent = JSON.stringify({before: data.before.notes, after: data.after.notes}, null, 2);
for (const side of ['before', 'after']) {
  byId(`${side}-origin`).textContent = data[side].state_origin.replaceAll('_', ' ');
  byId(`${side}-manifest`).href = data[side].manifest;
}
for (const key of comparison.metrics) {
  const option = document.createElement('option'); option.value = key; option.textContent = key; byId('metric').append(option);
}
const events = new Map();
for (const side of ['before', 'after']) for (const row of data[side].rows) {
  if (row.tick < start || row.tick > end) continue;
  for (const event of row.events) {
    const key = `${row.tick}:${event}`;
    if (!events.has(key)) events.set(key, {tick: row.tick, name: event, sides: []});
    events.get(key).sides.push(side);
  }
}
for (const event of [...events.values()].sort((a, b) => a.tick - b.tick)) {
  const button = document.createElement('button');
  button.textContent = `${event.name} · ${event.tick} · ${event.sides.join('/')}`;
  button.addEventListener('click', () => seek(event.tick)); byId('events').append(button);
}
function imageAt(side) {
  const frames = data[side].captures;
  const img = byId(`${side}-image`), caption = byId(`${side}-frame`);
  if (!frames.length) { img.hidden = true; caption.textContent = 'Telemetry only — no captured frame.'; return; }
  const frame = frames.reduce((best, item) => Math.abs((item.captured_tick ?? item.tick) - tick) < Math.abs((best.captured_tick ?? best.tick) - tick) ? item : best);
  img.hidden = frame.missing;
  if (!frame.missing && img.getAttribute('src') !== frame.url) img.src = frame.url;
  const actual = frame.captured_tick ?? frame.tick;
  caption.textContent = `${frame.missing ? 'Missing image. ' : ''}Captured tick ${actual} · ${number(frame.captured_frame_time ?? frame.time)} s · selected tick ${tick} · offset ${actual - tick} ticks`;
  img.onerror = () => { img.hidden = true; caption.textContent = 'Image unavailable. ' + caption.textContent; };
}
function chart() {
  const key = byId('metric').value, canvas = byId('chart'), ctx = canvas.getContext('2d');
  const width = canvas.width, height = canvas.height, padding = 16;
  const all = ['before', 'after'].flatMap(side => data[side].rows.filter(row => row.tick >= start && row.tick <= end).map(row => row.metrics[key])).filter(Number.isFinite);
  ctx.clearRect(0, 0, width, height);
  if (!all.length) { byId('chart-range').textContent = 'No samples for this metric.'; return; }
  let min = Infinity, max = -Infinity;
  for (const value of all) { min = Math.min(min, value); max = Math.max(max, value); }
  const x = t => padding + (t - start) / Math.max(1, end - start) * (width - padding * 2);
  const y = v => height - padding - (v - min) / (max - min || 1) * (height - padding * 2);
  for (const side of ['before', 'after']) {
    ctx.beginPath(); ctx.strokeStyle = side === 'before' ? '#50d9d0' : '#f6b869'; ctx.lineWidth = 2; let drawing = false;
    for (const row of data[side].rows) {
      if (row.tick < start || row.tick > end) continue;
      const value = row.metrics[key];
      if (!Number.isFinite(value)) { drawing = false; continue; }
      if (!drawing) ctx.moveTo(x(row.tick), y(value)); else ctx.lineTo(x(row.tick), y(value));
      drawing = true;
    }
    ctx.stroke();
  }
  ctx.strokeStyle = '#fff'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(x(tick), 0); ctx.lineTo(x(tick), height); ctx.stroke();
  byId('chart-range').textContent = `Range ${number(min)} to ${number(max)} · ticks ${start}–${end} · 120 Hz`;
}
function seek(next) {
  tick = Math.max(start, Math.min(end, Math.round(next))); slider.value = tick;
  byId('clock').textContent = `Tick ${tick} · ${(tick / 120).toFixed(3)} s`;
  imageAt('before'); imageAt('after');
  const key = byId('metric').value;
  const a = indexes.before.get(tick)?.metrics[key], b = indexes.after.get(tick)?.metrics[key];
  byId('values').textContent = `Before ${number(a)} / After ${number(b)} / Δ ${number(Number.isFinite(a) && Number.isFinite(b) ? b - a : null)}`;
  chart();
}
function pause() { clearInterval(timer); timer = null; byId('play').textContent = 'Play'; }
byId('play').addEventListener('click', () => {
  if (timer) { pause(); return; }
  if (tick >= end) seek(start);
  byId('play').textContent = 'Pause';
  timer = setInterval(() => { seek(tick + 4); if (tick >= end) pause(); }, 1000 / 30);
});
slider.addEventListener('input', () => { pause(); seek(Number(slider.value)); });
byId('previous').addEventListener('click', () => { pause(); seek(tick - 1); });
byId('next').addEventListener('click', () => { pause(); seek(tick + 1); });
byId('divergence').disabled = comparison.first_divergence_tick === null;
byId('divergence').textContent = comparison.first_divergence_tick === null ? 'No shared-state divergence' : `First divergence · ${comparison.first_divergence_tick}`;
byId('divergence').addEventListener('click', () => { pause(); seek(comparison.first_divergence_tick); });
byId('metric').addEventListener('change', () => seek(tick));
seek(start);
