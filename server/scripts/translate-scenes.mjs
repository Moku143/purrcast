// The app's example scenes (Shared/Data/scenes.json, hand-made in Korean) in English and Japanese, for the
// sample provider when the phone is not Korean: Shared/Data/scenes.en.json · scenes.ja.json.
// Every string is mapped through src/i18n.js so the words match what the server would send.
//   node scripts/translate-scenes.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { strings } from '../src/i18n.js';

const SRC = new URL('../../Shared/Data/scenes.json', import.meta.url);
const KO = strings('ko');

// words the samples use that the server does not emit (seasonal names on the canvas)
const EXTRA = {
  en: { 장맛비: 'Monsoon rain', 태풍: 'Typhoon', '강한 비바람': 'Strong wind and rain', 황사: 'Yellow dust', '꽃샘추위!': 'Spring chill!', '태풍!': 'Typhoon!', '황사!': 'Yellow dust!',
    '구름이 많아 약해요': 'Low (cloudy)', '11~14시에 가장 강해요': 'Strongest 11AM–2PM', '11~15시엔 바깥 활동 줄이기': 'Limit outings 11AM–3PM' },
  ja: { 장맛비: '梅雨の雨', 태풍: '台風', '강한 비바람': '強い雨風', 황사: '黄砂', '꽃샘추위!': '花冷え!', '태풍!': '台風!', '황사!': '黄砂!',
    '구름이 많아 약해요': '弱い（曇り）', '11~14시에 가장 강해요': '11〜14時が最も強い', '11~15시엔 바깥 활동 줄이기': '11〜15時は外出控えめに' },
};

function reverse(obj) { return Object.fromEntries(Object.entries(obj).map(([k, v]) => [v, k])); }

