fetch('https://hi.husseinh2711.workers.dev/?url=https%3A%2F%2Flive.143b.ch%2Fcam%2Fflux%2Fseg_111527032239525329_68205_hls.ts&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18', { redirect: 'manual' })
  .then(res => {
    console.log(res.status);
    console.log(res.headers.get('location'));
  });
