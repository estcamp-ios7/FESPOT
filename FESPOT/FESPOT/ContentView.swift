//
//  지금여기 — 위치 기반 실시간 행사 지도 (전체 코드 한 파일) v3 · TourAPI 실데이터 연결
//  사용법: Xcode 새 프로젝트(iOS App, SwiftUI)의 ContentView.swift 내용을 이 파일로 통째로 교체
//  ⚠️ TARGETS → Info → + → "Privacy - Location When In Use Usage Description" 추가
//  탭: ① 지도(시간 필터 포함)  ② 지역 추천(포스터 그리드)  ③ 찜  ④ 내 정보(프로필)
//  ⚠️ 실데이터: TARGETS → Info → + → 키 이름 TOUR_API_KEY, 값 = 공공데이터포털 '일반 인증키(Decoding)'
//     키가 없거나 불러오기에 실패하면 예시 데이터로 자동 표시돼요
//

/*
저는 집에 가고싶어요 다들 저와 똑같은 생각을 가지고 있다고 생각 중이에요 */
import SwiftUI
import MapKit
import CoreLocation
import Combine
import UserNotifications
import PhotosUI

// =========================================================
// ① 색 · 데이터 모양
// =========================================================

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
    static let ink = Color(rgb: 0x14161F)
    static let inkSub = Color(rgb: 0x5B6170)
    static let coral = Color(rgb: 0xFF6A3D)
    static let liveGreen = Color(rgb: 0x1E9E5A)
    static let liveText = Color(rgb: 0x12723F)
    static let soonText = Color(rgb: 0x2A55B8)
    static let endText = Color(rgb: 0xB4401C)
    static let paper = Color(rgb: 0xF6F6F3)
}

enum EventCategory: String, CaseIterable, Identifiable, Codable {
    case festival = "축제", concert = "공연", exhibit = "전시", market = "플리마켓", food = "먹거리", night = "야경", experience = "체험"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .experience: return Color(rgb: 0x7B61FF)
        case .festival: return .coral
        case .concert: return Color(rgb: 0x3B6FE0)
        case .exhibit: return Color(rgb: 0x129A8F)
        case .market: return Color(rgb: 0xE8A317)
        case .food: return Color(rgb: 0xF08A24)
        case .night: return Color(rgb: 0x2B3A67)
        }
    }
    var icon: String {
        switch self {
        case .experience: return "hands.sparkles.fill"
        case .festival: return "flag.fill"
        case .concert: return "music.note"
        case .exhibit: return "photo.artframe"
        case .market: return "storefront.fill"
        case .food: return "fork.knife"
        case .night: return "moon.stars.fill"
        }
    }
}

enum Day: String, CaseIterable, Identifiable, Hashable {
    case today = "오늘", tomorrow = "내일", sat = "토요일", sun = "일요일"
    var id: String { rawValue }
}

let regionList = ["서울", "경기", "인천", "부산", "강원", "제주"]
let sidoList = ["서울", "경기", "인천", "부산", "대구", "광주", "대전", "울산", "세종", "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주"]

struct EventItem: Identifiable, Hashable {
    let id: String                 // 찜 저장용 고정 아이디
    let title: String
    let category: EventCategory
    let region: String
    let place: String
    let latitude: Double
    let longitude: Double
    let days: Set<Day>
    let startHour: Int
    let endHour: Int
    let period: String
    let price: String
    var posterURL: String? = nil   // 포스터 이미지 주소 (TourAPI firstimage)
    var allDay: Bool = false       // TourAPI 행사: 날짜만 있고 운영 시간은 없음
    var startNote: String = ""     // 예: "11.20"
    var untilNote: String = ""     // 예: "11.30"
    var subType: String = ""       // 세부 유형 예: "뮤지컬", "커피", "박람회"

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    func isOpen(on day: Day, hour: Int) -> Bool { days.contains(day) && (allDay || (hour >= startHour && hour < endHour)) }
    var typeLabel: String { subType.isEmpty || subType == category.rawValue ? category.rawValue : "\(category.rawValue) · \(subType)" }
    var contentId: String? { id.hasPrefix("tour-") ? String(id.dropFirst(5)) : nil }   // TourAPI 행사만
    var hoursText: String { allDay ? "행사 기간 중 (세부 시간은 주최 측 확인)" : "\(startHour):00 – \(endHour):00" }
}

struct EventStatus {
    let text: String
    let color: Color
    let isLive: Bool
    let rank: Int                  // 0 진행 중, 1 곧 시작, 2 나중, 3 종료·휴무
}

// 지금 이 순간 기준 상태
func status(of e: EventItem, nowMinutes m: Int) -> EventStatus {
    if e.allDay {
        return e.days.contains(.today)
            ? EventStatus(text: "진행 중 · \(e.untilNote)까지", color: .liveText, isLive: true, rank: 0)
            : EventStatus(text: "\(e.startNote) 시작", color: .soonText, isLive: false, rank: 2)
    }
    guard e.days.contains(.today) else { return EventStatus(text: "오늘은 쉬어요", color: .inkSub, isLive: false, rank: 3) }
    let start = e.startHour * 60, end = e.endHour * 60
    if m >= start && m < end {
        let left = end - m
        let leftText = left >= 60 ? "\(left / 60)시간 \(left % 60)분" : "\(left)분"
        return EventStatus(text: "진행 중 · \(e.endHour)시까지 (\(leftText) 남음)", color: .liveText, isLive: true, rank: 0)
    }
    if m < start {
        let until = start - m
        return until <= 60
            ? EventStatus(text: "\(until)분 뒤 시작", color: .soonText, isLive: false, rank: 1)
            : EventStatus(text: "\(e.startHour)시 시작", color: .soonText, isLive: false, rank: 2)
    }
    return EventStatus(text: "오늘 종료", color: .endText, isLive: false, rank: 3)
}