function translator(lang) {
  const T = strings(lang), X = EXTRA[lang];
  const condR = reverse(KO.cond), bubbleR = reverse(KO.bubble), humR = reverse(KO.humidity), tileR = reverse(KO.tile), uvR = reverse(KO.uv);
  const amount = (w) => { const i = KO.rainAmount.indexOf(w); return i < 0 ? w : T.rainAmount[i]; };
  const hour = (h) => (h === '자정' ? T.hour(0) : T.hour(+h));
  const stopAt = (h) => (h === '자정' ? T.stopAt(0) : T.stopAt(+h));
  const cond = (s) => s.split(' · ').map((p) => (condR[p] ? T.cond[condR[p]] : X[p] ?? p)).join(' · ');
  const when = (s) => {
    let m = s.match(/^(\d+)~(\d+)시$/); if (m) return T.when(+m[1], +m[2], false);
    m = s.match(/^(\d+)시쯤$/); if (m) return T.when(+m[1], +m[1], false);
    m = s.match(/^내일 (\d+)~(\d+)시$/); if (m) return T.when(+m[1], +m[2], true);
    return s;
  };
  const bubble = (s) => {
    if (bubbleR[s]) return T.bubble[bubbleR[s]];
    if (X[s]) return X[s];
    const m = s.match(/^(.+?) (비|눈|진눈깨비) 예정$/);
    if (m) return T.expect(when(m[1]), T.what[{ 비: 'rain', 눈: 'snow', 진눈깨비: 'sleet' }[m[2]]]);
    return s;
  };
  const note = (s) => {
    let m;
    if (s === KO.noRain12h) return T.noRain12h;
    if (uvR[s]) return T.uv[uvR[s]];
    if (X[s]) return X[s];
    if ((m = s.match(/^(.+?) (비|눈|진눈깨비) 예정 · (.+?) \((.+)\)$/))) return `${bubble(`${m[1]} ${m[2]} 예정`)} · ${m[3]} (${amount(m[4])})`;
    if ((m = s.match(/^지금 (비|눈|진눈깨비) · 12시간 (.+?)(?: \((.+)\))?$/))) return T.nowWetNote(T.what[{ 비: 'rain', 눈: 'snow', 진눈깨비: 'sleet' }[m[1]]], m[3] ? `${m[2]} (${amount(m[3])})` : m[2]);
    if ((m = s.match(/^(?:새벽 )?(\d+|자정)시?쯤 그칠 예보 · (.+)$/))) return `${stopAt(m[1])} · ${m[2]}`;
    if ((m = s.match(/^내일 일출 (.+)$/))) return T.sunriseTomorrow(m[1]);
    if ((m = s.match(/^일몰 (.+)$/))) return T.sunsetAt(m[1]);
    if ((m = s.match(/^일출 (.+)$/))) return `${T.tile.sunrise} ${m[1]}`;
    if ((m = s.match(/^(.+?) · 이슬점 (-?\d+)°$/))) return `${humR[m[1]] ? T.humidity[humR[m[1]]] : m[1]} · ${T.dewPoint(m[2])}`;
    if ((m = s.match(/^밤 · 내일 낮 최고 (\d+)$/))) return { en: `Night · Tomorrow's peak ${m[1]}`, ja: `夜 · 明日の最高 ${m[1]}` }[lang];
    return s;
  };
  const alertNote = (s) => {
    const parts = s.split(', ').map((p) => {
      let m;
      if ((m = p.match(/^오늘 (.+?)cm$/))) return T.alert.todayCm(m[1]);
      if ((m = p.match(/^오늘 (.+?)mm \((.+)\)$/))) return T.alert.todayMm(m[1], amount(m[2]));
      if ((m = p.match(/^(\d+)시쯤 그칠 예보$/))) return T.stopAt(+m[1]);
      if ((m = p.match(/^돌풍 (.+) m\/s$/))) return T.alert.gust(m[1]);
      if ((m = p.match(/^낮 최고 (-?\d+)°$/))) return T.alert.heat(m[1]).split(T.sep)[0];
      if (p === '한낮 외출 줄여요') return T.alert.heat(0).split(T.sep)[1];
      if ((m = p.match(/^아침 (-?\d+)°$/))) return T.alert.cold(m[1]).split(T.sep)[0];
      if (p === '많이 추워요') return T.alert.cold(0).split(T.sep)[1];
      for (const k of ['icy', 'heavyRain', 'windRain', 'veryWindy', 'takeCare', 'fire', 'mask']) if (KO.alert[k] === p) return T.alert[k];
      return p;
    });
    return parts.map((p, i) => (lang === 'en' && i > 0 ? p.charAt(0).toLowerCase() + p.slice(1) : p)).join(T.sep);
  };
  const hourLabel = (h) => (h === KO.now ? T.now : (h.match(/^(\d+)시$/) ? hour(h.slice(0, -1)) : h));
  const dayName = (d) => (d === KO.today ? T.today : T.weekday({ 일: 'Sun', 월: 'Mon', 화: 'Tue', 수: 'Wed', 목: 'Thu', 금: 'Fri', 토: 'Sat' }[d] ?? d));
  return (scene) => {
    const s = JSON.parse(JSON.stringify(scene));
    s.cond = cond(s.cond);
    if (s.src === '기상청') s.src = { en: 'KMA', ja: '気象庁' }[lang];
    if (s.place) s.place = { en: { '서울 마포구': 'Mapo-gu, Seoul', '도쿄 시부야구': 'Shibuya, Tokyo' }, ja: { '서울 마포구': 'ソウル 麻浦区', '도쿄 시부야구': '東京 渋谷区' } }[lang][s.place] ?? s.place;
    if (s.bubble) s.bubble.text = bubble(s.bubble.text);
    if (s.alert) { s.alert.name = T.warning(s.alert.name); s.alert.note = alertNote(s.alert.note); }
    s.tiles = s.tiles.map((t) => ({ ...t, label: tileR[t.label] ? T.tile[tileR[t.label]] : t.label, note: note(t.note) }));
    s.hours = s.hours.map((h) => [hourLabel(h[0]), ...h.slice(1)]);
    if (s.next6) s.next6 = s.next6.map((h) => [hourLabel(h[0]), ...h.slice(1)]);
    if (s.dayDetail) s.dayDetail = s.dayDetail.map((d) => d.map((r) => [hourLabel(r[0]), ...r.slice(1)]));
    s.days = s.days.map((d) => [dayName(d[0]), ...d.slice(1)]);
    if (s.cmp) s.cmp = { ...s.cmp, sources: s.cmp.sources.map((x) => ({ ...x, name: T.src[x.key] ?? x.name })) };
    return s;
  };
}

const scenes = JSON.parse(readFileSync(SRC, 'utf8'));
for (const lang of ['en', 'ja']) {
  const tr = translator(lang);
  const out = Object.fromEntries(Object.entries(scenes).map(([k, s]) => [k, tr(s)]));
  writeFileSync(new URL(`../../Shared/Data/scenes.${lang}.json`, import.meta.url), JSON.stringify(out));
  // anything still Korean is a word this script does not know
  const left = [...new Set((JSON.stringify(out).match(/"[^"]*[가-힣][^"]*"/g) || []))].filter((x) => !/^"(가|나|다)$/.test(x));
  console.log(lang, Object.keys(out).length, 'scenes', left.length ? 'STILL KOREAN: ' + left.slice(0, 20).join(' ') : 'fully translated');
}
