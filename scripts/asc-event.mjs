// The App Store in-app event (event card) through the App Store Connect API, from docs/store/in-app-event.json.
// Never prints secrets.
//   node scripts/asc-event.mjs check                   the app's events: state, schedule, localizations, pictures
//   node scripts/asc-event.mjs draft                   makes the event if missing; sets its texts in every locale and
//                                                      uploads the two pictures to each locale that lacks them
//   node scripts/asc-event.mjs schedule START END      eventStart = publishStart = START, eventEnd = END (ISO, e.g.
//                                                      2026-11-14T00:00:00+09:00)
//   node scripts/asc-event.mjs submit                  sends the event to App Review
// Needs ASC_KEY_ID · ASC_ISSUER_ID · ASC_KEY_P8 (Admin key).
import { createPrivateKey, sign } from 'node:crypto';
import { readFileSync, statSync } from 'node:fs';
import { basename } from 'node:path';

const BUNDLE = 'app.purrcast.ios';
const [mode, a1, a2] = process.argv.slice(2);
if (!['check', 'draft', 'schedule', 'submit'].includes(mode)) { console.log('usage: asc-event.mjs check|draft|schedule START END|submit'); process.exit(1); }
const { ASC_KEY_ID: kid, ASC_ISSUER_ID: iss, ASC_KEY_P8: p8 } = process.env;
if (!kid || !iss || !p8) { console.log('missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8'); process.exit(1); }

const b64 = (b) => Buffer.from(b).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const jwt = (() => {
  const h = b64(JSON.stringify({ alg: 'ES256', kid, typ: 'JWT' })), p = b64(JSON.stringify({ iss, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' }));
  return `${h}.${p}.${b64(sign('sha256', Buffer.from(`${h}.${p}`), { key: createPrivateKey(p8), dsaEncoding: 'ieee-p1363' }))}`;
})();
const api = async (path, init = {}) => {
  const r = await fetch(path.startsWith('http') ? path : `https://api.appstoreconnect.apple.com/v1${path}`, { ...init, headers: { authorization: `Bearer ${jwt}`, 'content-type': 'application/json' } });
  const text = await r.text(); let json = null; try { json = JSON.parse(text); } catch {}
  return { ok: r.ok, status: r.status, json, err: json?.errors?.map((e) => `${e.code}: ${e.detail}`).join(' | ') };
};
const must = (r, what) => { if (!r.ok) { console.log(`FAILED ${what}: HTTP ${r.status} ${r.err ?? ''}`); process.exit(1); } return r; };
const body = (type, attributes, relationships, id) => JSON.stringify({ data: { type, ...(id ? { id } : {}), attributes, ...(relationships ? { relationships } : {}) } });

const E = JSON.parse(readFileSync(new URL('../docs/store/in-app-event.json', import.meta.url)));
const app = must(await api(`/apps?filter[bundleId]=${BUNDLE}`), 'app').json?.data?.[0];
if (!app) { console.log(`app ${BUNDLE} not found`); process.exit(1); }
console.log(`app ${app.attributes.name} (${app.id})`);

const events = must(await api(`/apps/${app.id}/appEvents?limit=50`), 'events').json.data;
for (const e of events) {
  const t = e.attributes.territorySchedules?.[0];
  console.log(`event ${e.attributes.referenceName} ${e.attributes.eventState} badge=${e.attributes.badge} ${t ? `publish ${t.publishStart} start ${t.eventStart} end ${t.eventEnd} territories ${t.territories?.length ?? 'all'}` : 'no schedule'}`);
}
let ev = events.find((e) => e.attributes.referenceName === E.referenceName);

const locsOf = async (id) => must(await api(`/appEvents/${id}/localizations?limit=50`), 'event localizations').json.data;
const picsOf = async (lid) => must(await api(`/appEventLocalizations/${lid}/appEventScreenshots?limit=10`), 'event pictures').json.data;

if (ev && mode === 'check') {
  for (const l of await locsOf(ev.id)) {
    const pics = await picsOf(l.id);
    console.log(`  ${l.attributes.locale}: ${l.attributes.name ?? '-'} | pictures ${pics.map((p) => `${p.attributes.appEventAssetType}:${p.attributes.assetDeliveryState?.state ?? '?'}`).join(', ') || 'none'}`);
  }
}
if (mode === 'check') process.exit(0);

if (mode === 'draft') {
  const attributes = { referenceName: E.referenceName, badge: E.badge, deepLink: E.deepLink, purchaseRequirement: E.purchaseRequirement,
    primaryLocale: E.primaryLocale, priority: E.priority, purpose: E.purpose };
  if (!ev) {
    ev = must(await api('/appEvents', { method: 'POST', body: body('appEvents', attributes, { app: { data: { type: 'apps', id: app.id } } }) }), 'new event').json.data;
    console.log(`made event ${E.referenceName} (${ev.id})`);
  } else {
    must(await api(`/appEvents/${ev.id}`, { method: 'PATCH', body: body('appEvents', (({ referenceName, ...rest }) => rest)(attributes), null, ev.id) }), 'event attributes');
    console.log(`event ${E.referenceName} attributes set`);
  }
  const locs = await locsOf(ev.id);
  for (const [locale, t] of Object.entries(E.localizations)) {
    let l = locs.find((x) => x.attributes.locale === locale);
    if (l) must(await api(`/appEventLocalizations/${l.id}`, { method: 'PATCH', body: body('appEventLocalizations', t, null, l.id) }), `${locale} texts`);
    else l = must(await api('/appEventLocalizations', { method: 'POST', body: body('appEventLocalizations', { locale, ...t }, { appEvent: { data: { type: 'appEvents', id: ev.id } } }) }), `${locale} texts`).json.data;
    const have = (await picsOf(l.id)).map((p) => p.attributes.appEventAssetType);
    for (const [kind, file] of [['EVENT_CARD', E.card], ['EVENT_DETAILS_PAGE', E.details]]) {
      if (have.includes(kind)) continue;
      const path = new URL(`../${file}`, import.meta.url), bytes = readFileSync(path);
      const shot = must(await api('/appEventScreenshots', { method: 'POST', body: body('appEventScreenshots',
        { fileName: basename(file), fileSize: statSync(path).size, appEventAssetType: kind },
        { appEventLocalization: { data: { type: 'appEventLocalizations', id: l.id } } }) }), `${locale} ${kind} reserve`).json.data;
      for (const op of shot.attributes.uploadOperations ?? []) {
        const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]));
        const r = await fetch(op.url, { method: op.method, headers, body: bytes.subarray(op.offset, op.offset + op.length) });
        if (!r.ok) { console.log(`FAILED ${locale} ${kind} upload: HTTP ${r.status}`); process.exit(1); }
      }
      must(await api(`/appEventScreenshots/${shot.id}`, { method: 'PATCH', body: body('appEventScreenshots', { uploaded: true }, null, shot.id) }), `${locale} ${kind} commit`);
    }
    console.log(`  ${locale}: texts set, pictures ${have.length === 2 ? 'already there' : 'uploaded'}`);
  }
}

