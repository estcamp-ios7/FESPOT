//
//  CultureService.swift
//  지금여기 — 한국문화정보원 '한눈에보는문화정보' 공연·전시 불러오기 (별도 파일, KOPIS 대신)
//
//  사용법: Xcode → File → New → File → Swift File → 이름 CultureService → 이 내용 붙여넣기
//  키:    공공데이터포털에서 '한국문화정보원_한눈에보는문화정보조회서비스' 활용신청만 하면
//         TourAPI에 쓰던 같은 인증키(TOUR_API_KEY)로 동작해요 (계정당 키 하나)
//         다른 키를 쓰고 싶으면 Info에 CULTURE_API_KEY 를 따로 넣으면 그게 우선이에요
//  ※ 응답이 XML이라 아래 작은 XML 해석기로 풀어서 앱의 EventItem 모양으로 바꿔요
//  ※ EventItem, TourAPI.daysOpen / regionName / keywordCategory 는 메인 파일에 있는 걸 그대로 씀
//

import Foundation

enum Culture {
    // 공공데이터포털 게이트웨이 주소 (예전 문화포털 주소 /nopenapi/rest/… 는 "서비스 없음(12)" 오류)
    static let base = "https://apis.data.go.kr/B553457/cultureinfo"

    static var lastStatus = "아직 안 불러옴"          // 내 정보 화면에 보여줄 진단 문구

    static var serviceKey: String? {
        if let k = Bundle.main.object(forInfoDictionaryKey: "CULTURE_API_KEY") as? String, !k.isEmpty { return k }
        return TourAPI.serviceKey
    }

    static func makeURL(_ path: String, _ params: [String], key: String) -> URL? {
        let enc = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return URL(string: "\(base)/\(path)?" + (params + ["serviceKey=\(enc)"]).joined(separator: "&"))
    }

    // =====================================================
    // ① 목록: 오늘 ~ 30일 뒤 열리는 공연·전시 (기간별 조회)
    // =====================================================
    static func fetchEvents(rows: Int = 100) async -> [EventItem] {
        guard let key = serviceKey else { lastStatus = "키 없음 (TOUR_API_KEY / CULTURE_API_KEY)"; return [] }
        let ymd = DateFormatter(); ymd.dateFormat = "yyyyMMdd"
        let from = Date()
        let to = Calendar.current.date(byAdding: .day, value: 30, to: from)!
        // 페이지 크기 이름이 numOfrows (r 소문자) 인 점 주의
        guard let url = makeURL("period2", ["from=\(ymd.string(from: from))", "to=\(ymd.string(from: to))",
                                            "PageNo=1", "numOfrows=\(rows)"], key: key) else { return [] }
        guard let data = await XMLRecords.download(url) else { lastStatus = "인터넷 연결 실패"; return [] }
        let list = XMLRecords.parse(data, tags: ["perforList", "item"])
        let events = list.compactMap(makeEvent)
        if list.isEmpty {
            // 받은 게 없으면 서버가 보낸 오류 문구를 그대로 보여주기 (예: 활용신청 안 됨)
            let raw = String(data: data, encoding: .utf8) ?? ""
            let msg = ["returnAuthMsg", "errMsg", "resultMsg", "returnReasonCode"].compactMap { tag -> String? in
                guard let r1 = raw.range(of: "<\(tag)>"), let r2 = raw.range(of: "</\(tag)>"), r1.upperBound <= r2.lowerBound else { return nil }
                return String(raw[r1.upperBound..<r2.lowerBound])
            }.joined(separator: " / ")
            lastStatus = "받은 공연·전시 0개" + (msg.isEmpty ? " (응답 앞부분: \(raw.prefix(80)))" : " (\(msg))")
        } else {
            let mapped = events.filter { $0.latitude != 0 }.count
            lastStatus = "목록 \(list.count)개 받음 → 앱에 \(events.count)개 (지도 위치 있는 것 \(mapped)개)"
        }
        return events
    }

    private static func makeEvent(_ r: [String: String]) -> EventItem? {
        guard let seq = pick(r, ["seq"]), let title = pick(r, ["title"])?.htmlDecoded,
              let sd = parseDate(pick(r, ["startDate", "startdate"])),
              let ed = parseDate(pick(r, ["endDate", "enddate"])),
              ed >= Calendar.current.startOfDay(for: Date()) else { return nil }
        // 좌표가 없어도 버리지 않기 → 추천 탭엔 보이고, 지도에서만 빠짐 (위도 0 = 위치 없음)
        let coord = coordinate(r) ?? (lat: 0, lon: 0)

        let realm = pick(r, ["realmName", "realmname"]) ?? ""
        let kind = classify(realm: realm, title: title)
        let place = pick(r, ["place"])?.htmlDecoded ?? "장소 정보 없음"
        let area = pick(r, ["area", "sigungu"]) ?? place
        let full = DateFormatter(); full.dateFormat = "yyyy.MM.dd"
        let short = DateFormatter(); short.dateFormat = "M.d"

        return EventItem(
            id: "culture-\(seq)", title: title, category: kind.0,
            region: TourAPI.regionName(area), place: place,
            latitude: coord.lat, longitude: coord.lon,
            days: TourAPI.daysOpen(from: sd, to: ed),
            startHour: 10, endHour: 22,
            period: "\(full.string(from: sd)) – \(full.string(from: ed))",
            price: "상세 정보 확인",
            posterURL: https(pick(r, ["thumbnail", "imgUrl"])),
            allDay: true, startNote: short.string(from: sd), untilNote: short.string(from: ed),
            subType: kind.1, startDate: sd, endDate: ed)
    }

