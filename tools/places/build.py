"""Builds Purrcast/Resources/places.json, the place search index (app only, not the widgets or the watch).

Sources
  · Korea: 기상청 단기예보 격자·위경도 목록 (the xlsx in the KMA API guide) — 시도 / 시군구 / 읍면동 with coordinates.
    English (and Japanese below the 시도) names are romanized (romanize.py, Revised Romanization).
  · Everywhere else: countries-states-cities-database by dr5hn (ODbL 1.0) — countries and their states / provinces /
    prefectures with Korean, English and Japanese names, coordinates and time zones.
    Japan's 47 prefectures get consistent names written here (東京都 · 도쿄도 · Tokyo …).
The derived file stays under the ODbL (see README.md).

    python3 tools/places/build.py <countries.json> <states.json> <kma-grid.xlsx>
"""
import json, sys, re, unicodedata, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from romanize import romanize

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'Purrcast/Resources/places.json'

JP = {  # code: (ja, ko, en)
    '01': ('北海道', '홋카이도', 'Hokkaido'), '02': ('青森県', '아오모리현', 'Aomori'), '03': ('岩手県', '이와테현', 'Iwate'),
    '04': ('宮城県', '미야기현', 'Miyagi'), '05': ('秋田県', '아키타현', 'Akita'), '06': ('山形県', '야마가타현', 'Yamagata'),
    '07': ('福島県', '후쿠시마현', 'Fukushima'), '08': ('茨城県', '이바라키현', 'Ibaraki'), '09': ('栃木県', '도치기현', 'Tochigi'),
    '10': ('群馬県', '군마현', 'Gunma'), '11': ('埼玉県', '사이타마현', 'Saitama'), '12': ('千葉県', '지바현', 'Chiba'),
    '13': ('東京都', '도쿄도', 'Tokyo'), '14': ('神奈川県', '가나가와현', 'Kanagawa'), '15': ('新潟県', '니가타현', 'Niigata'),
    '16': ('富山県', '도야마현', 'Toyama'), '17': ('石川県', '이시카와현', 'Ishikawa'), '18': ('福井県', '후쿠이현', 'Fukui'),
    '19': ('山梨県', '야마나시현', 'Yamanashi'), '20': ('長野県', '나가노현', 'Nagano'), '21': ('岐阜県', '기후현', 'Gifu'),
    '22': ('静岡県', '시즈오카현', 'Shizuoka'), '23': ('愛知県', '아이치현', 'Aichi'), '24': ('三重県', '미에현', 'Mie'),
    '25': ('滋賀県', '시가현', 'Shiga'), '26': ('京都府', '교토부', 'Kyoto'), '27': ('大阪府', '오사카부', 'Osaka'),
    '28': ('兵庫県', '효고현', 'Hyogo'), '29': ('奈良県', '나라현', 'Nara'), '30': ('和歌山県', '와카야마현', 'Wakayama'),
    '31': ('鳥取県', '돗토리현', 'Tottori'), '32': ('島根県', '시마네현', 'Shimane'), '33': ('岡山県', '오카야마현', 'Okayama'),
    '34': ('広島県', '히로시마현', 'Hiroshima'), '35': ('山口県', '야마구치현', 'Yamaguchi'), '36': ('徳島県', '도쿠시마현', 'Tokushima'),
    '37': ('香川県', '가가와현', 'Kagawa'), '38': ('愛媛県', '에히메현', 'Ehime'), '39': ('高知県', '고치현', 'Kochi'),
    '40': ('福岡県', '후쿠오카현', 'Fukuoka'), '41': ('佐賀県', '사가현', 'Saga'), '42': ('長崎県', '나가사키현', 'Nagasaki'),
    '43': ('熊本県', '구마모토현', 'Kumamoto'), '44': ('大分県', '오이타현', 'Oita'), '45': ('宮崎県', '미야자키현', 'Miyazaki'),
    '46': ('鹿児島県', '가고시마현', 'Kagoshima'), '47': ('沖縄県', '오키나와현', 'Okinawa'),
}
SIDO = {  # 기상청 1단계 → (ko short, en, ja)
    '서울특별시': ('서울', 'Seoul', 'ソウル'), '부산광역시': ('부산', 'Busan', '釜山'), '대구광역시': ('대구', 'Daegu', '大邱'),
    '인천광역시': ('인천', 'Incheon', '仁川'), '대전광역시': ('대전', 'Daejeon', '大田'), '울산광역시': ('울산', 'Ulsan', '蔚山'),
    '세종특별자치시': ('세종', 'Sejong', '世宗'), '경기도': ('경기', 'Gyeonggi', '京畿道'), '강원특별자치도': ('강원', 'Gangwon', '江原道'),
    '충청북도': ('충북', 'North Chungcheong', '忠清北道'), '충청남도': ('충남', 'South Chungcheong', '忠清南道'),
    '전북특별자치도': ('전북', 'Jeonbuk', '全羅北道'), '전남광주통합특별시': ('전남광주', 'Jeonnam-Gwangju', '全南光州'),
    '광주광역시': ('광주', 'Gwangju', '光州'), '전라남도': ('전남', 'South Jeolla', '全羅南道'),
    '경상북도': ('경북', 'North Gyeongsang', '慶尚北道'), '경상남도': ('경남', 'South Gyeongsang', '慶尚南道'),
    '제주특별자치도': ('제주', 'Jeju', '済州道'),
}
ALIASES = {'US': ['USA', 'America', '미합중국', 'アメリカ'], 'GB': ['UK', 'England', 'Britain', '잉글랜드', 'イギリス', 'イングランド'],
           'KR': ['Korea', '한국', '韓国'], 'JP': ['Nippon', '日本国'], 'CN': ['China', '중국', '中国'], 'TW': ['대만', '台湾'],
           'VN': ['베트남', 'ベトナム'], 'AE': ['UAE', '두바이']}