func nowMinutes() -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

// 발표용 예시 행사
let sampleEvents: [EventItem] = [
    // 서울
    EventItem(id: "night-market", title: "한강 야시장", category: .festival, region: "서울", place: "뚝섬한강공원 일대",
              latitude: 37.5297, longitude: 127.0670, days: [.today, .sat], startHour: 18, endHour: 22,
              period: "[시작일] – [종료일] · 매주 금·토", price: "[입장료 / 무료]"),
    EventItem(id: "jazz-park", title: "재즈 인 더 파크", category: .concert, region: "서울", place: "서울숲 야외무대",
              latitude: 37.5444, longitude: 127.0374, days: [.today, .sat, .sun], startHour: 19, endHour: 21,
              period: "[시작일] – [종료일]", price: "[입장료]"),
    EventItem(id: "vintage-market", title: "빈티지 플리마켓", category: .market, region: "서울", place: "성수동 카페거리",
              latitude: 37.5446, longitude: 127.0560, days: [.today, .sat, .sun], startHour: 12, endHour: 19,
              period: "[시작일] – [종료일] · 주말", price: "무료"),
    EventItem(id: "media-art", title: "미디어아트 전시", category: .exhibit, region: "서울", place: "성수 복합문화공간",
              latitude: 37.5470, longitude: 127.0440, days: [.today, .tomorrow, .sat, .sun], startHour: 10, endHour: 20,
              period: "[시작일] – [종료일]", price: "[관람료]"),
    EventItem(id: "food-festa", title: "골목 푸드 페스타", category: .food, region: "서울", place: "성수 연무장길",
              latitude: 37.5410, longitude: 127.0600, days: [.tomorrow, .sat, .sun], startHour: 16, endHour: 23,
              period: "[시작일] – [종료일]", price: "무료 (음식 별도)"),
    EventItem(id: "night-tour", title: "불꽃 야경 투어", category: .night, region: "서울", place: "응봉산 전망대",
              latitude: 37.5520, longitude: 127.0330, days: [.sat], startHour: 20, endHour: 22,
              period: "[날짜] 하루", price: "[참가비]"),
    // 경기
    EventItem(id: "suwon-night", title: "성곽 야간 산책", category: .night, region: "경기", place: "수원 화성 일대",
              latitude: 37.2871, longitude: 127.0119, days: [.today, .tomorrow, .sat, .sun], startHour: 19, endHour: 22,
              period: "[시작일] – [종료일]", price: "무료"),
    EventItem(id: "paju-book", title: "출판도시 책 마켓", category: .market, region: "경기", place: "파주 출판도시",
              latitude: 37.7120, longitude: 126.6880, days: [.sat, .sun], startHour: 11, endHour: 18,
              period: "[시작일] – [종료일] · 주말", price: "무료"),
    // 인천
    EventItem(id: "wolmi-busking", title: "바다 버스킹 나이트", category: .concert, region: "인천", place: "월미도 문화의거리",
              latitude: 37.4752, longitude: 126.5970, days: [.sat, .sun], startHour: 17, endHour: 21,
              period: "[시작일] – [종료일]", price: "무료"),
    EventItem(id: "songdo-food", title: "센트럴파크 푸드 페어", category: .food, region: "인천", place: "송도 센트럴파크",
              latitude: 37.3925, longitude: 126.6390, days: [.tomorrow, .sat], startHour: 16, endHour: 22,
              period: "[시작일] – [종료일]", price: "무료 (음식 별도)"),
    // 부산
    EventItem(id: "gwangalli-drone", title: "바다 위 드론 라이트쇼", category: .night, region: "부산", place: "광안리 해수욕장",
              latitude: 35.1532, longitude: 129.1187, days: [.sat], startHour: 20, endHour: 21,
              period: "[날짜]", price: "무료"),
    EventItem(id: "haeundae-sand", title: "모래 조각 페스티벌", category: .festival, region: "부산", place: "해운대 해수욕장",
              latitude: 35.1587, longitude: 129.1604, days: [.sat, .sun], startHour: 10, endHour: 18,
              period: "[시작일] – [종료일]", price: "무료"),
    // 강원
    EventItem(id: "gangneung-coffee", title: "커피 거리 축제", category: .food, region: "강원", place: "강릉 안목해변",
              latitude: 37.7700, longitude: 128.9480, days: [.sat, .sun], startHour: 10, endHour: 18,
              period: "[시작일] – [종료일]", price: "[체험비]"),
    EventItem(id: "sokcho-market", title: "항구 야시장", category: .market, region: "강원", place: "속초 중앙시장 일대",
              latitude: 38.2070, longitude: 128.5918, days: [.today, .sat], startHour: 18, endHour: 23,
              period: "[시작일] – [종료일]", price: "무료"),
    // 제주
    EventItem(id: "jeju-tangerine", title: "감귤 따기 체험 마켓", category: .market, region: "제주", place: "서귀포 농장 일대",
              latitude: 33.2541, longitude: 126.5600, days: [.today, .tomorrow, .sat, .sun], startHour: 10, endHour: 17,
              period: "[시작일] – [종료일]", price: "[체험비]"),
    EventItem(id: "jeju-art", title: "섬 미디어아트 전시", category: .exhibit, region: "제주", place: "제주시 전시관",
              latitude: 33.4996, longitude: 126.5312, days: [.today, .tomorrow, .sat, .sun], startHour: 10, endHour: 19,
              period: "[시작일] – [종료일]", price: "[관람료]")
]

// =========================================================
// ② 프로필 · 공용 창고 · 내 위치
// =========================================================

