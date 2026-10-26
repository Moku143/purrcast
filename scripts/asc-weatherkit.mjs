// Checks (and, with --enable, turns on) the WeatherKit capability of the app's bundle id through the App Store Connect API.
// Needs ASC_KEY_ID · ASC_ISSUER_ID · ASC_KEY_P8 (Admin key) in the environment. Prints what it finds; never prints secrets.
//   node scripts/asc-weatherkit.mjs [--enable] [bundle id]
import { createPrivateKey, sign } from 'node:crypto';

const BUNDLE = process.argv.slice(2).find((a) => !a.startsWith('-')) || 'app.purrcast.ios';
const ENABLE = process.argv.includes('--enable');
const { ASC_KEY_ID: kid, ASC_ISSUER_ID: iss, ASC_KEY_P8: p8 } = process.env;
if (!kid || !iss || !p8) { console.log('missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8'); process.exit(1); }

const b64 = (b) => Buffer.from(b).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const header = b64(JSON.stringify({ alg: 'ES256', kid, typ: 'JWT' }));
const payload = b64(JSON.stringify({ iss, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' }));
const key = createPrivateKey(p8);
const sig = sign('sha256', Buffer.from(`${header}.${payload}`), { key, dsaEncoding: 'ieee-p1363' });
const jwt = `${header}.${payload}.${b64(sig)}`;

const api = async (path, init = {}) => {
  const r = await fetch(`https://api.appstoreconnect.apple.com/v1${path}`, { ...init, headers: { authorization: `Bearer ${jwt}`, 'content-type': 'application/json', ...(init.headers || {}) } });
  const text = await r.text();
  let json = null; try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
};

const list = await api(`/bundleIds?filter[identifier]=${encodeURIComponent(BUNDLE)}&include=bundleIdCapabilities&limit=10`);
if (list.status !== 200) { console.log(`bundleIds: HTTP ${list.status} ${list.json?.errors?.[0]?.detail ?? ''}`); process.exit(1); }
const bid = (list.json.data || []).find((b) => b.attributes.identifier === BUNDLE);
if (!bid) { console.log(`no bundle id ${BUNDLE} registered`); console.log('registered:', (list.json.data || []).map((b) => b.attributes.identifier).join(', ') || '(none)'); process.exit(1); }
console.log(`bundle id ${BUNDLE}: ${bid.id} (${bid.attributes.name}, ${bid.attributes.platform}, team ${bid.attributes.seedId})`);
const caps = (list.json.included || []).filter((c) => c.type === 'bundleIdCapabilities');
console.log('capabilities:', caps.map((c) => c.attributes.capabilityType).join(', ') || '(none)');
const has = caps.some((c) => c.attributes.capabilityType === 'WEATHERKIT');
console.log(`WeatherKit: ${has ? 'ON' : 'OFF'}`);
if (!has && ENABLE) {
  const r = await api('/bundleIdCapabilities', { method: 'POST', body: JSON.stringify({ data: { type: 'bundleIdCapabilities', attributes: { capabilityType: 'WEATHERKIT' }, relationships: { bundleId: { data: { type: 'bundleIds', id: bid.id } } } } }) });
  console.log(`enable WeatherKit: HTTP ${r.status} ${r.json?.errors?.[0]?.detail ?? (r.status === 201 ? 'done' : r.text.slice(0, 200))}`);
}
