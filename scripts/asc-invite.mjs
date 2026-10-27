// Invites a person to test Purrcast as an internal tester, through the App Store Connect API. Prints nothing secret.
//   node scripts/asc-invite.mjs <email> [first] [last]
// 1. not on the team yet → sends the App Store Connect team invitation (role Developer, this app only, no
//    certificates / profiles). The person accepts it from the email with their Apple Account.
// 2. on the team → adds them to the internal TestFlight group "Me"; TestFlight emails them the invitation.
// Run again after they accept step 1 to do step 2.
import { createPrivateKey, sign } from 'node:crypto';

const [email, first = 'Purrcast', last = 'Tester'] = process.argv.slice(2).filter((a) => !a.startsWith('-'));
if (!email || !email.includes('@')) { console.log('usage: asc-invite.mjs <email> [first] [last]'); process.exit(1); }
const { ASC_KEY_ID: kid, ASC_ISSUER_ID: iss, ASC_KEY_P8: p8 } = process.env;
if (!kid || !iss || !p8) { console.log('missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8'); process.exit(1); }
const b64 = (b) => Buffer.from(b).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const header = b64(JSON.stringify({ alg: 'ES256', kid, typ: 'JWT' }));
const payload = b64(JSON.stringify({ iss, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' }));
const jwt = `${header}.${payload}.${b64(sign('sha256', Buffer.from(`${header}.${payload}`), { key: createPrivateKey(p8), dsaEncoding: 'ieee-p1363' }))}`;
const api = async (path, init = {}) => {
  const r = await fetch(`https://api.appstoreconnect.apple.com/v1${path}`, { ...init, headers: { authorization: `Bearer ${jwt}`, 'content-type': 'application/json', ...(init.headers || {}) } });
  const text = await r.text(); let json = null; try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
};
const err = (r) => r.json?.errors?.map((e) => `${e.code}: ${e.detail}`).join(' | ') || r.text.slice(0, 300);
const mask = (e) => e.replace(/^(.{3}).*(@.*)$/, '$1…$2');

const apps = await api('/apps?filter[bundleId]=app.purrcast.ios&limit=1');
const app = apps.json?.data?.[0];
if (!app) { console.log(`app not found: HTTP ${apps.status} ${err(apps)}`); process.exit(1); }

const users = await api(`/users?filter[username]=${encodeURIComponent(email)}&limit=5`);
const user = (users.json?.data || [])[0];
if (!user) {
  const pending = await api(`/userInvitations?filter[email]=${encodeURIComponent(email)}&limit=5`);
  const inv = (pending.json?.data || [])[0];
  if (inv) {
    console.log(`${mask(email)}: team invitation already sent (expires ${inv.attributes.expirationDate?.slice(0, 10)}), not accepted yet`);
  } else {
    const r = await api('/userInvitations', { method: 'POST', body: JSON.stringify({ data: { type: 'userInvitations',
      attributes: { email, firstName: first, lastName: last, roles: ['DEVELOPER'], allAppsVisible: false, provisioningAllowed: false },
      relationships: { visibleApps: { data: [{ type: 'apps', id: app.id }] } } } }) });
    console.log(`${mask(email)}: team invitation ${r.status === 201 ? 'SENT' : `failed HTTP ${r.status} ${err(r)}`}`);
  }
  console.log('after they accept it, run this again to add them to TestFlight');
  process.exit(0);
}
console.log(`${mask(email)}: on the team (${user.attributes.roles?.join(', ')})`);
const groups = await api(`/apps/${app.id}/betaGroups?limit=50`);
const me = (groups.json?.data || []).find((g) => g.attributes.isInternalGroup);
if (!me) { console.log('no internal TestFlight group'); process.exit(1); }
const testers = await api(`/betaTesters?filter[email]=${encodeURIComponent(email)}&include=betaGroups&limit=5`);
const t = (testers.json?.data || [])[0];
if (t && (testers.json.included || []).some((g) => g.id === me.id)) {
  console.log(`already a tester in "${me.attributes.name}"`);
  const r = await api('/betaTesterInvitations', { method: 'POST', body: JSON.stringify({ data: { type: 'betaTesterInvitations',
    relationships: { app: { data: { type: 'apps', id: app.id } }, betaTester: { data: { type: 'betaTesters', id: t.id } } } } }) });
  console.log(`TestFlight invitation re-sent: ${r.status === 201 ? 'yes' : `HTTP ${r.status} ${err(r)}`}`);
} else {
  const r = await api('/betaTesters', { method: 'POST', body: JSON.stringify({ data: { type: 'betaTesters',
    attributes: { email, firstName: first, lastName: last },
    relationships: { betaGroups: { data: [{ type: 'betaGroups', id: me.id }] } } } }) });
  console.log(`added to TestFlight group "${me.attributes.name}": ${r.status === 201 ? 'yes — TestFlight emails the invitation' : `HTTP ${r.status} ${err(r)}`}`);
}