struct Profile: Codable, Equatable {
    var nickname = ""
    var bio = ""
    var sido = "서울"
    var detail = ""                          // 구·동
    var interests: [EventCategory] = []
    var radiusKm = 3
    var photo: Data? = nil
}

final class EventStore: ObservableObject {
    @Published var saved: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "savedEvents") ?? []) {
        didSet { UserDefaults.standard.set(Array(saved), forKey: "savedEvents") }
    }
    @Published var profile: Profile = {
        if let d = UserDefaults.standard.data(forKey: "profile"), let p = try? JSONDecoder().decode(Profile.self, from: d) { return p }
        return Profile()
    }() {
        didSet { if let d = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(d, forKey: "profile") } }
    }
    func toggleSave(_ e: EventItem) {
        if saved.contains(e.id) { saved.remove(e.id) } else { saved.insert(e.id) }
    }

    // 행사 목록: 처음엔 예시, TourAPI 성공하면 실데이터로 교체
    @Published var events: [EventItem] = sampleEvents
    @Published var dataNote = "예시 데이터"
    @Published var loading = false

    @MainActor
    func loadFestivals() async {
        guard !loading else { return }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "TOUR_API_KEY") as? String, !key.isEmpty else {
            dataNote = "예시 데이터 (TOUR_API_KEY 없음)"; return
        }
        loading = true
        defer { loading = false }
        do {
            let real = try await TourAPI.fetchFestivals(serviceKey: key)
            if real.isEmpty { dataNote = "예시 데이터 (불러온 행사 0개)"; return }
            events = real
            dataNote = "TourAPI 실데이터 \(real.count)개"
        } catch {
            dataNote = "예시 데이터 (불러오기 실패: \(error.localizedDescription))"
        }
    }
}

// =========================================================
// ②-1 한국관광공사 TourAPI 4.0 — 행사정보(searchFestival2)
// =========================================================

enum TourAPI {
    static let base = "https://apis.data.go.kr/B551011/KorService2/searchFestival2"

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
        return list.compactMap { f -> EventItem? in
            guard let s = f.eventstartdate, let e = f.eventenddate,
                  let sd = ymd.date(from: s), let ed = ymd.date(from: e), ed >= today,
                  let lon = Double(f.mapx ?? ""), let lat = Double(f.mapy ?? ""), lat > 0 else { return nil }
            let dot = DateFormatter(); dot.dateFormat = "M.d"
            let full = DateFormatter(); full.dateFormat = "yyyy.MM.dd"
            let kind = classify(title: f.title, cat3: f.cat3)
            return EventItem(
                id: "tour-\(f.contentid)", title: f.title, category: kind.0,
                region: regionName(f.addr1 ?? ""), place: f.addr1 ?? "주소 정보 없음",
                latitude: lat, longitude: lon, days: daysOpen(from: sd, to: ed),
                startHour: 10, endHour: 22,
                period: "\(full.string(from: sd)) – \(full.string(from: ed))", price: "상세 정보 확인",
                posterURL: f.firstimage?.replacingOccurrences(of: "http://", with: "https://"),
                allDay: true, startNote: dot.string(from: sd), untilNote: dot.string(from: ed), subType: kind.1)
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
    struct CommonRow: Decodable { let homepage: String?; let overview: String? }

    // 관광공사에 등록된 행사 이미지들 (주최 측 제공 홍보 이미지 포함)
    static func fetchImages(contentId: String, key: String) async -> [String] {
        guard let u = makeURL("detailImage2", ["contentId=\(contentId)", "imageYN=Y", "numOfRows=20", "pageNo=1"], key: key),
              let res = try? await URLSession.shared.data(from: u),
              let env = try? JSONDecoder().decode(Env<ImageRow>.self, from: res.0) else { return [] }
        return (env.response.body?.items?.item ?? [])
            .compactMap { $0.originimgurl ?? $0.smallimageurl }
            .map { $0.replacingOccurrences(of: "http://", with: "https://") }
    }

    // 공식 홈페이지 주소 + 행사 소개글
    static func fetchCommon(contentId: String, key: String) async -> (homepage: URL?, overview: String?) {
        guard let u = makeURL("detailCommon2", ["contentId=\(contentId)"], key: key),
              let res = try? await URLSession.shared.data(from: u),
              let env = try? JSONDecoder().decode(Env<CommonRow>.self, from: res.0),
              let row = env.response.body?.items?.item.first else { return (nil, nil) }
        return (firstLink(row.homepage), cleanText(row.overview))
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

    static func regionName(_ addr: String) -> String {
        let map: [(String, String)] = [("서울", "서울"), ("부산", "부산"), ("대구", "대구"), ("인천", "인천"), ("광주", "광주"),
            ("대전", "대전"), ("울산", "울산"), ("세종", "세종"), ("경기", "경기"), ("강원", "강원"), ("충청북", "충북"), ("충북", "충북"),
            ("충청남", "충남"), ("충남", "충남"), ("전라북", "전북"), ("전북", "전북"), ("전라남", "전남"), ("전남", "전남"),
            ("경상북", "경북"), ("경북", "경북"), ("경상남", "경남"), ("경남", "경남"), ("제주", "제주")]
        return map.first { addr.hasPrefix($0.0) }?.1 ?? "기타"
    }
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 30
    }
    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

let defaultCenter = CLLocationCoordinate2D(latitude: 37.5446, longitude: 127.0560)   // 위치 모를 때: 성수역 근처

func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}
// 2km 이하 = 도보(4.5km/h) · 20km 이하 = 시내 차량(25km/h) · 그 이상 = 장거리 차량(70km/h)
func distanceText(_ m: Double) -> String {
    let d = m < 1000 ? "\(Int(m))m" : (m < 100_000 ? String(format: "%.1fkm", m / 1000) : String(format: "%.0fkm", m / 1000))
    if m <= 2_000 { return "도보 \(minutesText(m / 75)) · \(d)" }
    if m <= 20_000 { return "차로 \(minutesText(m / 416)) · \(d)" }
    return "차로 약 \(minutesText(m / 1166)) · \(d)"
}
func minutesText(_ minutes: Double) -> String {
    let t = max(1, Int(minutes.rounded()))
    if t < 60 { return "\(t)분" }
    return t % 60 == 0 ? "\(t / 60)시간" : "\(t / 60)시간 \(t % 60)분"
}

// =========================================================
// ③ 앱 뼈대: 하단 탭 4개
// =========================================================

enum AppTab: Hashable { case map, picks, saved, me }

struct ContentView: View {
    @StateObject private var store = EventStore()
    @StateObject private var location = LocationManager()
    @State private var tab: AppTab = .map

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { MapHomeView() }
                .tabItem { Label("지도", systemImage: "map") }.tag(AppTab.map)
            NavigationStack { RegionPicksView().navigationDestination(for: EventItem.self) { EventDetailView(event: $0) } }
                .tabItem { Label("추천", systemImage: "square.grid.2x2") }.tag(AppTab.picks)
            NavigationStack { SavedView().navigationDestination(for: EventItem.self) { EventDetailView(event: $0) } }
                .tabItem { Label("찜", systemImage: "heart") }.tag(AppTab.saved)
            NavigationStack { MeView() }
                .tabItem { Label("내 정보", systemImage: "person") }.tag(AppTab.me)
        }
        .tint(Color.ink)
        .environmentObject(store)
        .environmentObject(location)
        .onAppear { location.request() }
        .task { await store.loadFestivals() }
    }
}

