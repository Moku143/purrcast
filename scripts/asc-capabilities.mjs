// Lists the capabilities of every Purrcast bundle id (app, widgets, watch app, watch widgets) through the App Store
// Connect API and, with --enable, turns App Groups on where it is missing. Prints nothing secret.
//   node scripts/asc-capabilities.mjs [--enable]
import { createPrivateKey, sign } from 'node:crypto';

const ENABLE = process.argv.includes('--enable');
const IDS = ['app.purrcast.ios', 'app.purrcast.ios.widgets', 'app.purrcast.ios.watchkitapp', 'app.purrcast.ios.watchkitapp.widgets'];
const { ASC_KEY_ID: kid, ASC_ISSUER_ID: iss, ASC_KEY_P8: p8 } = process.env;
if (!kid || !iss || !p8) { console.log('missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8'); process.exit(1); }
const b64 = (b) => Buffer.from(b).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const header = b64(JSON.stringify({ alg: 'ES256', kid, typ: 'JWT' }));
const payload = b64(JSON.stringify({ iss, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' }));
const sig = sign('sha256', Buffer.from(`${header}.${payload}`), { key: createPrivateKey(p8), dsaEncoding: 'ieee-p1363' });
const jwt = `${header}.${payload}.${b64(sig)}`;
const api = async (path, init = {}) => {
  const r = await fetch(`https://api.appstoreconnect.apple.com/v1${path}`, { ...init, headers: { authorization: `Bearer ${jwt}`, 'content-type': 'application/json', ...(init.headers || {}) } });
  const text = await r.text(); let json = null; try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
};

const all = await api('/bundleIds?filter[identifier]=app.purrcast&limit=50&include=bundleIdCapabilities');
if (all.status !== 200) { console.log(`bundleIds: HTTP ${all.status} ${all.json?.errors?.[0]?.detail ?? ''}`); process.exit(1); }
console.log('registered:', (all.json.data || []).map((b) => b.attributes.identifier).join(', '));
for (const id of IDS) {
  const r = await api(`/bundleIds?filter[identifier]=${encodeURIComponent(id)}&include=bundleIdCapabilities,profiles&limit=10`);
  const b = (r.json?.data || []).find((x) => x.attributes.identifier === id);
  if (!b) { console.log(`${id}: NOT REGISTERED`); continue; }
  const inc = r.json.included || [];
  const caps = inc.filter((c) => c.type === 'bundleIdCapabilities');
  const profs = inc.filter((c) => c.type === 'profiles');
  console.log(`${id}: ${b.id} · capabilities: ${caps.map((c) => c.attributes.capabilityType + (c.attributes.settings?.length ? JSON.stringify(c.attributes.settings) : '')).join(', ') || '(none)'}`);
  console.log(`   profiles: ${profs.map((p) => `${p.attributes.name} [${p.attributes.profileType}, ${p.attributes.profileState}, until ${p.attributes.expirationDate?.slice(0, 10)}]`).join(' · ') || '(none)'}`);
  if (ENABLE && !caps.some((c) => c.attributes.capabilityType === 'APP_GROUPS')) {
    const e = await api('/bundleIdCapabilities', { method: 'POST', body: JSON.stringify({ data: { type: 'bundleIdCapabilities', attributes: { capabilityType: 'APP_GROUPS' }, relationships: { bundleId: { data: { type: 'bundleIds', id: b.id } } } } }) });
    console.log(`   enable App Groups: HTTP ${e.status} ${e.json?.errors?.[0]?.detail ?? (e.status === 201 ? 'done' : e.text.slice(0, 200))}`);
  }
}
