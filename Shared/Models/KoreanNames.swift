import Foundation

/// Korean place names in every app language, from the Korean name ("서울 오류동", "경기 수원시 영통구 매탄동"):
/// Korean as it is, Japanese in katakana (KoreanKana), Russian in Cyrillic (the Kontsevich system: "Сеул Орю-дон"),
/// Chinese by the places' own characters (시도 and 시군구 from the table below; a 동 has none on the phone, so it is
/// romanised), every other language in the Revised Romanization ("Seoul Oryu-dong").
enum KoreanNames {
    // MARK: one word

    /// A Korean word in the language (a 시도 by its usual name, a 시군구 in Chinese by its characters)
    static func word(_ w: String, _ lang: Lang, province: String? = nil) -> String {
        guard KoreanKana.hasHangul(w) else { return w }
        if let p = provinces[provinceKey(w)] {
            switch lang {
            case .ko: return w
            case .ja: return KoreanKana.province(w) ?? KoreanKana.place(w)
            case .ru: return p.ru
            case .zhHans: return p.zh
            case .zhHant: return traditional(p.zh)
            default: return provinceKey(w) == "서울" ? (seoul[lang] ?? p.en) : p.en
            }
        }
        switch lang {
        case .ko: return w
        case .ja: return KoreanKana.place(w)
        case .ru: return cyrillic(w)
        case .zhHans: return chinese(w, province: province) ?? latin(w)
        case .zhHant: return chinese(w, province: province).map(traditional) ?? latin(w)
        default: return latin(w)
        }
    }

    /// The whole name, big to small as Korean has it ("서울 오류동" → "Seoul Oryu-dong" · "Сеул Орю-дон" · "首尔 Oryu-dong")
    static func name(_ ko: String, _ lang: Lang) -> String {
        let words = ko.split(separator: " ").map(String.init)
        let province = words.first.flatMap { provinces[provinceKey($0)] != nil ? $0 : nil }
        return join(words.map { word($0, lang, province: province) })
    }

    /// The Chinese characters of a 시도 or 시군구 ("구로구" → "九老区"); nil for a 동 or a name not in the table
    static func chinese(_ w: String, province: String? = nil) -> String? {
        if let p = provinces[provinceKey(w)] { return p.zh }
        if w == "고성군" { return provinceKey(province ?? "") == "경남" ? "固城郡" : "高城郡" }
        if w == "광주시", provinceKey(province ?? "") != "경기", province != nil { return nil }
        return districts[w]
    }

    // MARK: 시도

    struct Province { let en: String; let ru: String; let zh: String }
    /// Seoul as the languages write it
    private static let seoul: [Lang: String] = [.es: "Seúl", .fr: "Séoul", .pt: "Seul", .it: "Seul"]

    /// Words put together: no space between two words in Chinese characters ("首尔九老区"), one elsewhere
    static func join(_ words: [String]) -> String {
        var out = ""
        for w in words where !w.isEmpty {
            if let last = out.unicodeScalars.last, let first = w.unicodeScalars.first, isHan(last), isHan(first) { out += w }
            else { out += out.isEmpty ? w : " " + w }
        }
        return out
    }
    static func isHan(_ u: Unicode.Scalar) -> Bool { (0x4E00...0x9FFF).contains(u.value) || (0x3400...0x4DBF).contains(u.value) }

    /// "서울특별시" · "서울" · "충청북도" · "충청북" (what LocationService.shortCity leaves) · "충북" → one key
    static func provinceKey(_ s: String) -> String {
        var k = s
        for suffix in ["특별자치시", "특별자치도", "통합특별시", "특별시", "광역시"] where k.hasSuffix(suffix) && k.count > suffix.count {
            k = String(k.dropLast(suffix.count)); break
        }
        if k.hasSuffix("도"), k.count >= 3 { k = String(k.dropLast()) }
        let short = ["충청북": "충북", "충청남": "충남", "전라북": "전북", "전라남": "전남", "경상북": "경북", "경상남": "경남", "경기": "경기", "강원": "강원", "제주": "제주"]
        return short[k] ?? k
    }

