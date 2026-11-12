// A version for App Review through the App Store Connect API, from docs/store/release-<version>.json
// (whatsNew and promotionalText per locale, reviewNotes). Never prints secrets or the review contact.
//   node scripts/asc-release.mjs check  <version>            what exists: versions and states, builds, texts, submissions
//   node scripts/asc-release.mjs apply  <version> [build]    makes the version if missing, sets the texts and notes,
//                                                            attaches the build (the newest processed one by default)
//   node scripts/asc-release.mjs submit <version>            sends the version to App Review
// Needs ASC_KEY_ID · ASC_ISSUER_ID · ASC_KEY_P8 (Admin key).
import { createPrivateKey, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';

const BUNDLE = 'app.purrcast.ios';
const [mode, version, buildArg] = process.argv.slice(2);
if (!['check', 'apply', 'submit'].includes(mode) || !/^\d+\.\d+(\.\d+)?$/.test(version ?? '')) {
  console.log('usage: asc-release.mjs check|apply|submit <version> [build]'); process.exit(1);
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

const app = must(await api(`/apps?filter[bundleId]=${BUNDLE}`), 'app').json?.data?.[0];
if (!app) { console.log(`app ${BUNDLE} not found`); process.exit(1); }
console.log(`app ${app.attributes.name} (${app.id})`);

// versions
const vers = must(await api(`/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=10&include=build`), 'versions').json;
const buildOf = (v) => vers.included?.find((x) => x.type === 'builds' && x.id === v.relationships?.build?.data?.id);
for (const v of vers.data) {
  const b = buildOf(v);
  console.log(`version ${v.attributes.versionString} ${v.attributes.appStoreState ?? v.attributes.appVersionState} release=${v.attributes.releaseType} build=${b ? b.attributes.version : '-'}`);
}
let ver = vers.data.find((v) => v.attributes.versionString === version);

// builds of this version
const pre = must(await api(`/preReleaseVersions?filter[app]=${app.id}&filter[version]=${version}&filter[platform]=IOS`), 'pre-release').json?.data?.[0];
const builds = pre ? must(await api(`/builds?filter[preReleaseVersion]=${pre.id}&sort=-uploadedDate&limit=10`), 'builds').json.data : [];
for (const b of builds) console.log(`build ${version} (${b.attributes.version}) ${b.attributes.processingState} uploaded ${b.attributes.uploadedDate} expired=${b.attributes.expired}`);

// open review submissions
const subs = must(await api(`/reviewSubmissions?filter[app]=${app.id}&filter[platform]=IOS&limit=10`), 'submissions').json.data;
for (const s of subs) console.log(`submission ${s.id} ${s.attributes.state} ${s.attributes.submittedDate ?? ''}`);

if (ver) {
  const locs = must(await api(`/appStoreVersions/${ver.id}/appStoreVersionLocalizations?limit=50`), 'localizations').json.data;
  for (const l of locs) console.log(`  ${l.attributes.locale}: whatsNew ${l.attributes.whatsNew ? l.attributes.whatsNew.length + ' chars' : 'empty'}, promo ${l.attributes.promotionalText ? l.attributes.promotionalText.length + ' chars' : 'empty'}`);
  const rd = await api(`/appStoreVersions/${ver.id}/appStoreReviewDetail`);
  console.log(`  review detail: ${rd.json?.data ? `present, notes ${rd.json.data.attributes.notes?.length ?? 0} chars, contact ${rd.json.data.attributes.contactEmail ? 'set' : 'missing'}` : 'missing'}`);
}
if (mode === 'check') process.exit(0);

const T = JSON.parse(readFileSync(new URL(`../docs/store/release-${version}.json`, import.meta.url)));

if (mode === 'apply') {
  if (!ver) {
    ver = must(await api('/appStoreVersions', { method: 'POST', body: JSON.stringify({ data: { type: 'appStoreVersions',
      attributes: { platform: 'IOS', versionString: version, releaseType: 'AFTER_APPROVAL' },
      relationships: { app: { data: { type: 'apps', id: app.id } } } } }) }), 'new version').json.data;
    console.log(`made version ${version} (${ver.id})`);
  }
  const state = ver.attributes.appStoreState ?? ver.attributes.appVersionState;
  if (!['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'READY_FOR_REVIEW'].includes(state ?? 'PREPARE_FOR_SUBMISSION')) {
    console.log(`version ${version} is ${state}: not editable here`); process.exit(1);
  }
  const locs = must(await api(`/appStoreVersions/${ver.id}/appStoreVersionLocalizations?limit=50`), 'localizations').json.data;
  for (const [locale, whatsNew] of Object.entries(T.whatsNew)) {
    const promotionalText = T.promotionalText[locale];
    const l = locs.find((x) => x.attributes.locale === locale);
    const r = l
      ? await api(`/appStoreVersionLocalizations/${l.id}`, { method: 'PATCH', body: JSON.stringify({ data: { type: 'appStoreVersionLocalizations', id: l.id, attributes: { whatsNew, promotionalText } } }) })
      : await api('/appStoreVersionLocalizations', { method: 'POST', body: JSON.stringify({ data: { type: 'appStoreVersionLocalizations', attributes: { locale, whatsNew, promotionalText }, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: ver.id } } } } }) });
    console.log(`  ${locale}: ${r.ok ? 'texts set' : `FAILED HTTP ${r.status} ${r.err}`}`);
  }
  const rd = (await api(`/appStoreVersions/${ver.id}/appStoreReviewDetail`)).json?.data;
  if (rd) {
    const r = await api(`/appStoreReviewDetails/${rd.id}`, { method: 'PATCH', body: JSON.stringify({ data: { type: 'appStoreReviewDetails', id: rd.id, attributes: { notes: T.reviewNotes } } }) });
    console.log(`review notes: ${r.ok ? 'set' : `FAILED HTTP ${r.status} ${r.err}`}`);
  } else console.log('review notes: this version has no review detail yet (contact info) — add it in App Store Connect');
  const pick = buildArg ? builds.find((b) => b.attributes.version === buildArg) : builds.find((b) => b.attributes.processingState === 'VALID' && !b.attributes.expired);
  if (!pick || pick.attributes.processingState !== 'VALID') { console.log(`build: none processed yet${buildArg ? ` (${buildArg})` : ''}`); process.exit(1); }
  must(await api(`/appStoreVersions/${ver.id}/relationships/build`, { method: 'PATCH', body: JSON.stringify({ data: { type: 'builds', id: pick.id } }) }), 'attach build');
  console.log(`build ${version} (${pick.attributes.version}) attached`);
}