// =========================================================
// ④ 지도 홈: 지도가 주인공 · 핀 탭 = 바로 상세 · 시간 필터
// =========================================================

struct MapHomeView: View {
    @EnvironmentObject var store: EventStore
    @EnvironmentObject var location: LocationManager
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(center: defaultCenter, latitudinalMeters: 3500, longitudinalMeters: 3500))
    @State private var query = ""
    @State private var picked: EventCategory? = nil      // nil = 전체
    @State private var openOnly = false
    @State private var day: Day = .today
    @State private var hour: Int? = nil                  // nil = 지금 이 순간
    @State private var showTime = false
    @State private var selected: EventItem? = nil
    @State private var focusedID: String? = nil           // 검색으로 고른 행사 (핀 강조)
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var searching: Bool

    var timeLabel: String { hour == nil ? "\(day.rawValue) · 지금" : "\(day.rawValue) · \(hour!)시" }

    // 선택한 시간에 열려 있나?
    func isOpen(_ e: EventItem) -> Bool {
        if let h = hour { return e.isOpen(on: day, hour: h) }
        if day == .today { return status(of: e, nowMinutes: nowMinutes()).isLive }
        let h = Calendar.current.component(.hour, from: Date())
        return e.isOpen(on: day, hour: h)
    }
    func runsThatDay(_ e: EventItem) -> Bool { e.days.contains(day) }

    var shown: [EventItem] {
        store.events
            .filter { picked == nil || $0.category == picked }
            .filter { query.isEmpty || matches($0, query) }
            .filter { runsThatDay($0) }
            .filter { !openOnly || isOpen($0) }
    }

    // 이름·장소·지역·종류·세부유형 어디든 걸리면 검색 결과
    func matches(_ e: EventItem, _ q: String) -> Bool {
        let t = q.trimmingCharacters(in: .whitespaces)
        return [e.title, e.place, e.region, e.category.rawValue, e.subType].contains { $0.localizedCaseInsensitiveContains(t) }
    }

    // 검색 결과 위치로 지도 이동: 1개면 그곳으로 확대, 여러 개면 전부 보이게
    func moveCamera(to list: [EventItem]) {
        guard !list.isEmpty else { return }
        if list.count == 1 {
            withAnimation(.easeInOut(duration: 0.6)) {
                position = .region(MKCoordinateRegion(center: list[0].coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
            }
            return
        }
        let lats = list.map(\.latitude), lons = list.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.02, (lats.max()! - lats.min()!) * 1.5),
                                    longitudeDelta: max(0.02, (lons.max()! - lons.min()!) * 1.5))
        withAnimation(.easeInOut(duration: 0.6)) { position = .region(MKCoordinateRegion(center: center, span: span)) }
    }

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(shown) { e in
                let open = isOpen(e)
                Annotation(e.title, coordinate: e.coordinate, anchor: .center) {
                    Button { selected = e } label: {
                        EventPin(category: e.category, live: open, dimmed: !open, highlighted: focusedID == e.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // 타자를 멈추고 0.6초 지나면 자동으로 결과 위치로 이동
        .onChange(of: query) { _, q in
            searchTask?.cancel()
            focusedID = nil
            guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                if !Task.isCancelled { moveCamera(to: shown) }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
        .safeAreaInset(edge: .top) { topBar }
        .toolbar(.hidden, for: .navigationBar)
        // 핀 탭 → 바로 상세 (아래에서 올라오는 시트)
        .sheet(item: $selected) { e in
            NavigationStack {
                EventDetailView(event: e)
                    .navigationDestination(for: EventItem.self) { EventDetailView(event: $0) }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("닫기") { selected = nil }
                        }
                    }
            }
            .presentationDetents([.large])              // 처음부터 화면 가득 (풀시트)
            .presentationDragIndicator(.visible)
            .environmentObject(store)
            .environmentObject(location)
        }
    }

    // 검색 · 카테고리 · 언제 · 열린 곳만
    var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.inkSub)
                TextField("행사·장소·지역·종류 검색 (예: 뮤지컬, 커피, 부산)", text: $query)
                    .focused($searching)
                    .submitLabel(.search)
                    .onSubmit { moveCamera(to: shown); searching = false }
                if !query.isEmpty {
                    Button { query = ""; focusedID = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.inkSub) }
                        .accessibilityLabel("검색어 지우기")
                }
            }
            .padding(.horizontal, 14).frame(height: 50)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)

            // 검색 결과 목록 → 누르면 그 행사 위치로 이동 + 핀 강조
            if searching && !query.isEmpty {
                VStack(spacing: 0) {
                    if shown.isEmpty {
                        Text("검색 결과가 없어요").font(.subheadline).foregroundStyle(Color.inkSub)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    }
                    ForEach(shown.prefix(6)) { e in
                        Button {
                            focusedID = e.id
                            searching = false
                            moveCamera(to: [e])
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: e.category.icon).font(.subheadline).foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(e.category.color, in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.title).font(.subheadline.bold()).foregroundStyle(Color.ink)
                                        .lineLimit(1).truncationMode(.tail)
                                    Text("\(e.typeLabel) · \(e.region)").font(.caption).foregroundStyle(Color.inkSub).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "location.fill").font(.caption).foregroundStyle(Color.inkSub)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 58)
                    }
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(label: "전체", on: picked == nil) { picked = nil }
                    ForEach(EventCategory.allCases) { c in
                        Chip(label: c.rawValue, on: picked == c) { picked = c }
                    }
                }
            }

            HStack(spacing: 8) {
                Button { openOnly.toggle() } label: {
                    HStack(spacing: 8) {
                        Circle().fill(openOnly ? Color.liveGreen : Color.gray.opacity(0.5)).frame(width: 8, height: 8)
                        Text("열린 곳만").font(.subheadline.bold())
                    }
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(openOnly ? Color(rgb: 0xE7F6EE) : Color.white, in: Capsule())
                    .foregroundStyle(openOnly ? Color.liveText : Color.ink)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }
}