if (mode === 'schedule') {
  if (!ev) { console.log('no event yet: run draft first'); process.exit(1); }
  const start = new Date(a1), end = new Date(a2);
  if (!(start < end) || (end - start) / 86400000 > 31) { console.log('START must be before END, at most 31 days'); process.exit(1); }
  const territorySchedules = [{ publishStart: start.toISOString(), eventStart: start.toISOString(), eventEnd: end.toISOString() }];
  must(await api(`/appEvents/${ev.id}`, { method: 'PATCH', body: body('appEvents', { territorySchedules }, null, ev.id) }), 'schedule');
  console.log(`event ${E.referenceName}: ${start.toISOString()} → ${end.toISOString()}`);
}

if (mode === 'submit') {
  if (!ev) { console.log('no event yet'); process.exit(1); }
  const subs = must(await api(`/reviewSubmissions?filter[app]=${app.id}&filter[platform]=IOS&limit=20`), 'submissions').json.data;
  let sub = subs.find((s) => s.attributes.state === 'READY_FOR_REVIEW');
  if (!sub) sub = must(await api('/reviewSubmissions', { method: 'POST', body: body('reviewSubmissions', { platform: 'IOS' }, { app: { data: { type: 'apps', id: app.id } } }) }), 'new submission').json.data;
  must(await api('/reviewSubmissionItems', { method: 'POST', body: JSON.stringify({ data: { type: 'reviewSubmissionItems', relationships: {
    reviewSubmission: { data: { type: 'reviewSubmissions', id: sub.id } }, appEvent: { data: { type: 'appEvents', id: ev.id } } } } }) }), 'add event to submission');
  must(await api(`/reviewSubmissions/${sub.id}`, { method: 'PATCH', body: body('reviewSubmissions', { submitted: true }, null, sub.id) }), 'submit');
  console.log(`submitted event ${E.referenceName} for App Review (${sub.id})`);
}