    static let provinces: [String: Province] = [
        "서울": .init(en: "Seoul", ru: "Сеул", zh: "首尔"),
        "부산": .init(en: "Busan", ru: "Пусан", zh: "釜山"),
        "대구": .init(en: "Daegu", ru: "Тэгу", zh: "大邱"),
        "인천": .init(en: "Incheon", ru: "Инчхон", zh: "仁川"),
        "광주": .init(en: "Gwangju", ru: "Кванджу", zh: "光州"),
        "대전": .init(en: "Daejeon", ru: "Тэджон", zh: "大田"),
        "울산": .init(en: "Ulsan", ru: "Ульсан", zh: "蔚山"),
        "세종": .init(en: "Sejong", ru: "Седжон", zh: "世宗"),
        "경기": .init(en: "Gyeonggi", ru: "Кёнгидо", zh: "京畿道"),
        "강원": .init(en: "Gangwon", ru: "Канвондо", zh: "江原道"),
        "충북": .init(en: "North Chungcheong", ru: "Чхунчхон-Пукто", zh: "忠清北道"),
        "충남": .init(en: "South Chungcheong", ru: "Чхунчхон-Намдо", zh: "忠清南道"),
        "전북": .init(en: "Jeonbuk", ru: "Чонбук", zh: "全北"),
        "전남": .init(en: "South Jeolla", ru: "Чолла-Намдо", zh: "全罗南道"),
        "전남광주": .init(en: "Jeonnam-Gwangju", ru: "Чоннам-Кванджу", zh: "全南光州"),
        "경북": .init(en: "North Gyeongsang", ru: "Кёнсан-Пукто", zh: "庆尚北道"),
        "경남": .init(en: "South Gyeongsang", ru: "Кёнсан-Намдо", zh: "庆尚南道"),
        "제주": .init(en: "Jeju", ru: "Чеджу", zh: "济州"),
    ]

    // MARK: 시군구 in Chinese (simplified; traditional by `traditional`)