// 언제 갈지 고르는 작은 시트 (예전 타임라인 기능)
struct TimeFilterSheet: View {
    @Binding var day: Day
    @Binding var hour: Int?
    @Environment(\.dismiss) private var dismiss
    private let hours = [10, 12, 14, 16, 18, 20, 22]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("언제 갈까요?").font(.title3.bold())
            Picker("요일", selection: $day) {
                ForEach(Day.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                TimeButton(label: "지금", on: hour == nil) { hour = nil }
                ForEach(hours, id: \.self) { h in
                    TimeButton(label: "\(h)시", on: hour == h) { hour = h }
                }
            }
            Button { dismiss() } label: {
                Text("이 시간으로 지도 보기").font(.headline)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.ink, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }
}

struct TimeButton: View {
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(on ? Color.ink : Color.white, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(on ? Color.white : Color.ink)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Color.clear : Color.gray.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}

struct Chip: View {
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.subheadline.bold())
                .padding(.horizontal, 14).frame(height: 36)
                .background(on ? Color.ink : Color.white, in: Capsule())
                .foregroundStyle(on ? Color.white : Color.ink)
                .overlay(Capsule().stroke(on ? Color.clear : Color.gray.opacity(0.25)))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct EventPin: View {
    let category: EventCategory
    let live: Bool
    var dimmed: Bool = false
    var highlighted: Bool = false
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: category.icon)
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(category.color, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            if live {
                Circle().fill(Color.liveGreen).frame(width: 13, height: 13)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
        .opacity(dimmed && !highlighted ? 0.55 : 1)
        .scaleEffect(highlighted ? 1.35 : (dimmed ? 0.85 : 1))
        .background(
            Circle().fill(category.color.opacity(highlighted ? 0.25 : 0))
                .frame(width: 70, height: 70)
        )
        .animation(.spring(response: 0.35), value: highlighted)
        .accessibilityLabel("\(category.rawValue)\(live ? ", 열려 있음" : "")")
    }
}

// =========================================================
// ⑤ 지역 추천: 포스터 그리드
// =========================================================

struct RegionPicksView: View {
    @EnvironmentObject var store: EventStore
    @State private var region: String = ""

