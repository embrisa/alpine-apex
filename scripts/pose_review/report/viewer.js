'use strict';
const cases = JSON.parse(document.getElementById('report-data').textContent);
const $ = id => document.getElementById(id);
const video = $('playerMovie'), canvas = $('canvas'), ctx = canvas.getContext('2d');
let current = cases[0], shownFrame = 75, pendingFrame = 75, loaded = false;
let movieLoad = 0, movieBlob = null;
let notes = {};
try { notes = JSON.parse(localStorage.getItem('alpine-cascadeur-review-20260912') || '{}'); } catch (_) {}
for (const item of cases) {
  const option = document.createElement('option'); option.value = item.id; option.textContent = item.title; $('sequence').append(option);
}
function labels() {
  const r9 = current.group === 'r9';
  $('labelA').textContent = r9 ? 'R7 pose · earlier R8 support' : 'Our baseline · September 10';
  $('labelB').textContent = r9 ? 'Same R7 pose · deeper support' : `Cascadeur ${current.group.toUpperCase()} · fitted in game`;
  const mode = $('layout').value;
  $('visual').classList.toggle('single', mode !== 'pair');
  $('labelA').hidden = mode === 'b'; $('labelB').hidden = mode === 'a' || mode === 'overlay';
  if (mode === 'overlay') $('labelA').textContent = '50% overlay · baseline + candidate';
  canvas.setAttribute('aria-label', `${current.title}; ${$('view').value}; ${mode}`);
}
function draw() {
  if (!loaded || video.readyState < 2) return;
  const panel = {oblique: 0, front: 1, side: 2}[$('view').value];
  const whole = current.chase || $('view').value === 'all';
  const width = whole ? video.videoWidth : 800, sourceHeight = video.videoHeight / 2;
  const crop = !whole && $('framing').value === 'rider';
  const y = crop ? 220 : 0, height = crop ? 640 : sourceHeight;
  const x = whole ? 0 : panel * 800, mode = $('layout').value;
  if (canvas.width !== width * (mode === 'pair' ? 2 : 1) || canvas.height !== height) {
    canvas.width = width * (mode === 'pair' ? 2 : 1); canvas.height = height;
  }
  ctx.globalAlpha = 1; ctx.clearRect(0, 0, canvas.width, height);
  if (mode !== 'b') ctx.drawImage(video, x, y, width, height, 0, 0, width, height);
  if (mode !== 'a') {
    ctx.globalAlpha = mode === 'overlay' ? .5 : 1;
    ctx.drawImage(video, x, sourceHeight + y, width, height, mode === 'pair' ? width : 0, 0, width, height);
  }
  ctx.globalAlpha = 1;
}
function updateFrame(frame) {
  shownFrame = Math.max(0, Math.min(120, frame));
  $('scrub').value = shownFrame;
  $('time').textContent = `Frame ${shownFrame} / 120 · ${(shownFrame / 30).toFixed(2)}s`;
  const phase = current.phases[shownFrame];
  $('phase').textContent = `Recorded input: steering ${Math.round(phase.steer * 100)}% · tuck ${Math.round(phase.tuck * 100)}% · 30 captured frames/s`;
}
function seek(frame) {
  pendingFrame = Math.max(0, Math.min(120, frame));
  video.pause(); $('play').textContent = 'Play'; updateFrame(pendingFrame);
  if (loaded) video.currentTime = (pendingFrame + .15) / 30;
}
async function loadCase(id, frame, view) {
  const generation = ++movieLoad;
  video.pause(); loaded = false; current = cases.find(c => c.id === id); pendingFrame = frame ?? current.frame;
  $('sequence').value = id; $('play').textContent = 'Play';
  for (const name of ['play', 'restart', 'prev', 'next']) $(name).disabled = true;
  $('watch').textContent = current.note;
  $('scope').textContent = current.group === 'r9' ? 'R9 physical-support trial • same inputs/ticks, different physics • overlay disabled • September 11 evidence' : `${current.group.toUpperCase()} animation comparison • physics, inputs and camera transforms verified equal • September 10 evidence`;
  $('view').disabled = current.chase;
  $('framing').disabled = current.chase;
  if (view) $('view').value = view;
  $('layout').querySelector('option[value="overlay"]').disabled = current.group === 'r9';
  $('layout').querySelector('option[value="a"]').textContent = current.group === 'r9' ? 'Earlier R8 support only' : 'Our baseline only';
  if (current.group === 'r9' && $('layout').value === 'overlay') $('layout').value = 'pair';
  labels(); updateFrame(pendingFrame);
  ctx.fillStyle = '#a1a4aa'; ctx.fillRect(0, 0, canvas.width, canvas.height);
  $('status').textContent = 'Loading comparison…'; $('keyframe').textContent = `Key moment · ${current.frame}`;
  $('preference').value = notes[id]?.preference || ''; $('notes').value = notes[id]?.note || ''; $('saved').textContent = '';
  $('download').href = current.movie;
  try {
    // The small localhost review server has no byte-range support. A complete
    // in-memory movie restores exact seeking; file:// playback uses native files.
    let url = current.movie;
    if (location.protocol === 'http:' || location.protocol === 'https:') {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const blob = await response.blob();
      if (generation !== movieLoad) return;
      url = URL.createObjectURL(blob);
    }
    const oldBlob = movieBlob;
    movieBlob = url.startsWith('blob:') ? url : null;
    video.src = url; video.load();
    if (oldBlob) URL.revokeObjectURL(oldBlob);
  } catch (error) { if (generation === movieLoad) $('status').textContent = `Movie could not load: ${error.message}`; }
}
video.addEventListener('loadeddata', () => {
  loaded = true; video.playbackRate = Number($('speed').value);
  for (const name of ['play', 'restart', 'prev', 'next']) $(name).disabled = false;
  $('status').textContent = 'Ready · both versions share one synchronized movie'; seek(pendingFrame);
});
video.addEventListener('seeked', draw);
video.addEventListener('error', () => {$('status').textContent = 'The movie could not load. Open the report in Chrome or Edge, or use the still comparisons below.';});
video.addEventListener('ended', () => {$('play').textContent = 'Play'; updateFrame(120); draw();});
function onFrame(_, metadata) {
  if (!video.seeking) { updateFrame(Math.floor(metadata.mediaTime * 30 + .001)); draw(); }
  video.requestVideoFrameCallback(onFrame);
}
if (video.requestVideoFrameCallback) video.requestVideoFrameCallback(onFrame);
else video.addEventListener('timeupdate', () => {updateFrame(Math.floor(video.currentTime * 30)); draw();});
$('play').addEventListener('click', async () => {
  if (!video.paused) { video.pause(); $('play').textContent = 'Play'; return; }
  if (shownFrame >= 120) video.currentTime = 0;
  try { await video.play(); $('play').textContent = 'Pause'; } catch (error) { $('status').textContent = `Playback could not start: ${error.message}`; }
});
$('restart').addEventListener('click', () => seek(0));
$('prev').addEventListener('click', () => seek(shownFrame - 1));
$('next').addEventListener('click', () => seek(shownFrame + 1));
$('scrub').addEventListener('input', e => seek(Number(e.target.value)));
$('speed').addEventListener('change', e => {video.playbackRate = Number(e.target.value);});
$('sequence').addEventListener('change', e => loadCase(e.target.value));
$('view').addEventListener('change', () => {labels(); draw();});
$('framing').addEventListener('change', draw);
$('layout').addEventListener('change', () => {labels(); draw();});
$('keyframe').addEventListener('click', () => seek(current.frame));
document.querySelectorAll('[data-frame]').forEach(button => button.addEventListener('click', () => seek(Number(button.dataset.frame))));
document.querySelectorAll('[data-case]').forEach(button => button.addEventListener('click', () => {loadCase(button.dataset.case, Number(button.dataset.at), button.dataset.view); $('compare').scrollIntoView({behavior:'smooth'});}));
$('fullscreen').addEventListener('click', async () => {try {if (document.fullscreenElement) await document.exitFullscreen(); else await $('player').requestFullscreen();} catch (_) {$('status').textContent = 'Fullscreen is unavailable here; open index.html in Chrome or Edge to enlarge.';}});
function saveNote() {
  notes[current.id] = {sequence: current.title, preference: $('preference').value, note: $('notes').value, frame: shownFrame, view: $('view').value, layout: $('layout').value};
  try {localStorage.setItem('alpine-cascadeur-review-20260912', JSON.stringify(notes)); $('saved').textContent = 'Saved in this browser.';} catch (_) {$('saved').textContent = 'Stored for this session. Download notes to keep them.';}
}
$('save-note').addEventListener('click', saveNote);
$('preference').addEventListener('change', saveNote);
$('notes').addEventListener('input', saveNote);
$('export').addEventListener('click', () => {
  saveNote(); const url = URL.createObjectURL(new Blob([JSON.stringify({report:'Historical Cascadeur comparisons, September 10–11, 2026', judgements:notes}, null, 2)], {type:'application/json'}));
  const link = document.createElement('a'); link.href = url; link.download = 'my-animation-review.json'; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
});
loadCase(current.id);
if (location.protocol === 'http:' || location.protocol === 'https:') {
  const source = document.querySelector('.source');
  fetch(source.getAttribute('src')).then(response => {
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.blob();
  }).then(blob => {source.src = URL.createObjectURL(blob);}).catch(() => {});
}
