//
//  TourAPI.swift
//  FESPOT
//
//  한국관광공사 TourAPI 4.0 연결 — 행사 목록 · 상세 이미지 · 소개글 · 운영 정보 불러오기
//
//  · 키 설정: TARGETS → Info → 키 이름 TOUR_API_KEY, 값 = 공공데이터포털 '일반 인증키(Decoding)'
//  · 흐름: 주소(URL) 만들기 → URLSession으로 요청 → JSON 받기 → Decodable 구조체로 풀기 → EventItem으로 변환
//  · 아래쪽엔 분류(카테고리 정하기) · 주소에서 시·군 이름 뽑기 같은 도우미 함수들이 있어요
//

import Foundation

enum TourAPI {
    static let base = "https://apis.data.go.kr/B551011/KorService2/searchFestival2"

    // ---------- 받은 JSON을 풀어 담을 그릇들 ----------
    // Decodable: JSON의 키 이름과 똑같은 이름의 변수에 값이 자동으로 들어가요
    // 응답 모양: { response: { body: { items: { item: [ Festival, Festival, ... ] } } } }
    struct Festival: Decodable {
        let contentid: String
        let title: String
        let addr1: String?
        let firstimage: String?
        let mapx: String?
        let mapy: String?
        let eventstartdate: String?
        let eventenddate: String?
        let cat3: String?              // 관광공사 분류 코드 (예: A02080300 = 뮤지컬)
    }
    // items가 비면 "" 문자열로 오는 경우가 있어서 직접 풀기
    struct Items: Decodable {
        let item: [Festival]
        init(from decoder: Decoder) throws {
            if let c = try? decoder.container(keyedBy: K.self) {
                if let arr = try? c.decode([Festival].self, forKey: .item) { item = arr; return }
                if let one = try? c.decode(Festival.self, forKey: .item) { item = [one]; return }
            }
            item = []
        }
        enum K: String, CodingKey { case item }
    }
    struct Envelope: Decodable {
        struct Resp: Decodable { let body: Body? }
        struct Body: Decodable { let items: Items? }
        let response: Resp
    }

    // ---------- 행사 목록 불러오기 ----------
    // throws: 실패하면 오류를 던져요 → 부르는 쪽(EventStore)에서 do/catch 로 받아요
    static func fetchFestivals(serviceKey: String) async throws -> [EventItem] {
        let ymd = DateFormatter(); ymd.dateFormat = "yyyyMMdd"; ymd.locale = Locale(identifier: "ko_KR")
        // 이미 시작해서 진행 중인 행사도 받으려고 60일 전부터 조회 → 끝난 행사는 아래에서 걸러냄
        let from = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        // 인증키의 + / = 가 깨지지 않게 직접 인코딩
        let encodedKey = serviceKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? serviceKey
        let query = [
            "serviceKey=\(encodedKey)",
            "MobileOS=IOS", "MobileApp=JigeumYeogi", "_type=json",
            "numOfRows=200", "pageNo=1",
            "arrange=Q",                                   // 대표 이미지 있는 것만, 수정일순
            "eventStartDate=\(ymd.string(from: from))"
        ].joined(separator: "&")
        guard let url = URL(string: base + "?" + query) else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        let list = env.response.body?.items?.item ?? []

        let today = Calendar.current.startOfDay(for: Date())
        // compactMap: 하나씩 EventItem 으로 바꾸고, nil(날짜·좌표 없음, 이미 끝남)은 빼고 모으기
        return list.compactMap { f -> EventItem? in
            guard let s = f.eventstartdate, let e = f.eventenddate,
                  let sd = ymd.date(from: s), let ed = ymd.date(from: e), ed >= today,
                  let lon = Double(f.mapx ?? ""), let lat = Double(f.mapy ?? ""), lat > 0 else { return nil }
            let dot = DateFormatter(); dot.dateFormat = "M.d"
            let full = DateFormatter(); full.dateFormat = "yyyy.MM.dd"
            let kind = classify(title: f.title, cat3: f.cat3)
            return EventItem(
                id: "tour-\(f.contentid)", title: f.title.htmlDecoded, category: kind.0,
                region: regionName(f.addr1 ?? ""), place: f.addr1 ?? "주소 정보 없음",
                latitude: lat, longitude: lon, days: daysOpen(from: sd, to: ed),
                startHour: 10, endHour: 22,
                period: "\(full.string(from: sd)) – \(full.string(from: ed))", price: "상세 정보 확인",
                posterURL: f.firstimage?.replacingOccurrences(of: "http://", with: "https://"),
                allDay: true, startNote: dot.string(from: sd), untilNote: dot.string(from: ed), subType: kind.1,
                startDate: sd, endDate: ed,
                city: cityName(addr: f.addr1, title: f.title))
        }
    }