if (mode === 'submit') {
  if (!ver) { console.log(`no version ${version}`); process.exit(1); }
  let sub = subs.find((s) => ['READY_FOR_REVIEW'].includes(s.attributes.state));
  if (!sub) sub = must(await api('/reviewSubmissions', { method: 'POST', body: JSON.stringify({ data: { type: 'reviewSubmissions', attributes: { platform: 'IOS' }, relationships: { app: { data: { type: 'apps', id: app.id } } } } }) }), 'new submission').json.data;
  const items = must(await api(`/reviewSubmissions/${sub.id}/items`), 'submission items').json.data;
  if (!items.some((i) => i.relationships?.appStoreVersion?.data?.id === ver.id)) {
    must(await api('/reviewSubmissionItems', { method: 'POST', body: JSON.stringify({ data: { type: 'reviewSubmissionItems', relationships: { reviewSubmission: { data: { type: 'reviewSubmissions', id: sub.id } }, appStoreVersion: { data: { type: 'appStoreVersions', id: ver.id } } } } }) }), 'add version to submission');
  }
  must(await api(`/reviewSubmissions/${sub.id}`, { method: 'PATCH', body: JSON.stringify({ data: { type: 'reviewSubmissions', id: sub.id, attributes: { submitted: true } } }) }), 'submit');
  console.log(`submitted ${version} for App Review (${sub.id})`);
}
