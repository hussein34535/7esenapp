fetch('https://hi.husseinh2711.workers.dev/?url=https%3A%2F%2Flive.143b.ch%2Fcam%2Fflux%2Fts%3Aabr.m3u8&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18')
  .then(res => res.text())
  .then(text => console.log(text.substring(0, 1000)));