    var list: [EventItem] {
        let interests = store.profile.interests
        return store.events.filter { $0.region == region }.sorted {
            let a = interests.contains($0.category) ? 0 : 1, b = interests.contains($1.category) ? 0 : 1
            return a != b ? a < b : $0.title < $1.title
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sidoList, id: \.self) { r in
                            Chip(label: r == store.profile.sido ? "\(r) · 우리 동네" : r, on: region == r) { region = r }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                if !store.profile.interests.isEmpty {
                    Text("관심 카테고리(\(store.profile.interests.map(\.rawValue).joined(separator: ", "))) 먼저 보여드려요")
                        .font(.caption).foregroundStyle(Color.inkSub).padding(.horizontal, 16)
                }
                if list.isEmpty {
                    Text("이 지역은 아직 등록된 행사가 없어요").foregroundStyle(Color.inkSub)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 20) {
                    ForEach(list) { e in
                        NavigationLink(value: e) { PosterCard(event: e) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
        .background(Color.paper)
        .navigationTitle("지역별 추천 행사")
        .onAppear { if region.isEmpty { region = store.profile.sido } }
        .refreshable { await store.loadFestivals() }
    }
}

struct PosterCard: View {
    @EnvironmentObject var store: EventStore
    let event: EventItem
    var body: some View {
        let st = status(of: event, nowMinutes: nowMinutes())
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                // 빈 3:4 틀을 먼저 만들고 → 그 위에 사진을 꽉 채운 뒤 → 틀 밖은 잘라냄
                Color.clear
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay { PosterImage(event: event) }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                if st.isLive {
                    Text("진행 중").font(.caption2.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.liveGreen, in: Capsule())
                        .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { store.toggleSave(event) } label: {
                    Image(systemName: store.saved.contains(event.id) ? "heart.fill" : "heart")
                        .font(.subheadline.bold())
                        .foregroundStyle(store.saved.contains(event.id) ? Color.coral : Color.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.25), in: Circle())
                }
                .accessibilityLabel("찜하기")
                .padding(6)
            }
            Text("\(event.typeLabel) · \(event.region)").font(.caption.bold()).foregroundStyle(event.category.color)
                .lineLimit(1)
            Text(event.title).font(.subheadline.bold()).foregroundStyle(Color.ink)
                .lineLimit(1).truncationMode(.tail)          // 길면 "…"
            Text(event.place).font(.caption).foregroundStyle(Color.inkSub)
                .lineLimit(1).truncationMode(.tail)
        }
    }
}

// 포스터: 주소가 있으면 진짜 이미지, 없으면 자동으로 만든 포스터
struct PosterImage: View {
    let event: EventItem
    var body: some View {
        if let s = event.posterURL, let url = URL(string: s) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } placeholder: { generated }
        } else {
            generated
        }
    }
    var generated: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [event.category.color, event.category.color.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            Image(systemName: event.category.icon)
                .font(.system(size: 90, weight: .bold))
                .foregroundStyle(.white.opacity(0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
                .rotationEffect(.degrees(-8))
            VStack(alignment: .leading, spacing: 4) {
                Text(event.region.uppercased()).font(.caption2.bold()).foregroundStyle(.white.opacity(0.85))
                Text(event.title).font(.system(size: 20, weight: .heavy)).foregroundStyle(.white).lineLimit(2)
                Text(event.allDay ? "~ \(event.untilNote)" : "\(event.startHour):00 – \(event.endHour):00").font(.caption.bold()).foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
        }
    }
}

// =========================================================
// ⑥ 행사 상세
// =========================================================

struct EventDetailView: View {
    @EnvironmentObject var store: EventStore
    @EnvironmentObject var location: LocationManager
    let event: EventItem
    @State private var alertText: String?
    @State private var page = 0                    // 지금 보고 있는 사진 번호
    @State private var fullIndex: FullIndex?       // 전체 화면으로 볼 사진 번호
    @State private var extraImages: [String] = []  // TourAPI 홍보 이미지들
    @State private var homepage: URL?
    @State private var overview: String?
    @State private var showAllOverview = false

    // 첫 장 = 대표 포스터, 그다음 = 관광공사에 올라온 홍보 이미지 (중복 제외). nil = 자동 생성 포스터
    var gallery: [String?] {
        var arr: [String?] = [event.posterURL]
        for u in extraImages where u != event.posterURL && !arr.contains(u) { arr.append(u) }
        return arr
    }

    var me: CLLocationCoordinate2D { location.coordinate ?? defaultCenter }

    var body: some View {
        let st = status(of: event, nowMinutes: nowMinutes())
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 옆으로 넘기는 사진들 (탭하면 전체 화면)
                TabView(selection: $page) {
                    ForEach(Array(gallery.enumerated()), id: \.offset) { i, src in
                        Color.clear
                            .overlay { GalleryImage(src: src, event: event) }
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { fullIndex = FullIndex(id: i) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("사진 \(i + 1), 전체 화면으로 보기")
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: gallery.count > 1 ? .always : .never))
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .topTrailing) {
                    if gallery.count > 1 {
                        Text("\(page + 1) / \(gallery.count)").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(10)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(10)
                        .allowsHitTesting(false)
                }
                if gallery.count > 1 {
                    Text("← 옆으로 넘기면 공식 홍보 이미지 \(gallery.count - 1)장 더 있어요")
                        .font(.caption).foregroundStyle(Color.inkSub)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(event.typeLabel) · \(event.region)").font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(event.category.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.ink)
                    Text(event.title).font(.title2.bold()).lineLimit(2)
                    Text("\(event.place) · \(distanceText(meters(me, event.coordinate)))")
                        .font(.subheadline).foregroundStyle(Color.inkSub)
                }

                HStack(spacing: 10) {
                    Circle().fill(st.isLive ? Color.liveGreen : st.color).frame(width: 10, height: 10)
                    Text(st.text).font(.headline).foregroundStyle(st.color)
                    Spacer()
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.2)))

                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "운영", value: event.hoursText)
                    if !event.allDay {
                        InfoRow(label: "요일", value: Day.allCases.filter { event.days.contains($0) }.map(\.rawValue).joined(separator: " · "))
                    }
                    InfoRow(label: "기간", value: event.period)
                    InfoRow(label: "요금", value: event.price)
                }

