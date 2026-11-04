"""Public holidays for every country, for the 날씨 달력.

    pip install holidays && python3 tools/holidays/make.py [--split DIR]

From the open-source `holidays` package (vacanza/holidays, MIT): national public holidays with substitute days
(대체공휴일, 振替休日, "observed") and election days, in the country's own language, in English, and in the app's
languages where the package has them; last year to four years ahead.

Writes Purrcast/Resources/HolidayZones.json (time zone → country, from zone.tab: the app finds a place's country from
its time zone) and, with --split, DIR/<cc>.json for each country — what tools/holidays/upload.mjs puts on the server
(the app asks the server for its countries' tables and keeps the latest).
"""
import argparse, datetime, json, os, holidays

ap = argparse.ArgumentParser()
ap.add_argument("--split", help="write each country's table to this folder")
args = ap.parse_args()

TODAY = datetime.date.today()
YEARS = range(TODAY.year - 1, TODAY.year + 5)
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


def korean(n):
    """The names as Korean calendars write them: 설날 · 추석 연휴, 대체공휴일, 신정"""
    for big in ("설날", "추석"):
        if n in (big + " 전날", big + " 다음날"):
            return big + " 연휴"
    n = n.replace("대체 휴일", "대체공휴일")
    return "신정" if n == "신정연휴" else n


countries = {}
for code in sorted(holidays.list_supported_countries()):
    if len(code) != 2:
        continue
    base = holidays.country_holidays(code)
    own = names(code, base.default_language)
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
    lang = app_lang(base.default_language)
    for d in days.values():
        if lang == "ko":
            d[""] = korean(d[""])
        if "ko" in d:
            d["ko"] = korean(d["ko"])
    countries[code] = {"cc": code, "lang": lang, "made": TODAY.isoformat(), "package": holidays.__version__,
                       "days": dict(sorted(days.items()))}

zones = {}
for line in open("/usr/share/zoneinfo/zone.tab"):
    p = line.split("\t")
    if not line.startswith("#") and len(p) >= 3:
        zones[p[2].strip()] = p[0]
# old and linked names a phone may still give ("Asia/Calcutta", "US/Eastern" …) take their target's country
try:
    for line in open("/usr/share/zoneinfo/tzdata.zi"):
        p = line.split()
        if len(p) == 3 and p[0] == "L" and p[1] in zones and p[2] not in zones:
            zones[p[2]] = zones[p[1]]
except FileNotFoundError:
    pass

out = os.path.join(ROOT, "Purrcast", "Resources", "HolidayZones.json")
with open(out, "w") as f:
    json.dump(dict(sorted(zones.items())), f, ensure_ascii=False, separators=(",", ":"))
print(out, os.path.getsize(out), "bytes,", len(zones), "zones")
if args.split:
    os.makedirs(args.split, exist_ok=True)
    for code, t in countries.items():
        with open(os.path.join(args.split, code + ".json"), "w") as f:
            json.dump(t, f, ensure_ascii=False, separators=(",", ":"))
    print(args.split, len(countries), "countries", sum(os.path.getsize(os.path.join(args.split, c + ".json")) for c in countries), "bytes")