    static let districts: [String: String] = [
        "중구": "中区", "동구": "东区", "서구": "西区", "남구": "南区", "북구": "北区",
        // 서울
        "종로구": "钟路区", "용산구": "龙山区", "성동구": "城东区", "광진구": "广津区", "동대문구": "东大门区", "중랑구": "中浪区",
        "성북구": "城北区", "강북구": "江北区", "도봉구": "道峰区", "노원구": "芦原区", "은평구": "恩平区", "서대문구": "西大门区",
        "마포구": "麻浦区", "양천구": "阳川区", "강서구": "江西区", "구로구": "九老区", "금천구": "衿川区", "영등포구": "永登浦区",
        "동작구": "铜雀区", "관악구": "冠岳区", "서초구": "瑞草区", "강남구": "江南区", "송파구": "松坡区", "강동구": "江东区",
        // 부산
        "영도구": "影岛区", "부산진구": "釜山镇区", "동래구": "东莱区", "해운대구": "海云台区", "사하구": "沙下区", "금정구": "金井区",
        "연제구": "莲堤区", "수영구": "水营区", "사상구": "沙上区", "기장군": "机张郡",
        // 대구
        "수성구": "寿城区", "달서구": "达西区", "달성군": "达城郡", "군위군": "军威郡",
        // 인천
        "미추홀구": "弥邹忽区", "연수구": "延寿区", "남동구": "南洞区", "부평구": "富平区", "계양구": "桂阳区", "강화군": "江华郡",
        "옹진군": "瓮津郡", "영종구": "永宗区", "제물포구": "济物浦区", "검단구": "黔丹区", "서해구": "西海区",
        // 광주 · 대전 · 울산
        "광산구": "光山区", "유성구": "儒城区", "대덕구": "大德区", "울주군": "蔚州郡",
        // 경기
        "수원시": "水原市", "장안구": "长安区", "권선구": "劝善区", "팔달구": "八达区", "영통구": "灵通区",
        "성남시": "城南市", "수정구": "寿井区", "중원구": "中院区", "분당구": "盆唐区", "의정부시": "议政府市",
        "안양시": "安养市", "만안구": "万安区", "동안구": "东安区", "부천시": "富川市", "원미구": "远美区", "소사구": "素砂区", "오정구": "梧亭区",
        "광명시": "光明市", "평택시": "平泽市", "동두천시": "东豆川市", "안산시": "安山市", "상록구": "常绿区", "단원구": "檀园区",
        "고양시": "高阳市", "덕양구": "德阳区", "일산동구": "一山东区", "일산서구": "一山西区", "과천시": "果川市", "구리시": "九里市",
        "남양주시": "南杨州市", "오산시": "乌山市", "시흥시": "始兴市", "군포시": "军浦市", "의왕시": "义王市", "하남시": "河南市",
        "용인시": "龙仁市", "처인구": "处仁区", "기흥구": "器兴区", "수지구": "水枝区", "파주시": "坡州市", "이천시": "利川市",
        "안성시": "安城市", "김포시": "金浦市", "화성시": "华城市", "동탄구": "东滩区", "병점구": "饼店区", "만세구": "万岁区", "효행구": "孝行区",
        "광주시": "广州市", "양주시": "杨州市", "포천시": "抱川市", "여주시": "骊州市", "연천군": "涟川郡", "가평군": "加平郡", "양평군": "杨平郡",
        // 강원
        "춘천시": "春川市", "원주시": "原州市", "강릉시": "江陵市", "동해시": "东海市", "태백시": "太白市", "속초시": "束草市", "삼척시": "三陟市",
        "홍천군": "洪川郡", "횡성군": "横城郡", "영월군": "宁越郡", "평창군": "平昌郡", "정선군": "旌善郡", "철원군": "铁原郡", "화천군": "华川郡",
        "양구군": "杨口郡", "인제군": "麟蹄郡", "양양군": "襄阳郡",
        // 충북
        "청주시": "清州市", "상당구": "上党区", "서원구": "西原区", "흥덕구": "兴德区", "청원구": "清原区", "충주시": "忠州市", "제천시": "堤川市",
        "보은군": "报恩郡", "옥천군": "沃川郡", "영동군": "永同郡", "증평군": "曾坪郡", "진천군": "镇川郡", "괴산군": "槐山郡", "음성군": "阴城郡", "단양군": "丹阳郡",
        // 충남
        "천안시": "天安市", "동남구": "东南区", "서북구": "西北区", "공주시": "公州市", "보령시": "保宁市", "아산시": "牙山市", "서산시": "瑞山市",
        "논산시": "论山市", "계룡시": "鸡龙市", "당진시": "唐津市", "금산군": "锦山郡", "부여군": "扶余郡", "서천군": "舒川郡", "청양군": "青阳郡",
        "홍성군": "洪城郡", "예산군": "礼山郡", "태안군": "泰安郡",
        // 전북
        "전주시": "全州市", "완산구": "完山区", "덕진구": "德津区", "군산시": "群山市", "익산시": "益山市", "정읍시": "井邑市", "남원시": "南原市",
        "김제시": "金堤市", "완주군": "完州郡", "진안군": "镇安郡", "무주군": "茂朱郡", "장수군": "长水郡", "임실군": "任实郡", "순창군": "淳昌郡",
        "고창군": "高敞郡", "부안군": "扶安郡",
        // 전남
        "목포시": "木浦市", "여수시": "丽水市", "순천시": "顺天市", "나주시": "罗州市", "광양시": "光阳市", "담양군": "潭阳郡", "곡성군": "谷城郡",
        "구례군": "求礼郡", "고흥군": "高兴郡", "보성군": "宝城郡", "화순군": "和顺郡", "장흥군": "长兴郡", "강진군": "康津郡", "해남군": "海南郡",
        "영암군": "灵岩郡", "무안군": "务安郡", "함평군": "咸平郡", "영광군": "灵光郡", "장성군": "长城郡", "완도군": "莞岛郡", "진도군": "珍岛郡", "신안군": "新安郡",
        // 경북
        "포항시": "浦项市", "경주시": "庆州市", "김천시": "金泉市", "안동시": "安东市", "구미시": "龟尾市", "영주시": "荣州市", "영천시": "永川市",
        "상주시": "尚州市", "문경시": "闻庆市", "경산시": "庆山市", "의성군": "义城郡", "청송군": "青松郡", "영양군": "英阳郡", "영덕군": "盈德郡",
        "청도군": "清道郡", "고령군": "高灵郡", "성주군": "星州郡", "칠곡군": "漆谷郡", "예천군": "醴泉郡", "봉화군": "奉化郡", "울진군": "蔚珍郡", "울릉군": "郁陵郡",
        // 경남
        "창원시": "昌原市", "의창구": "义昌区", "성산구": "城山区", "마산합포구": "马山合浦区", "마산회원구": "马山会原区", "진해구": "镇海区",
        "진주시": "晋州市", "통영시": "统营市", "사천시": "泗川市", "김해시": "金海市", "밀양시": "密阳市", "거제시": "巨济市", "양산시": "梁山市",
        "의령군": "宜宁郡", "함안군": "咸安郡", "창녕군": "昌宁郡", "남해군": "南海郡", "하동군": "河东郡", "산청군": "山清郡", "함양군": "咸阳郡",
        "거창군": "居昌郡", "합천군": "陕川郡",
        // 제주
        "제주시": "济州市", "서귀포시": "西归浦市",
    ]

