const PROXY_PREFIX = 'https://hi.husseinh2711.workers.dev/?url=';
const baseUrl = 'https://live.143b.ch/cam/flux/';
const uaSuffix = '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';
const refParam = '';
const isMaster = false;
let line = 'seg_111527032239525329_68205_hls.ts';

let seg = line;
if (!seg.startsWith('http') && !seg.startsWith('data:')) {
    seg = new URL(seg, baseUrl).toString();
}
if (!seg.startsWith('data:')) {
    const extra = isMaster ? '&is_manifest=1' : '';
    console.log(PROXY_PREFIX + encodeURIComponent(seg) + uaSuffix + refParam + extra);
}
