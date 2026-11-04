// Puts each country's holiday table (tools/holidays/make.py --split DIR) on the server: Workers KV namespace
// "purrcast-holidays" (bound as HOLIDAYS), key `cc:KR` …, and `index` with each table's hash — only the tables that
// changed are written (the free plan allows 1,000 writes a day, shared with the forecasts).
//
//   CLOUDFLARE_API_TOKEN=… CLOUDFLARE_ACCOUNT_ID=… node tools/holidays/upload.mjs DIR
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const dir = process.argv[2];
const token = process.env.CLOUDFLARE_API_TOKEN, account = process.env.CLOUDFLARE_ACCOUNT_ID;
if (!dir || !token || !account) { console.log('holidays: no folder or no Cloudflare secrets — nothing uploaded'); process.exit(0); }
const api = `https://api.cloudflare.com/client/v4/accounts/${account}/storage/kv/namespaces`;
const auth = { Authorization: `Bearer ${token}` };

async function call(url, opts = {}) {
  const r = await fetch(url, { ...opts, headers: { ...auth, ...(opts.headers || {}) } });
  if (!r.ok && r.status !== 404) throw new Error(`${opts.method || 'GET'} ${url.replace(api, '…')}: ${r.status} ${(await r.text()).slice(0, 200)}`);
  return r;
}

// the namespace: found by its title, else made
let id = (await (await call(`${api}?per_page=100`)).json()).result?.find((n) => n.title === 'purrcast-holidays')?.id;
if (!id) {
  id = (await (await call(api, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ title: 'purrcast-holidays' }) })).json()).result?.id;
  console.log('holidays: made the purrcast-holidays namespace');
}
if (!id) throw new Error('holidays: no KV namespace (the token needs Workers KV Storage: Edit)');

const was = await call(`${api}/${id}/values/index`);
const old = was.status === 200 ? await was.json().catch(() => ({})) : {};
const index = {}, put = [];
for (const f of readdirSync(dir).filter((f) => /^[A-Z]{2}\.json$/.test(f)).sort()) {
  const cc = f.slice(0, 2), body = readFileSync(join(dir, f), 'utf8');
  // the hash leaves out the day it was made, so an unchanged table is not written again
  const t = JSON.parse(body); delete t.made; delete t.package;
  index[cc] = createHash('sha1').update(JSON.stringify(t)).digest('hex');
  if (old[cc] !== index[cc]) put.push({ key: `cc:${cc}`, value: body });
}
if (put.length) {
  put.push({ key: 'index', value: JSON.stringify(index) });
  for (let i = 0; i < put.length; i += 5000) {
    await call(`${api}/${id}/bulk`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(put.slice(i, i + 5000)) });
  }
}
const changed = put.filter((p) => p.key !== 'index').map((p) => p.key.slice(3));
console.log(`holidays: ${Object.keys(index).length} countries, ${changed.length} written${changed.length && changed.length < 20 ? ' (' + changed.join(' ') + ')' : ''}`);
