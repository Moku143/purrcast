// TestFlight status through the App Store Connect API: the latest builds of app.purrcast.ios, whether Apple finished
// processing them, their TestFlight state, and which beta groups have them. With --add, a processed build that the
// internal groups do not have yet is added to every internal group (so it shows as an update in the TestFlight app).
// Needs ASC_KEY_ID · ASC_ISSUER_ID · ASC_KEY_P8 (Admin key). Never prints secrets.
//   node scripts/asc-builds.mjs [--add]
import { createPrivateKey, sign } from 'node:crypto';

const BUNDLE = 'app.purrcast.ios';
const ADD = process.argv.includes('--add');
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
  return { status: r.status, json, err: json?.errors?.map((e) => `${e.code}: ${e.detail}`).join(' | ') };
};

const apps = await api(`/apps?filter[bundleId]=${BUNDLE}`);
const app = apps.json?.data?.[0];
if (!app) { console.log(`app ${BUNDLE} not found (HTTP ${apps.status} ${apps.err ?? ''})`); process.exit(1); }
console.log(`app ${app.attributes.name} (${app.id})`);

const groups = (await api(`/apps/${app.id}/betaGroups?limit=50`)).json?.data || [];
for (const g of groups) console.log(`group "${g.attributes.name}" ${g.attributes.isInternalGroup ? 'internal' : 'external'} · auto-add new builds: ${g.attributes.hasAccessToAllBuilds ?? '?'} (${g.id})`);

const builds = (await api(`/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=8&include=buildBetaDetail,preReleaseVersion`)).json;
const inc = Object.fromEntries((builds?.included || []).map((x) => [`${x.type}:${x.id}`, x]));
console.log('\nbuild · version · uploaded · processing · TestFlight internal / external · expired · groups');
let latestOk = null;
for (const b of builds?.data || []) {
  const a = b.attributes;
  const det = inc[`buildBetaDetails:${b.relationships?.buildBetaDetail?.data?.id}`]?.attributes || {};
  const ver = inc[`preReleaseVersions:${b.relationships?.preReleaseVersion?.data?.id}`]?.attributes?.version ?? '?';
  const bg = ((await api(`/builds/${b.id}/betaGroups`)).json?.data || []).map((g) => g.attributes.name);
  console.log(`${a.version} · ${ver} · ${a.uploadedDate} · ${a.processingState} · ${det.internalBuildState ?? '?'} / ${det.externalBuildState ?? '?'} · ${a.expired ? 'expired' : 'ok'} · [${bg.join(', ')}] · usesNonExemptEncryption=${a.usesNonExemptEncryption}`);
  if (!latestOk && a.processingState === 'VALID' && !a.expired) latestOk = { b, bg };
}

if (ADD && latestOk) {
  const missing = groups.filter((g) => g.attributes.isInternalGroup && !latestOk.bg.includes(g.attributes.name));
  for (const g of missing) {
    const r = await api(`/betaGroups/${g.id}/relationships/builds`, { method: 'POST', body: JSON.stringify({ data: [{ type: 'builds', id: latestOk.b.id }] }) });
    console.log(`add build ${latestOk.b.attributes.version} to "${g.attributes.name}": HTTP ${r.status} ${r.err ?? 'done'}`);
  }
  if (!missing.length) console.log(`build ${latestOk.b.attributes.version} is already in every internal group`);
}
