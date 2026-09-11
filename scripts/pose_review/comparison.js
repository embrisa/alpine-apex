// Evidence controls accept a combined comparison or two synchronized videos.
for (const section of document.querySelectorAll('section[data-fps]')) {
  const videos = [...section.querySelectorAll('video')];
  const toolbar = section.querySelector('.playback');
  if (videos.length < 1 || videos.length > 2) { toolbar.hidden = true; continue; }
  const fps = Number(section.dataset.fps);
  const scrub = toolbar.querySelector('input');
  const position = toolbar.querySelector('output');
  const speed = toolbar.querySelector('select');
  const pause = () => videos.forEach(video => video.pause());
  const seek = time => videos.forEach(video => { video.currentTime = time; });
  toolbar.querySelector('[data-action="play"]').addEventListener('click', async () => {
    seek(videos[0].ended ? 0 : videos[0].currentTime);
    const results = await Promise.allSettled(videos.map(video => video.play()));
    if (results.some(result => result.status === 'rejected')) {
      pause(); position.textContent = 'Playback unavailable; inspect the video files.';
    }
  });
  toolbar.querySelector('[data-action="pause"]').addEventListener('click', pause);
  toolbar.querySelector('[data-action="start"]').addEventListener('click', () => { pause(); seek(0); });
  speed.addEventListener('change', () => videos.forEach(video => { video.playbackRate = Number(speed.value); }));
  scrub.addEventListener('input', () => { pause(); seek(Number(scrub.value) / fps); });
  videos[0].addEventListener('timeupdate', () => {
    const frame = Math.min(Number(scrub.max), Math.round(videos[0].currentTime * fps));
    scrub.value = String(frame); position.textContent = `Frame ${frame}`;
    if (videos.length === 2 && !videos[0].paused && Math.abs(videos[1].currentTime - videos[0].currentTime) > .08) {
      videos[1].currentTime = videos[0].currentTime;
    }
  });
  videos[0].addEventListener('ended', pause);
}
