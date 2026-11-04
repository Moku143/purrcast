"""Public holidays for every country, for the 날씨 달력 — writes Purrcast/Resources/Holidays.json.

    pip install holidays && python3 tools/holidays/make.py

From the open-source `holidays` package (vacanza/holidays, MIT): national public holidays with substitute days
(대체공휴일, 振替休日, "observed"), in the country's own language, in English, and in the app's languages where the
package has them. Also the time zone → country table (zone.tab), so a place's country comes from its time zone.
Run it again before a release: holidays announced later (임시공휴일) arrive with the package's updates.
"""
import datetime, json, os, holidays

YEARS = range(datetime.date.today().year - 1, datetime.date.today().year + 5)
# the app's language → the package's language codes to try, in order
APP = {"ko": ["ko"], "en": ["en_US", "en_GB"], "ja": ["ja"], "es": ["es"], "fr": ["fr"], "de": ["de"],
       "pt": ["pt_BR", "pt_PT"], "it": ["it", "it_IT"], "id": ["id"], "ru": ["ru"],
       "zh-Hans": ["zh_CN"], "zh-Hant": ["zh_TW", "zh_HK"]}
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")

def names(code, lang):
    try:
        h = holidays.country_holidays(code, years=YEARS, language=lang)
    except Exception:
        return {}
    return {d.isoformat(): n for d, n in h.items()}

def app_lang(pkg):
    """The package's language code as the app's ("pt_BR" → "pt", "zh_TW" → "zh-Hant")"""
    for app, tries in APP.items():
        if pkg in tries or (pkg or "").split("_")[0] == app:
            return app
    return pkg or ""

countries = {}
for code in sorted(holidays.list_supported_countries()):
    if len(code) != 2:
        continue
    base = holidays.country_holidays(code)
    own = names(code, base.default_language) if base.default_language else names(code, None)
    if not own:
        continue
    have = set(base.supported_languages or ())
    days = {d: {"": n} for d, n in own.items()}
    for app, tries in APP.items():
        lang = next((t for t in tries if t in have), None)
        if not lang or lang == base.default_language:
            continue
        for d, n in names(code, lang).items():
            if d in days and n != days[d][""]:
                days[d][app] = n
    if code == "KR":     # the package calls 1 January 신정연휴 (the old three days); it is 신정 now
        for d, n in days.items():
            if d.endswith("-01-01"): n[""] = "신정"
    countries[code] = {"lang": app_lang(base.default_language), "days": dict(sorted(days.items()))}

zones = {}
for line in open("/usr/share/zoneinfo/zone.tab"):
    if line.startswith("#"):
        continue
    p = line.split("\t")
    if len(p) >= 3:
        zones[p[2].strip()] = p[0]

# old and linked names a phone may still give ("Asia/Calcutta", "Europe/Vaduz" …) take their target's country
try:
    for line in open("/usr/share/zoneinfo/tzdata.zi"):
        p = line.split()
        if len(p) == 3 and p[0] == "L" and p[1] in zones and p[2] not in zones:
            zones[p[2]] = zones[p[1]]
except FileNotFoundError:
    pass

out = os.path.join(ROOT, "Purrcast", "Resources", "Holidays.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w") as f:
    json.dump({"years": [min(YEARS), max(YEARS)], "made": datetime.date.today().isoformat(), "package": holidays.__version__,
               "zones": zones, "countries": countries}, f, ensure_ascii=False, separators=(",", ":"))
print(out, os.path.getsize(out), "bytes,", len(countries), "countries,", len(zones), "zones")
