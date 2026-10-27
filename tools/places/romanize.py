"""Revised Romanization of Korean for place names: 종로구 → Jongno-gu, 해운대구 → Haeundae-gu, 왕십리 → Wangsimni.
Sound changes are applied inside the name (ㅇ+ㄹ → n, ㄱ+ㄴ → ng …); the administrative suffix (시 군 구 동 읍 면 리 가 도)
is joined with a hyphen and romanized on its own, as on Korean road signs."""
CHO = ['g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h']
JUNG = ['a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae', 'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i']
# final consonant index → (sound class) ; 0 = none
JONG_SOUND = ['', 'k', 'k', 'k', 'n', 'n', 'n', 't', 'l', 'k', 'm', 'l', 'l', 'l', 'p', 'l', 'm', 'p', 'p', 't', 't', 'ng', 't', 't', 'k', 't', 'p', 't']
# a final consonant that moves to the next syllable when it starts with a vowel (index → initial index)
JONG_TO_CHO = {1: 0, 2: 1, 4: 2, 7: 3, 8: 5, 16: 6, 17: 7, 19: 9, 20: 10, 22: 12, 23: 14, 24: 15, 25: 16, 26: 17, 27: 18}
SUFFIX = {'시': 'si', '군': 'gun', '구': 'gu', '동': 'dong', '읍': 'eup', '면': 'myeon', '도': 'do'}

def _split(ch):
    c = ord(ch) - 0xAC00
    return c // 588, (c % 588) // 28, c % 28

def _word(word):
    syl = [_split(ch) for ch in word if '가' <= ch <= '힣']
    if not syl: return word
    out = []
    for i, (cho, jung, jong) in enumerate(syl):
        nxt = syl[i + 1] if i + 1 < len(syl) else None
        # initial: ㄹ at the very start or after a vowel reads r; after ㄹ it is part of ll (handled at the previous final)
        ini = CHO[cho]
        if i > 0:
            pc, pj, pf = syl[i - 1]
            ps = JONG_SOUND[pf]
            if pf == 0:
                ini = 'r' if cho == 5 else CHO[cho]
            elif cho == 11 and pf in JONG_TO_CHO:      # liaison: 금오 → geumo
                ini = ''
            elif cho == 5:                              # initial ㄹ after a final
                ini = 'l' if ps in ('l', 'n') else 'n'    # 신라 → silla, 종로 → jongno
            elif cho == 2 and ps == 'l':                # ㄹ+ㄴ → ll
                ini = 'l'
            elif cho == 18 and ps in ('k', 't', 'p'):   # ㄱ+ㅎ → k (aspiration kept simple)
                ini = ''
        out.append(ini + JUNG[jung])
        # final
        if jong == 0: continue
        sound = JONG_SOUND[jong]
        if nxt:
            ncho = nxt[0]
            if ncho == 11 and jong in JONG_TO_CHO:      # moves to the next syllable
                out.append({0: 'g', 1: 'kk', 2: 'n', 3: 'd', 5: 'r', 6: 'm', 7: 'b', 9: 's', 10: 'ss', 12: 'j', 14: 'ch', 15: 'k', 16: 't', 17: 'p', 18: 'h'}[JONG_TO_CHO[jong]])
                continue
            if ncho in (2, 6):                          # before ㄴ ㅁ: nasalisation
                sound = {'k': 'ng', 't': 'n', 'p': 'm'}.get(sound, sound)
            elif ncho == 5:                             # before ㄹ
                sound = {'k': 'ng', 't': 'n', 'p': 'm', 'n': 'l'}.get(sound, sound)
            elif ncho == 18 and sound in ('k', 't', 'p'):   # 집현 → jiphyeon: aspirate
                sound = {'k': 'k', 't': 't', 'p': 'p'}[sound]
                out.append(sound); out[-1] = sound
                out.append({'k': 'h', 't': 'h', 'p': 'h'}[sound]); out.pop()
        out.append(sound)
    s = ''.join(out)
    return s

def romanize(name):
    """'서울특별시' → 'Seoul', '종로구' → 'Jongno-gu', '청운효자동' → 'Cheongunhyoja-dong'."""
    special = {'서울특별시': 'Seoul', '부산광역시': 'Busan', '대구광역시': 'Daegu', '인천광역시': 'Incheon', '광주광역시': 'Gwangju',
               '대전광역시': 'Daejeon', '울산광역시': 'Ulsan', '세종특별자치시': 'Sejong', '경기도': 'Gyeonggi-do', '강원특별자치도': 'Gangwon-do',
               '충청북도': 'Chungcheongbuk-do', '충청남도': 'Chungcheongnam-do', '전북특별자치도': 'Jeonbuk-do', '전라남도': 'Jeollanam-do',
               '경상북도': 'Gyeongsangbuk-do', '경상남도': 'Gyeongsangnam-do', '제주특별자치도': 'Jeju-do'}
    if name in special: return special[name]
    import re
    parts = []
    for w in name.split():
        if len(w) >= 2 and w[-1] in SUFFIX:
            m = re.match(r'^(.*?)(?:제)?([0-9][0-9.·,]*)?(가)?$', w[:-1])
            base, num, ga = m.group(1), m.group(2), m.group(3)
            r = _word(base)
            out = (r[:1].upper() + r[1:]) + (' ' + num.replace('·', '.') if num else '') + ('-ga' if ga else '') + '-' + SUFFIX[w[-1]]
            parts.append(out)
        else:
            r = _word(w); parts.append(r[:1].upper() + r[1:])
    return ' '.join(parts)

if __name__ == '__main__':
    for n in ['종로구', '중랑구', '해운대구', '마포구', '영등포구', '왕십리', '신림동', '독립문', '압구정동', '관악구', '강남구', '청운효자동',
              '성남시', '분당구', '수원시', '팔달구', '울릉군', '서귀포시', '종로1.2.3.4가동', '신당동', '을지로동', '광희동', '금호1가동', '대림1동']:
        print(n, romanize(n))
