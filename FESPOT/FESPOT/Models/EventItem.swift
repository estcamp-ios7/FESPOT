//
//  EventItem.swift
//  FESPOT
//
//  행사 1개를 나타내는 데이터 모양 (앱에서 가장 중요한 타입!)
//
//  · TourAPI · 한국문화정보원 · 예시 데이터 모두 결국 이 EventItem 모양으로 바뀌어서 화면에 보여요
//  · let = 한 번 정하면 안 바뀌는 값 / var = 나중에 바뀔 수 있는 값
//  · 아래쪽 '계산 속성'(var xxx: String { ... })은 저장하지 않고 필요할 때마다 계산해서 돌려줘요
//

import Foundation
import CoreLocation

struct EventItem: Identifiable, Hashable {
    let id: String                 // 찜 저장용 고정 아이디
    let title: String
    let category: EventCategory
    var region: String             // 포스터에서 찾으면 바로잡을 수 있게 var
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
    var startDate: Date? = nil     // D-day 계산용 (TourAPI)
    var endDate: Date? = nil
    var showTime: String? = nil    // 공연 시간 안내 (있으면 운영 시간에 표시)
    var extraImageURLs: [String] = []   // 처음부터 받은 소개 이미지
    var city: String = ""          // 시·군·구 짧은 이름 예: "남원", "양평", "종로" (없으면 빈칸)

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    func isOpen(on day: Day, hour: Int) -> Bool { days.contains(day) && (allDay || (hour >= startHour && hour < endHour)) }
    // 짧은 행사 기간 (카드용): 실데이터 "10.23 – 11.14", 예시는 기간 문구 그대로
    var dateRange: String { allDay ? (startNote == untilNote ? startNote : "\(startNote) – \(untilNote)") : period }
    // 카드 윗줄: "남원 · 공연 · 음악" (시·군 모르면 "전북 · 공연 · 음악")
    var placeTypeLabel: String { "\(city.isEmpty ? region : city) · \(typeLabel)" }
    var typeLabel: String { subType.isEmpty || subType == category.rawValue ? category.rawValue : "\(category.rawValue) · \(subType)" }
    var contentId: String? { id.hasPrefix("tour-") ? String(id.dropFirst(5)) : nil }   // TourAPI 행사만
    var hoursText: String { allDay ? (showTime ?? "행사 기간 중 (세부 시간은 주최 측 확인)") : "\(startHour):00 – \(endHour):00" }
}


// 이 행사가 속한 모든 카테고리: 대표 카테고리 + 제목·세부유형 키워드로 찾은 것 + 제목에 "축제"류가 있으면 축제
// 예) "진안고원 김치보쌈축제" → [먹거리, 축제]  /  "한강 달빛 야시장" → [플리마켓, 야경]
extension EventItem {
    var tags: Set<EventCategory> {
        var t: Set<EventCategory> = [category]
        let text = title + " " + subType
        for (c, words) in TourAPI.keywords where words.contains(where: { text.contains($0) }) { t.insert(c) }
        if ["축제", "페스티벌", "페스타", "festival", "Festival", "FESTIVAL"].contains(where: { title.contains($0) }) {
            t.insert(.festival)
        }
        return t
    }
}