                if let ov = overview {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("행사 소개").font(.headline)
                        Text(ov).font(.subheadline).foregroundStyle(Color.ink)
                            .lineLimit(showAllOverview ? nil : 5)
                        Button(showAllOverview ? "접기" : "더 보기") { withAnimation { showAllOverview.toggle() } }
                            .font(.subheadline.bold()).foregroundStyle(Color.inkSub)
                    }
                }
                if let hp = homepage {
                    Link(destination: hp) {
                        Label("공식 홈페이지에서 더 보기", systemImage: "safari")
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).frame(height: 46)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.35)))
                            .foregroundStyle(Color.ink)
                    }
                }

                Map(initialPosition: .region(MKCoordinateRegion(center: event.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)),
                    interactionModes: []) {
                    Annotation(event.title, coordinate: event.coordinate) { EventPin(category: event.category, live: st.isLive) }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 10) {
                    Button { openDirections() } label: {
                        Label("길찾기", systemImage: "location.north.line.fill")
                            .font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                            .background(Color.ink, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    Button { scheduleReminder() } label: {
                        Label("시작 알림", systemImage: "bell")
                            .font(.subheadline.bold()).frame(width: 120, height: 52)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.35)))
                            .foregroundStyle(Color.ink)
                    }
                }
                .buttonStyle(.plain)

                let nearby = store.events
                    .filter { $0.id != event.id && meters(event.coordinate, $0.coordinate) < 2000 }
                    .sorted { meters(event.coordinate, $0.coordinate) < meters(event.coordinate, $1.coordinate) }
                if !nearby.isEmpty {
                    Text("여기서 걸어갈 수 있는 행사").font(.headline)
                    ForEach(nearby) { n in
                        NavigationLink(value: n) {
                            HStack(spacing: 12) {
                                Image(systemName: n.category.icon).foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(n.category.color, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(n.title).font(.subheadline.bold()).foregroundStyle(Color.ink)
                                    let ns = status(of: n, nowMinutes: nowMinutes())
                                    Text("\(ns.text) · \(distanceText(meters(event.coordinate, n.coordinate)))")
                                        .font(.caption.bold()).foregroundStyle(ns.color).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Color.inkSub)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.paper)
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.toggleSave(event) } label: {
                    Image(systemName: store.saved.contains(event.id) ? "heart.fill" : "heart")
                        .foregroundStyle(store.saved.contains(event.id) ? Color.coral : Color.ink)
                }
                .accessibilityLabel("찜하기")
            }
        }
        .alert(alertText ?? "", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button("확인", role: .cancel) {}
        }
        .fullScreenCover(item: $fullIndex) { f in GalleryFullScreen(sources: gallery, start: f.id, event: event) }
        .task(id: event.id) { await loadExtra() }
    }

    // TourAPI 행사면 홍보 이미지 · 소개글 · 홈페이지를 추가로 불러오기
    func loadExtra() async {
        guard let cid = event.contentId, let key = TourAPI.serviceKey else { return }
        async let imgs = TourAPI.fetchImages(contentId: cid, key: key)
        async let info = TourAPI.fetchCommon(contentId: cid, key: key)
        let (i, c) = await (imgs, info)
        extraImages = i
        homepage = c.homepage
        overview = c.overview
    }

    func openDirections() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: event.coordinate))
        item.name = event.title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    // 시작 30분 전 알림 (오늘 열리는 행사만)
    func scheduleReminder() {
        guard !event.allDay else { alertText = "운영 시간 정보가 없는 행사라 시작 알림을 걸 수 없어요"; return }
        guard event.days.contains(.today) else { alertText = "오늘은 열리지 않는 행사예요"; return }
        let fire = event.startHour * 60 - 30
        guard fire > nowMinutes() else { alertText = "이미 시작했거나 30분도 안 남았어요"; return }
        Task {
            let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            guard ok else { alertText = "설정에서 알림을 허용해 주세요"; return }
            let content = UNMutableNotificationContent()
            content.title = "30분 뒤 \(event.title) 시작!"
            content.body = "\(event.place) · 지금 출발하면 딱 맞아요"
            content.sound = .default
            var comps = DateComponents()
            comps.hour = fire / 60
            comps.minute = fire % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "start-\(event.id)", content: content, trigger: trigger))
            alertText = "\(fire / 60):\(String(format: "%02d", fire % 60))에 알려드릴게요"
        }
    }
}

struct FullIndex: Identifiable { let id: Int }

// 칸 안에 꽉 채우는 사진 (주소 없으면 자동 포스터)
struct GalleryImage: View {
    let src: String?
    let event: EventItem
    var body: some View {
        if let s = src, let url = URL(string: s) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } placeholder: { Color.gray.opacity(0.15).overlay(ProgressView()) }
        } else {
            PosterImage(event: event)
        }
    }
}

// 전체 화면 갤러리: 옆으로 넘기기 + 사진마다 확대
struct GalleryFullScreen: View {
    let sources: [String?]
    let start: Int
    let event: EventItem
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(sources.enumerated()), id: \.offset) { i, src in
                    ZoomableImage(src: src, event: event).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: sources.count > 1 ? .always : .never))
            .ignoresSafeArea()

            VStack(spacing: 4) {
                Spacer()
                Text(event.title).font(.subheadline.bold()).foregroundStyle(.white)
                    .lineLimit(1).truncationMode(.tail)
                if sources.count > 1 {
                    Text("\(index + 1) / \(sources.count)").font(.caption).foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline.bold()).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel("닫기")
            .padding(.trailing, 16).padding(.top, 8)
        }
        .statusBarHidden()
        .onAppear { index = start }
    }
}

// 두 손가락 확대 · 두 번 탭 확대 · 확대 중 이동 (확대 안 했을 땐 옆으로 넘기기가 우선)
struct ZoomableImage: View {
    let src: String?
    let event: EventItem
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        picture
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { v in scale = max(1, min(4, lastScale * v)) }
                    .onEnded { _ in
                        lastScale = scale
                        if scale == 1 { withAnimation { offset = .zero; lastOffset = .zero } }
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { v in
                        offset = CGSize(width: lastOffset.width + v.translation.width,
                                        height: lastOffset.height + v.translation.height)
                    }
                    .onEnded { _ in lastOffset = offset },
                including: scale > 1 ? .all : .subviews          // 확대 안 했으면 이동 끄기 → 옆 넘기기 가능
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                    else { scale = 2.5; lastScale = 2.5 }
                }
            }
    }

    @ViewBuilder var picture: some View {
        if let s = src, let url = URL(string: s) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()          // 잘리지 않게 "맞추기"
                case .failure: Text("사진을 불러오지 못했어요").foregroundStyle(.white)
                default: ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            PosterImage(event: event)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label).foregroundStyle(Color.inkSub).frame(width: 44, alignment: .leading)
            Text(value).foregroundStyle(Color.ink)
        }
        .font(.subheadline)
    }
}