    /// The table's simplified characters in traditional form (Taiwan · Hong Kong)
    static func traditional(_ s: String) -> String {
        String(s.map { trad[$0] ?? $0 })
    }
    private static let trad: [Character: Character] = [
        "区": "區", "东": "東", "尔": "爾", "龙": "龍", "广": "廣", "门": "門", "阳": "陽", "铜": "銅", "钟": "鍾", "芦": "蘆",
        "岛": "島", "镇": "鎮", "莱": "萊", "云": "雲", "台": "臺", "莲": "蓮", "营": "營", "机": "機", "张": "張", "寿": "壽",
        "达": "達", "军": "軍", "弥": "彌", "邹": "鄒", "华": "華", "瓮": "甕", "济": "濟", "长": "長", "劝": "勸", "灵": "靈",
        "议": "議", "养": "養", "万": "萬", "远": "遠", "泽": "澤", "绿": "綠", "园": "園", "杨": "楊", "乌": "烏", "兴": "興",
        "义": "義", "处": "處", "滩": "灘", "饼": "餅", "岁": "歲", "骊": "驪", "涟": "漣", "宁": "寧", "铁": "鐵", "党": "黨",
        "报": "報", "阴": "陰", "论": "論", "鸡": "雞", "锦": "錦", "余": "餘", "礼": "禮", "实": "實", "丽": "麗", "顺": "順",
        "罗": "羅", "宝": "寶", "务": "務", "庆": "慶", "项": "項", "龟": "龜", "荣": "榮", "闻": "聞", "郁": "鬱", "马": "馬",
        "会": "會", "晋": "晉", "统": "統", "陕": "陝", "归": "歸",
    ]

    // MARK: letters

    private static func jamo(_ c: Character) -> (Int, Int, Int)? {
        guard let u = c.unicodeScalars.first?.value, c.unicodeScalars.count == 1, (0xAC00...0xD7A3).contains(u) else { return nil }
        let i = Int(u) - 0xAC00
        return (i / 588, (i % 588) / 28, i % 28)
    }

    /// The units written after a hyphen ("오류동" → "Oryu-dong"); 가 and 리 only after a number ("을지로3가")
    private static func split(_ w: String) -> (base: String, number: String, unit: String?) {
        var base = w, unit: String?
        if let last = w.last, w.count >= 2 {
            let before = w.dropLast().last
            if "동구시군읍면도".contains(last) || ("가리".contains(last) && (before?.isNumber ?? false)) {
                unit = String(last); base = String(w.dropLast())
            }
        }
        var number = ""
        while let l = base.last, l.isNumber { number = String(l) + number; base.removeLast() }
        return (base, number, unit)
    }

