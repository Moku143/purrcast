// A version's App Store screenshots through the App Store Connect API. Never prints secrets.
//   node scripts/asc-shots.mjs check  <version>                      every locale's screenshot sets: display type, count, state
//   node scripts/asc-shots.mjs ipad   <version> <dir>                the 13-inch iPad set of every locale from <dir>/<lang>/01.png …
//                                                                    (docs/store/ipad/compose.py, the store-frames-ipad branch);
//                                                                    a set that already has pictures is emptied first
// The version must exist (asc-release.mjs apply makes it). Needs ASC_KEY_ID · ASC_ISSUER_ID · ASC_KEY_P8 (Admin key).
import { createPrivateKey, sign, createHash } from 'node:crypto';
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';

const BUNDLE = 'app.purrcast.ios';
const IPAD = 'APP_IPAD_PRO_3GEN_129';      // the 13-inch iPad pictures (2064 × 2752 or 2048 × 2732)
const [mode, version, dir] = process.argv.slice(2);
if (!['check', 'ipad'].includes(mode) || !/^\d+\.\d+(\.\d+)?$/.test(version ?? '') || (mode === 'ipad' && !dir)) {
  console.log('usage: asc-shots.mjs check <version> | ipad <version> <dir>'); process.exit(1);
}
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

// App Store Connect locale → the app's picture folder
const folder = { ko: 'ko', 'en-US': 'en', 'en-GB': 'en', 'en-AU': 'en', 'en-CA': 'en', ja: 'ja', 'zh-Hans': 'zh-Hans', 'zh-Hant': 'zh-Hant',
  'de-DE': 'de', 'es-ES': 'es', 'es-MX': 'es', 'fr-FR': 'fr', 'fr-CA': 'fr', it: 'it', 'pt-BR': 'pt-BR', 'pt-PT': 'pt-BR', ru: 'ru', id: 'id' };

const app = must(await api(`/apps?filter[bundleId]=${BUNDLE}`), 'app').json?.data?.[0];
if (!app) { console.log(`app ${BUNDLE} not found`); process.exit(1); }
const ver = must(await api(`/apps/${app.id}/appStoreVersions?filter[platform]=IOS&filter[versionString]=${version}`), 'version').json.data[0];
if (!ver) { console.log(`version ${version} not found: run asc-release apply first`); process.exit(1); }
console.log(`app ${app.attributes.name} · version ${version} (${ver.attributes.appStoreState ?? ver.attributes.appVersionState})`);
const locs = must(await api(`/appStoreVersions/${ver.id}/appStoreVersionLocalizations?limit=50`), 'localizations').json.data;
const setsOf = async (lid) => must(await api(`/appStoreVersionLocalizations/${lid}/appScreenshotSets?limit=50&include=appScreenshots`), 'screenshot sets').json;

for (const l of locs) {
  const locale = l.attributes.locale;
  const got = await setsOf(l.id);
  const shots = (got.included ?? []).filter((x) => x.type === 'appScreenshots');
  const line = got.data.map((s) => {
    const ids = s.relationships?.appScreenshots?.data?.map((x) => x.id) ?? [];
    const bad = shots.filter((x) => ids.includes(x.id) && x.attributes.assetDeliveryState?.state !== 'COMPLETE').length;
    return `${s.attributes.screenshotDisplayType}:${ids.length}${bad ? ` (${bad} not complete)` : ''}`;
  }).join(', ');
  if (mode === 'check') { console.log(`  ${locale}: ${line || 'no pictures'}`); continue; }

  const f = folder[locale];
  const files = f && existsSync(`${dir}/${f}`) ? readdirSync(`${dir}/${f}`).filter((n) => /^\d+\.png$/.test(n)).sort() : [];
  if (!files.length) { console.log(`  ${locale}: no pictures in ${dir}/${f ?? '?'}, skipped`); continue; }
  let set = got.data.find((s) => s.attributes.screenshotDisplayType === IPAD);
  if (set) {
    for (const x of set.relationships?.appScreenshots?.data ?? []) must(await api(`/appScreenshots/${x.id}`, { method: 'DELETE' }), `${locale} old picture`);
  } else {
    set = must(await api('/appScreenshotSets', { method: 'POST', body: body('appScreenshotSets', { screenshotDisplayType: IPAD },
      { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: l.id } } }) }), `${locale} new set`).json.data;
  }
  for (const n of files) {
    const path = `${dir}/${f}/${n}`, bytes = readFileSync(path);
    const shot = must(await api('/appScreenshots', { method: 'POST', body: body('appScreenshots', { fileName: `ipad-${f}-${n}`, fileSize: statSync(path).size },
      { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } }) }), `${locale} ${n} reserve`).json.data;
    for (const op of shot.attributes.uploadOperations ?? []) {
      const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]));
      const r = await fetch(op.url, { method: op.method, headers, body: bytes.subarray(op.offset, op.offset + op.length) });
      if (!r.ok) { console.log(`FAILED ${locale} ${n} upload: HTTP ${r.status}`); process.exit(1); }
    }
    must(await api(`/appScreenshots/${shot.id}`, { method: 'PATCH', body: body('appScreenshots',
      { uploaded: true, sourceFileChecksum: createHash('md5').update(bytes).digest('hex') }, null, shot.id) }), `${locale} ${n} commit`);
  }
  console.log(`  ${locale}: ${files.length} iPad pictures from ${f}/ (was: ${line || 'none'})`);
}