// =========================================================
// ⑦ 찜
// =========================================================

struct SavedView: View {
    @EnvironmentObject var store: EventStore
    var body: some View {
        let list = store.events.filter { store.saved.contains($0.id) }
        ScrollView {
            if list.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart").font(.largeTitle).foregroundStyle(Color.inkSub)
                    Text("마음에 드는 행사에 ♡를 눌러 모아보세요").foregroundStyle(Color.inkSub)
                }
                .padding(.top, 80)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 20) {
                ForEach(list) { e in
                    NavigationLink(value: e) { PosterCard(event: e) }.buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color.paper)
        .navigationTitle("찜한 행사")
    }
}

// =========================================================
// ⑧ 내 정보: 프로필 카드 + 편집
// =========================================================

struct Avatar: View {
    let profile: Profile
    var size: CGFloat = 72
    var body: some View {
        Group {
            if let d = profile.photo, let ui = UIImage(data: d) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Text(String(profile.nickname.prefix(1)).isEmpty ? "?" : String(profile.nickname.prefix(1)))
                    .font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.coral)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct MeView: View {
    @EnvironmentObject var store: EventStore
    var p: Profile { store.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 프로필 카드
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        Avatar(profile: p)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.nickname.isEmpty ? "닉네임을 정해주세요" : p.nickname).font(.title3.bold())
                            Label(p.detail.isEmpty ? p.sido : "\(p.sido) · \(p.detail)", systemImage: "house")
                                .font(.subheadline).foregroundStyle(Color.inkSub)
                        }
                        Spacer()
                    }
                    if !p.bio.isEmpty { Text(p.bio).font(.subheadline) }
                    NavigationLink { ProfileEditView() } label: {
                        Text("프로필 편집").font(.subheadline.bold())
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35)))
                            .foregroundStyle(Color.ink)
                    }
                }
                .padding(18)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))

                // 요약 숫자
                HStack(spacing: 12) {
                    StatBox(value: "\(store.saved.count)", label: "찜한 행사")
                    StatBox(value: "\(p.interests.count)", label: "관심 카테고리")
                    StatBox(value: "\(p.radiusKm)km", label: "관심 반경")
                }

                // 관심 카테고리
                VStack(alignment: .leading, spacing: 10) {
                    Text("관심 있는 행사").font(.headline)
                    if p.interests.isEmpty {
                        Text("프로필 편집에서 고르면 추천 탭에 먼저 보여드려요").font(.subheadline).foregroundStyle(Color.inkSub)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(p.interests) { c in
                                    Label(c.rawValue, systemImage: c.icon).font(.subheadline.bold())
                                        .padding(.horizontal, 12).frame(height: 36)
                                        .background(c.color.opacity(0.15), in: Capsule())
                                        .foregroundStyle(Color.ink)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))

                // 행사 데이터 상태
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("행사 데이터").font(.subheadline.bold())
                        Text(store.dataNote).font(.caption).foregroundStyle(Color.inkSub)
                    }
                    Spacer()
                    if store.loading { ProgressView() }
                    else {
                        Button("새로고침") { Task { await store.loadFestivals() } }
                            .font(.subheadline.bold()).foregroundStyle(Color.ink)
                    }
                }
                .padding(18)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                Text("행사 정보 출처: 한국관광공사 TourAPI").font(.caption2).foregroundStyle(Color.inkSub)
            }
            .padding(16)
        }
        .background(Color.paper)
        .navigationTitle("내 정보")
    }
}

struct StatBox: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).foregroundStyle(Color.ink)
            Text(label).font(.caption).foregroundStyle(Color.inkSub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ProfileEditView: View {
    @EnvironmentObject var store: EventStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Profile()
    @State private var photoItem: PhotosPickerItem?
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Avatar(profile: draft, size: 96)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("사진 바꾸기").font(.subheadline.bold())
                        }
                        if draft.photo != nil {
                            Button("사진 지우기", role: .destructive) { draft.photo = nil }.font(.caption)
                        }
                    }
                    Spacer()
                }
            }
            Section("기본 정보") {
                TextField("닉네임", text: $draft.nickname)
                TextField("한 줄 소개 (예: 주말마다 축제 찾아다녀요)", text: $draft.bio)
            }
            Section {
                Picker("시·도", selection: $draft.sido) {
                    ForEach(sidoList, id: \.self) { Text($0).tag($0) }
                }
                TextField("구·동 (예: 성동구 성수동)", text: $draft.detail)
            } header: {
                Text("사는 곳")
            } footer: {
                Text("추천 탭이 사는 지역 행사부터 보여줘요.")
            }
            Section("관심 있는 행사") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                    ForEach(EventCategory.allCases) { c in
                        let on = draft.interests.contains(c)
                        Button {
                            if on { draft.interests.removeAll { $0 == c } } else { draft.interests.append(c) }
                        } label: {
                            Label(c.rawValue, systemImage: c.icon).font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(on ? c.color : Color.gray.opacity(0.12), in: Capsule())
                                .foregroundStyle(on ? Color.white : Color.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("관심 반경") {
                Picker("반경", selection: $draft.radiusKm) {
                    ForEach([1, 3, 5, 10], id: \.self) { Text("\($0)km").tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { store.profile = draft; dismiss() }.bold()
            }
        }
        .onAppear { if !loaded { draft = store.profile; loaded = true } }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data),
                   let small = ui.jpegData(compressionQuality: 0.6) {          // 저장 용량 줄이기
                    draft.photo = small
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