    private static func capitalised(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    private static func assemble(_ w: String, _ letters: (String) -> String, units: [String: String]) -> String {
        let (base, number, unit) = split(w)
        var out = capitalised(letters(base))
        if !number.isEmpty { out += (out.isEmpty ? "" : " ") + number }
        if let u = unit { out += out.isEmpty ? capitalised(units[u] ?? letters(u)) : "-" + (units[u] ?? letters(u)) }
        return out
    }

    /// The Revised Romanization, with its sound changes inside the name ("종로" Jongno · "신림" Sillim · "왕십" Wangsim)
    static func latin(_ w: String) -> String {
        assemble(w, rrLetters, units: ["동": "dong", "구": "gu", "시": "si", "군": "gun", "읍": "eup", "면": "myeon", "도": "do", "가": "ga", "리": "ri"])
    }

    /// The Kontsevich system ("오류" Орю · "강남" Каннам · "수원" Сувон)
    static func cyrillic(_ w: String) -> String {
        assemble(w, cyLetters, units: ["동": "дон", "구": "гу", "시": "си", "군": "гун", "읍": "ып", "면": "мён", "도": "до", "가": "га", "리": "ри"])
    }

    // finals by their sound: k n t l m p ng (0: none)
    private static func finalClass(_ f: Int) -> String {
        switch f {
        case 0: return ""
        case 1, 2, 3, 9, 24: return "k"
        case 4, 5, 6: return "n"
        case 7, 19, 20, 22, 23, 25, 27: return "t"
        case 8, 11, 12, 13, 15: return "l"
        case 10, 16: return "m"
        case 14, 17, 18, 26: return "p"
        case 21: return "ng"
        default: return ""
        }
    }
    /// A final carried over to a silent ㅇ: (what stays, the consonant that moves as an initial index, or nil)
    private static func carry(_ f: Int) -> (stay: Int, move: Int?) {
        switch f {
        case 1: return (0, 0); case 2: return (0, 1); case 3: return (1, 9); case 4: return (0, 2); case 5: return (4, 12)
        case 6: return (4, nil); case 7: return (0, 3); case 8: return (0, 5); case 9: return (8, 0); case 10: return (8, 6)
        case 11: return (8, 7); case 12: return (8, 9); case 13: return (8, 16); case 14: return (8, 17); case 15: return (8, nil)
        case 16: return (0, 6); case 17: return (0, 7); case 18: return (17, 9); case 19: return (0, 9); case 20: return (0, 10)
        case 21: return (21, nil); case 22: return (0, 12); case 23: return (0, 14); case 24: return (0, 15); case 25: return (0, 16)
        case 26: return (0, 17); case 27: return (0, nil)
        default: return (f, nil)
        }
    }

    /// Syllables with their sound changes applied: (initial, vowel, final class). Initial -1: none (a silent ㅇ);
    /// 19: ㄹ heard as ㄴ (종로 → Jongno); 20: ㄹ heard as l after l or n (신림 → Sillim)
    private static func sounds(_ s: String) -> [(Int, Int, String)] {
        var syl = s.compactMap { jamo($0) }
        var out: [(Int, Int, String)] = []
        for i in syl.indices {
            let ini = syl[i].0, vow = syl[i].1
            var fin = syl[i].2
            if i + 1 < syl.count {
                let next = syl[i + 1].0
                if next == 11 {                                  // a silent ㅇ next: the final moves over
                    let c = carry(fin)
                    fin = c.stay
                    if let m = c.move { syl[i + 1].0 = m }
                } else {
                    let cls = finalClass(fin)
                    if next == 2 || next == 6 {                  // before ㄴ ㅁ: k t p → ng n m; l + n → ll
                        switch cls { case "k": fin = 21; case "t": fin = 4; case "p": fin = 16; default: break }
                        if cls == "l", next == 2 { syl[i + 1].0 = 20 }
                    } else if next == 5 {                        // before ㄹ
                        switch cls {
                        case "n", "l": fin = 8; syl[i + 1].0 = 20
                        case "m", "ng": syl[i + 1].0 = 19
                        case "k": fin = 21; syl[i + 1].0 = 19
                        case "p": fin = 16; syl[i + 1].0 = 19
                        case "t": fin = 4; syl[i + 1].0 = 19
                        default: break
                        }
                    }
                }
            }
            out.append((ini == 11 ? -1 : ini, vow, finalClass(fin)))
        }
        return out
    }

    private static let rrInitial = ["g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h", "n", "l"]
    private static let rrVowel = ["a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"]

    private static func rrLetters(_ s: String) -> String {
        var out = ""
        for (ini, vow, fin) in sounds(s) {
            if ini >= 0 { out += rrInitial[ini] }
            out += rrVowel[vow]
            out += fin
        }
        return out
    }

    private static let cyInitial = ["к", "кк", "н", "т", "тт", "р", "м", "п", "пп", "с", "сс", "", "ч", "чч", "чх", "кх", "тх", "пх", "х", "н", "л"]
    private static let cyVoiced: [Int: String] = [0: "г", 3: "д", 7: "б", 12: "дж"]
    private static let cyVowel = ["а", "э", "я", "йе", "о", "е", "ё", "йе", "о", "ва", "вэ", "ве", "ё", "у", "во", "ве", "ви", "ю", "ы", "ый", "и"]
    private static let cyFinal: [String: String] = ["k": "к", "n": "н", "t": "т", "l": "ль", "m": "м", "p": "п", "ng": "н"]

    private static func cyLetters(_ s: String) -> String {
        var out = ""
        var prev: String? = nil                 // the previous syllable's final class (nil: the word's start)
        for (ini, vow, fin) in sounds(s) {
            if ini >= 0 {
                // ㄱ ㄷ ㅂ ㅈ are voiced between vowels and after ㄴ ㄹ ㅁ ㅇ
                let voiced = prev.map { ["", "n", "l", "m", "ng"].contains($0) } ?? false
                out += voiced ? (cyVoiced[ini] ?? cyInitial[ini]) : cyInitial[ini]
                // after a consonant ㅖ ㅒ are е, ㅢ is и (계 ке · 희 хи)
                out += vow == 7 || vow == 3 ? "е" : (vow == 19 ? "и" : cyVowel[vow])
            } else {
                out += prev == nil && vow == 5 ? "э" : cyVowel[vow]       // a word starting with ㅔ
            }
            out += cyFinal[fin] ?? ""
            prev = fin
        }
        return out.replacingOccurrences(of: "льл", with: "лл")
    }
}

extension Lang {
    /// Whether the language's readers can read a name as written: their own script, or Latin letters
    func reads(_ s: String) -> Bool {
        for u in s.unicodeScalars {
            let v = u.value
            if v < 0x80 || !CharacterSet.letters.contains(u) { continue }                     // ASCII, digits, marks, spaces
            let latin = v < 0x250 || (0x1E00...0x1EFF).contains(v)
            let hangul = (0xAC00...0xD7A3).contains(v) || (0x1100...0x11FF).contains(v) || (0x3130...0x318F).contains(v)
            let kana = (0x3040...0x30FF).contains(v) || (0x31F0...0x31FF).contains(v) || (0xFF66...0xFF9F).contains(v)
            let han = (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || (0xF900...0xFAFF).contains(v) || v >= 0x20000
            let cyrillic = (0x0400...0x052F).contains(v)
            if latin { continue }
            switch self {
            case .ko: if hangul { continue }
            case .ja: if kana || han { continue }
            case .zhHans, .zhHant: if han { continue }
            case .ru: if cyrillic { continue }
            default: break
            }
            return false
        }
        return true
    }
}
