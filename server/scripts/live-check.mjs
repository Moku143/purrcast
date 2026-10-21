// Live check against the real upstreams (run in CI; MET Norway needs no key, KMA runs only when KMA_SERVICE_KEY is set).
// Prints one line per case and exits non-zero when a scene fails the app contract.
import { forecast, readQuery } from '../src/index.js';
import { validateScene } from '../src/scene.js';

const env = { KMA_SERVICE_KEY: process.env.KMA_SERVICE_KEY || '', CONTACT: process.env.CONTACT || 'github.com/Moku143/purrcast' };
const cases = [
  'lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=free&name=서울 마포구',
  'lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=plus&name=서울 마포구',
  'lat=33.4996&lon=126.5312&region=kr&tz=Asia/Seoul&plan=plus&name=제주 제주시',
  'lat=35.6938&lon=139.7034&region=jp&tz=Asia/Tokyo&plan=plus',
  'lat=40.7128&lon=-74.006&region=other&tz=America/New_York&plan=free',
  'lat=64.1466&lon=-21.9426&region=other&tz=Atlantic/Reykjavik&plan=plus',
];
let failed = 0;
for (const c of cases) {
  try {
    const s = await forecast(readQuery(new URLSearchParams(c)), env, null);
    validateScene(s);
    console.log(`ok   ${c.split('&').slice(0, 4).join(' ')} → ${s.temp}° (체감 ${s.feels}°) lv${s.level} ${s.rain} · ${s.cond} · ${s.bubble ? s.bubble.text || '(생각)' : '-'} · days ${s.days.length}${s.next6 ? ' · next6 ' + s.nextSource : ''}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${c} → ${e.message}`);
  }
}
console.log(env.KMA_SERVICE_KEY ? 'KMA key present: Korea used 기상청' : 'no KMA key: Korea fell back to MET Norway');
process.exit(failed ? 1 : 0);