    // ---------- 상세 화면용 추가 정보 ----------
    static var serviceKey: String? {
        let k = Bundle.main.object(forInfoDictionaryKey: "TOUR_API_KEY") as? String
        return (k ?? "").isEmpty ? nil : k
    }
    static func makeURL(_ op: String, _ params: [String], key: String) -> URL? {
        let enc = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        let q = (["serviceKey=\(enc)", "MobileOS=IOS", "MobileApp=JigeumYeogi", "_type=json"] + params).joined(separator: "&")
        return URL(string: "https://apis.data.go.kr/B551011/KorService2/\(op)?\(q)")
    }
    // 어떤 종류의 item이든 받는 공용 포장지 (하나만 와도, 비어 있어도 OK)
    struct ItemList<T: Decodable>: Decodable {
        let item: [T]
        init(from decoder: Decoder) throws {
            if let c = try? decoder.container(keyedBy: K.self) {
                if let arr = try? c.decode([T].self, forKey: .item) { item = arr; return }
                if let one = try? c.decode(T.self, forKey: .item) { item = [one]; return }
            }
            item = []
        }
        enum K: String, CodingKey { case item }
    }
    struct Env<T: Decodable>: Decodable {
        struct Resp: Decodable { let body: Body? }
        struct Body: Decodable { let items: ItemList<T>? }
        let response: Resp
    }
    struct ImageRow: Decodable { let originimgurl: String?; let smallimageurl: String? }
    struct CommonRow: Decodable { let homepage: String?; let overview: String?; let tel: String? }   // tel = 문의 전화

    // 관광공사에 등록된 행사 이미지들 (주최 측 제공 홍보 이미지 포함)
    static func fetchImages(contentId: String, key: String) async -> [String] {
        guard let u = makeURL("detailImage2", ["contentId=\(contentId)", "imageYN=Y", "numOfRows=20", "pageNo=1"], key: key),
              let res = try? await URLSession.shared.data(from: u),
              let env = try? JSONDecoder().decode(Env<ImageRow>.self, from: res.0) else { return [] }
        return (env.response.body?.items?.item ?? [])
            .compactMap { $0.originimgurl ?? $0.smallimageurl }
            .map { $0.replacingOccurrences(of: "http://", with: "https://") }
    }