    // =====================================================
    // ② 상세: 가격 · 문의 전화 · 홈페이지 · 소개 · 큰 이미지 · 주소 (상세 화면 열 때만 요청)
    // =====================================================
    struct Detail {
        var price: String?
        var phone: String?
        var link: URL?
        var contents: String?
        var image: String?
        var address: String?
    }

    static func fetchDetail(seq: String, key: String) async -> Detail? {
        // 상세 주소 이름이 버전마다 달라서 두 가지를 차례로 시도
        for path in ["detail2"] {
            guard let url = makeURL(path, ["seq=\(seq)"], key: key) else { continue }
            if let r = await XMLRecords.fetch(url, tags: ["perforInfo", "item"]).first {
                return Detail(
                    price: TourAPI.cleanText(pick(r, ["price"])),
                    phone: pick(r, ["phone"]),
                    link: TourAPI.firstLink(pick(r, ["url", "placeUrl"])),
                    contents: TourAPI.cleanText(pick(r, ["contents1", "contents2"])),
                    image: https(pick(r, ["imgUrl", "thumbnail"])),
                    address: pick(r, ["placeAddr", "placeaddr"]))
            }
        }
        return nil
    }

    // =====================================================
    // 도우미들
    // =====================================================

    // 분야 이름으로 분류: 미술·사진 → 전시, 연극·음악·무용·국악 → 공연, 나머지는 제목 키워드
    // 분야(realmName) 예: "미술/전시" · "교육/체험" · "음악/콘서트" · "행사/축제" …
    static func classify(realm: String, title: String) -> (EventCategory, String) {
        let exhibit = ["미술", "전시", "사진", "공예", "디자인", "건축"]
        let experience = ["체험", "교육", "클래스", "강좌", "워크숍"]
        let concert = ["연극", "음악", "무용", "국악", "뮤지컬", "클래식", "오페라", "콘서트", "공연"]
        let cat: EventCategory?
        if exhibit.contains(where: { realm.contains($0) }) { cat = .exhibit }
        else if experience.contains(where: { realm.contains($0) }) { cat = .experience }   // ← 교육/체험 → 체험
        else if concert.contains(where: { realm.contains($0) }) { cat = .concert }
        else { cat = nil }
        if let c = cat { return (c, subName(realm, c)) }
        if let k = TourAPI.keywordCategory(title) { return k }               // 행사/축제·기타 → 제목으로 세분화
        return (.festival, subName(realm, .festival))
    }
    // "교육/체험" → 카테고리(체험)와 겹치지 않는 쪽 "교육"만 세부 유형으로
    static func subName(_ realm: String, _ c: EventCategory) -> String {
        let parts = realm.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.first { $0 != c.rawValue && !$0.isEmpty } ?? ""
    }

    // 여러 후보 이름 중 값이 있는 첫 번째
    static func pick(_ r: [String: String], _ keys: [String]) -> String? {
        for k in keys { if let v = r[k], !v.isEmpty { return v } }
        return nil
    }

    // "20261020" · "2026.10.20" · "2026-10-20" 모두 읽기
    static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let digits = s.filter { $0.isNumber }
        guard digits.count >= 8 else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return f.date(from: String(digits.prefix(8)))
    }

    // 좌표: 이름(gpsX/gpsY)에 기대지 않고 숫자 범위로 위도·경도 구분 (한국: 위도 33~39, 경도 124~132)
    static func coordinate(_ r: [String: String]) -> (lat: Double, lon: Double)? {
        let nums = ["gpsX", "gpsY", "gpsx", "gpsy"].compactMap { r[$0] }.compactMap(Double.init)
        guard let lat = nums.first(where: { (33...39).contains($0) }),
              let lon = nums.first(where: { (124...132).contains($0) }) else { return nil }
        return (lat, lon)
    }

    static func https(_ s: String?) -> String? { s?.replacingOccurrences(of: "http://", with: "https://") }
}

// =========================================================
// 아주 작은 XML 해석기: 지정한 태그 하나 = [이름: 값] 사전 하나
// =========================================================
enum XMLRecords {
    static func download(_ url: URL) async -> Data? {
        (try? await URLSession.shared.data(from: url))?.0
    }
    static func parse(_ data: Data, tags: Set<String>) -> [[String: String]] {
        let collector = Collector(tags: tags)
        let parser = XMLParser(data: data)
        parser.delegate = collector
        parser.parse()
        return collector.records
    }
    static func fetch(_ url: URL, tags: Set<String>) async -> [[String: String]] {
        guard let data = await download(url) else { return [] }
        return parse(data, tags: tags)
    }

    final class Collector: NSObject, XMLParserDelegate {
        let tags: Set<String>
        var records: [[String: String]] = []
        private var current: [String: String]? = nil
        private var currentTag = ""
        private var text = ""

        init(tags: Set<String>) { self.tags = tags }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            if current == nil, tags.contains(name) { current = [:]; currentTag = name }
            text = ""
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            text += String(data: CDATABlock, encoding: .utf8) ?? ""
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            if current != nil, name == currentTag {
                records.append(current!)
                current = nil
            } else if current != nil {
                let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !v.isEmpty && current?[name] == nil { current?[name] = v }
            }
            text = ""
        }
    }
}