def plain(s):
    """Latin names without macrons (Hokkaidō → Hokkaido)."""
    return ''.join(c for c in unicodedata.normalize('NFKD', s or '') if not unicodedata.combining(c))


def f6(x):
    return round(float(x), 4)


def main(countries_path, states_path, xlsx_path):
    C = json.load(open(countries_path)); S = json.load(open(states_path))
    tr = lambda o: o['translations'] if isinstance(o.get('translations'), dict) else {}
    countries = []
    for c in C:
        t = tr(c)
        tz = (c.get('timezones') or [{}])[0].get('zoneName') or 'UTC'
        if not c.get('latitude'): continue
        countries.append([c['iso2'], t.get('ko') or c['name'], c['name'], t.get('ja') or c['name'], c.get('native') or '',
                          f6(c['latitude']), f6(c['longitude']), tz, ALIASES.get(c['iso2'], [])])
    regions = []
    for s in S:
        if s['country_code'] == 'KR' or not s.get('latitude'): continue
        t = tr(s)
        code = s.get('iso3166_2') or f"{s['country_code']}-{s.get('iso2')}"
        ko, en, ja = t.get('ko') or plain(s['name']), plain(s['name']), t.get('ja') or plain(s['name'])
        if s['country_code'] == 'JP' and s.get('iso2') in JP:
            ja, ko, en = JP[s['iso2']]
        parent = ''
        if s.get('parent_id'):
            p = next((x for x in S if x['id'] == s['parent_id']), None)
            parent = (p.get('iso3166_2') if p else '') or ''
        regions.append([code, s['country_code'], ko, en, ja, s.get('native') or '', f6(s['latitude']), f6(s['longitude']),
                        s.get('timezone') or '', parent])
    # Korea from the KMA list
    import openpyxl
    ws = openpyxl.load_workbook(xlsx_path, read_only=True).worksheets[0]
    kr = []
    for r in ws.iter_rows(min_row=2, values_only=True):
        if r[0] != 'kor' or r[2] not in SIDO: continue
        code, l1, l2, l3 = str(r[1]), r[2], (r[3] or '').strip(), (r[4] or '').strip()
        lon, lat = f6(r[13]), f6(r[14])
        if l2 == l1: l2 = ''                    # 세종특별자치시 repeats itself at level 2
        l2 = re.sub(r'^(.+?시)(.+[구])$', r'\1 \2', l2)   # 수원시장안구 → 수원시 장안구
        short, en1, ja1 = SIDO[l1]
        kr.append([code, l1, l2, l3, lat, lon, short, en1, ja1, romanize(l2) if l2 else '', romanize(l3) if l3 else ''])
    out = {'v': 1, 'src': 'KMA grid list; countries-states-cities-database (ODbL 1.0)',
           'countries': countries, 'regions': regions, 'kr': kr}
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')))
    print(f'{OUT.relative_to(ROOT)}: {len(countries)} countries, {len(regions)} regions, {len(kr)} Korean places, {OUT.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main(*sys.argv[1:4])