    // 공식 홈페이지 주소 + 행사 소개글 + 문의 전화
    static func fetchCommon(contentId: String, key: String) async -> (homepage: URL?, overview: String?, tel: String?) {
        guard let u = makeURL("detailCommon2", ["contentId=\(contentId)"], key: key),
              let res = try? await URLSession.shared.data(from: u),
              let env = try? JSONDecoder().decode(Env<CommonRow>.self, from: res.0),
              let row = env.response.body?.items?.item.first else { return (nil, nil, nil) }
        return (firstLink(row.homepage), cleanText(row.overview), cleanText(row.tel))
    }
    // ---------- 행사 소개정보 (detailIntro2, 행사 타입 = 15) ----------
    struct IntroRow: Decodable {
        let playtime: String?              // 공연·운영 시간
        let usetimefestival: String?       // 이용 요금
        let discountinfofestival: String?  // 할인 정보
        let sponsor1: String?              // 주최
        let sponsor1tel: String?           // 주최 연락처
        let sponsor2tel: String?           // 주관 연락처 (주최 번호가 없을 때 대신)
        let agelimit: String?              // 관람 가능 연령
        let eventplace: String?            // 행사 장소
        let spendtimefestival: String?     // 관람 소요 시간
        let bookingplace: String?          // 예매처
        let program: String?               // 행사 프로그램
    }
    struct FestivalIntro {
        var playtime, fee, discount, host, hostTel, age, place, duration, booking, program: String?
    }
    static func fetchIntro(contentId: String, key: String) async -> FestivalIntro? {
        guard let u = makeURL("detailIntro2", ["contentId=\(contentId)", "contentTypeId=15"], key: key),
              let res = try? await URLSession.shared.data(from: u),
              let env = try? JSONDecoder().decode(Env<IntroRow>.self, from: res.0),
              let r = env.response.body?.items?.item.first else { return nil }
        return FestivalIntro(playtime: cleanText(r.playtime), fee: cleanText(r.usetimefestival),
                             discount: cleanText(r.discountinfofestival), host: cleanText(r.sponsor1),
                             hostTel: cleanText(r.sponsor1tel) ?? cleanText(r.sponsor2tel), age: cleanText(r.agelimit),
                             place: cleanText(r.eventplace), duration: cleanText(r.spendtimefestival),
                             booking: cleanText(r.bookingplace), program: cleanText(r.program))
    }
    // "10:00~18:00", "19시~21시" 같은 글에서 시작 시각 꺼내기 (못 찾으면 nil)
    static func startTime(from text: String?) -> (hour: Int, minute: Int)? {
        guard let t = text else { return nil }
        let ns = t as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let re = try? NSRegularExpression(pattern: #"(\d{1,2})\s*:\s*(\d{2})"#),
           let m = re.firstMatch(in: t, range: range),
           let h = Int(ns.substring(with: m.range(at: 1))), let mi = Int(ns.substring(with: m.range(at: 2))),
           h < 24, mi < 60 { return (h, mi) }
        if let re = try? NSRegularExpression(pattern: #"(\d{1,2})\s*시"#),
           let m = re.firstMatch(in: t, range: range),
           let h = Int(ns.substring(with: m.range(at: 1))), h < 24 { return (h, 0) }
        return nil
    }

    // homepage는 <a href="...">...</a> 같은 HTML로 와서 주소만 꺼냄
    static func firstLink(_ html: String?) -> URL? {
        guard let h = html else { return nil }
        if let r = h.range(of: #"https?://[^\s"'<>]+"#, options: .regularExpression) {
            return URL(string: String(h[r]).replacingOccurrences(of: "&amp;", with: "&"))
        }
        if let r = h.range(of: #"www\.[^\s"'<>]+"#, options: .regularExpression) {
            return URL(string: "https://" + String(h[r]))
        }
        return nil
    }
    // 소개글의 <br> 등 HTML 태그 정리
    static func cleanText(_ html: String?) -> String? {
        guard var t = html, !t.isEmpty else { return nil }
        t = t.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 오늘·내일·이번 주말 중 행사 기간에 들어가는 날
    static func daysOpen(from s: Date, to e: Date) -> Set<Day> {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: Set<Day> = []
        func inRange(_ d: Date) -> Bool { d >= cal.startOfDay(for: s) && d <= cal.startOfDay(for: e) }
        if inRange(today) { result.insert(.today) }
        if let t = cal.date(byAdding: .day, value: 1, to: today), inRange(t) { result.insert(.tomorrow) }
        let wd = cal.component(.weekday, from: today)            // 일=1 … 토=7
        let toSat = (7 - wd + 7) % 7
        if let sat = cal.date(byAdding: .day, value: toSat, to: today) {
            if inRange(sat) { result.insert(.sat) }
            if let sun = cal.date(byAdding: .day, value: 1, to: sat), inRange(sun) { result.insert(.sun) }
        }
        return result
    }

    // ---------- 분류 ----------
    // ① 관광공사 분류 코드로 확실한 것(공연·전시)은 그대로
    static let cat3Map: [String: (EventCategory?, String)] = [
        "A02070100": (nil, "문화관광축제"), "A02070200": (nil, "일반축제"),
        "A02080100": (.concert, "전통공연"), "A02080200": (.concert, "연극"), "A02080300": (.concert, "뮤지컬"),
        "A02080400": (.concert, "오페라"), "A02080500": (.exhibit, "전시회"), "A02080600": (.exhibit, "박람회"),
        "A02080800": (.concert, "무용"), "A02080900": (.concert, "클래식"), "A02081000": (.concert, "콘서트"),
        "A02081100": (.concert, "영화"), "A02081200": (.experience, "스포츠"), "A02081300": (nil, "기타행사")
    ]
    // ② 축제·기타는 제목 키워드로 세분화 (많이 걸린 쪽 승리, 동점이면 위쪽 우선)
    static let keywords: [(EventCategory, [String])] = [
        (.food, ["먹거리", "음식", "푸드", "미식", "맛", "커피", "맥주", "와인", "막걸리", "전통주", "김치", "한우", "떡", "빵", "디저트",
                 "치맥", "대게", "굴", "전어", "젓갈", "인삼", "사과", "딸기", "감귤", "곶감", "송이", "꽃게", "새우", "산채", "한과", "고추", "마늘", "김장", "밤 "]),
        (.market, ["마켓", "장터", "플리", "바자", "벼룩", "야시장", "직거래"]),
        (.night, ["불꽃", "야경", "빛", "야간", "별빛", "등불", "유등", "연등", "등축제", "랜턴", "일루미", "루미나", "드론쇼", "라이트"]),
        (.concert, ["음악", "뮤직", "재즈", "콘서트", "공연", "뮤지컬", "연극", "국악", "오케스트라", "버스킹", "락", "록", "힙합", "클래식",
                    "가요제", "댄스", "탈춤", "풍물", "마당극", "판소리"]),
        (.exhibit, ["전시", "아트", "미술", "사진", "박람회", "비엔날레", "엑스포", "특별전", "갤러리", "디자인", "도서", "책"]),
        (.experience, ["체험", "클래스", "만들기", "공방", "원데이", "캠프", "마라톤", "걷기", "트레킹", "레이스", "보드게임", "게임"])
    ]
    static func keywordCategory(_ t: String) -> (EventCategory, String)? {
        var best: (EventCategory, String, Int)? = nil
        for (c, words) in keywords {
            let hits = words.filter { t.contains($0) }
            if let first = hits.first, hits.count > (best?.2 ?? 0) {
                best = (c, first.trimmingCharacters(in: .whitespaces), hits.count)
            }
        }
        return best.map { ($0.0, $0.1) }
    }
    // ③ 그래도 "축제"로 남으면 어떤 축제인지 세부 이름만 붙이기
    static let festivalSub = ["벚꽃", "국화", "단풍", "꽃", "눈꽃", "얼음", "눈", "머드", "물", "해맞이", "해돋이", "문화제", "민속", "전통", "불교", "역사"]
    static func classify(title: String, cat3: String?) -> (EventCategory, String) {
        let mapped = cat3.flatMap { cat3Map[$0] }
        if let m = mapped, let c = m.0 { return (c, m.1) }               // 공연·전시 코드는 확실
        if let k = keywordCategory(title) { return k }                   // 축제 → 먹거리·야경·마켓·체험…
        if let sub = festivalSub.first(where: { title.contains($0) }) { return (.festival, sub) }
        return (.festival, mapped?.1 ?? "")
    }

    // 시·군·구 짧은 이름: "전북특별자치도 남원시 요천로 …" → "남원" / 주소가 없으면 제목 "[남원] …" 에서
    static func cityName(addr: String?, title: String? = nil) -> String {
        let parts = (addr ?? "").split(separator: " ").map(String.init)
        if parts.count >= 2, let c = shortCity(parts[1]) { return withMetro(c, sido: parts[0]) }
        if let t = title, t.hasPrefix("["), let end = t.firstIndex(of: "]") {   // 제목 앞 [남원]
            let inside = String(t[t.index(after: t.startIndex)..<end]).trimmingCharacters(in: .whitespaces)
            if (2...4).contains(inside.count), !inside.allSatisfy(\.isNumber) { return shortCity(inside) ?? inside }
        }
        return ""
    }
    // 여러 광역시에 똑같이 있는 구 이름이면 앞에 도시 붙이기: "동구" → "광주 동구", "강서" → "부산 강서"
    static let sharedGu: Set<String> = ["동구", "서구", "남구", "북구", "중구", "강서"]
    static func withMetro(_ city: String, sido: String) -> String {
        guard sharedGu.contains(city) else { return city }
        let metro = regionName(sido)
        return metro == "기타" ? city : "\(metro) \(city)"
    }
    // "남원시" → "남원", "양평군" → "양평", "종로구" → "종로" / "중구"처럼 짧으면 그대로
    static func shortCity(_ w: String) -> String? {
        guard let last = w.last, "시군구".contains(last) else { return nil }
        return w.count >= 3 ? String(w.dropLast()) : w
    }

    static func regionName(_ addr: String) -> String {
        let map: [(String, String)] = [("서울", "서울"), ("부산", "부산"), ("대구", "대구"), ("인천", "인천"), ("광주", "광주"),
            ("대전", "대전"), ("울산", "울산"), ("세종", "세종"), ("경기", "경기"), ("강원", "강원"), ("충청북", "충북"), ("충북", "충북"),
            ("충청남", "충남"), ("충남", "충남"), ("전라북", "전북"), ("전북", "전북"), ("전라남", "전남"), ("전남", "전남"),
            ("경상북", "경북"), ("경북", "경북"), ("경상남", "경남"), ("경남", "경남"), ("제주", "제주")]
        return map.first { addr.hasPrefix($0.0) }?.1 ?? "기타"
    }
}
