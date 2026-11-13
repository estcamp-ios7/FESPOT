//
//  EventStore.swift
//  FESPOT
//
//  앱 전체가 함께 쓰는 '행사 창고' — 행사 목록 · 찜 목록 · 내 프로필
//
//  · ObservableObject + @Published: 값이 바뀌면 그 값을 쓰는 화면이 자동으로 다시 그려져요
//  · didSet { ... }: 값이 바뀔 때마다 실행 → 여기서 UserDefaults(기기 저장소)에 저장해서 앱을 껐다 켜도 남아요
//  · loadFestivals(): TourAPI → 한국문화정보원 순서로 실제 행사 불러오기
//  · fillCities():    주소가 없는 행사의 시·군 이름 채우기 (PlaceFinder.swift 이용)
//

import Foundation
import Combine

final class EventStore: ObservableObject {
    // ---------- 찜 · 프로필 (기기에 저장) ----------
    // 찜한 행사의 id 모음. Set = 중복 없는 묶음이라 같은 행사를 두 번 넣어도 하나만 남아요
    @Published var saved: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "savedEvents") ?? []) {
        didSet { UserDefaults.standard.set(Array(saved), forKey: "savedEvents") }
    }
    // 처음 만들 때 저장된 프로필이 있으면 꺼내고(JSON → Profile), 없으면 빈 프로필로 시작
    @Published var profile: Profile = {
        if let savedData = UserDefaults.standard.data(forKey: "profile"), let savedProfile = try? JSONDecoder().decode(Profile.self, from: savedData) { return savedProfile }
        return Profile()
    }() {
        didSet { if let encodedData = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(encodedData, forKey: "profile") } }
    }
    // ♡ 버튼: 찜돼 있으면 빼고, 아니면 넣기
    func toggleSave(_ event: EventItem) {
        if saved.contains(event.id) { saved.remove(event.id) } else { saved.insert(event.id) }
    }

    // 행사 목록: 처음엔 예시, TourAPI 성공하면 실데이터로 교체
    // ---------- 행사 목록 ----------
    @Published var events: [EventItem] = sampleEvents
    @Published var dataNote = "예시 데이터"
    @Published var cultureNote = "아직 안 불러옴"      // 한국문화정보원 진단 문구
    @Published var loading = false

    // @MainActor: 화면에 보이는 값(@Published)을 바꾸니까 메인 스레드에서 실행하라는 표시
    // async: 인터넷을 기다리는 동안 앱이 멈추지 않게 '비동기'로 실행
    @MainActor
    func loadFestivals() async {
        guard !loading else { return }                  // 이미 불러오는 중이면 또 시작하지 않기
        loading = true
        defer { loading = false }
        if let key = TourAPI.serviceKey {
            do {
                let real = try await TourAPI.fetchFestivals(serviceKey: key)
                if real.isEmpty { dataNote = "예시 데이터 (불러온 행사 0개)" }
                else { events = real; dataNote = "TourAPI 실데이터 \(real.count)개" }
            } catch {
                dataNote = "예시 데이터 (불러오기 실패: \(error.localizedDescription))"
            }
        } else {
            dataNote = "예시 데이터 (TOUR_API_KEY 없음)"
        }
        // 공연·전시 더하기 (CultureService.swift · 한국문화정보원, 같은 공공데이터포털 키)
        let culture = await Culture.fetchEvents()
        cultureNote = Culture.lastStatus
        if !culture.isEmpty {
            let have = Set(events.map(\.id))
            events += culture.filter { !have.contains($0.id) }
            dataNote += " + 공연·전시 \(culture.count)개"
        }
        // 새로 올라온 행사 알림 (근처 · 관심) — Services/Notifier.swift
        await Notifier.checkNewEvents(events, profile: profile)
        await Notifier.removeOldDeadlineAlerts()
        await fillCities()
    }

    // 주소 없는 행사 → 장소 이름·제목 → 포스터 글자 순으로 시·군 찾기 (PlaceFinder.swift)
    @MainActor
    func fillCities() async {
        var cache = UserDefaults.standard.dictionary(forKey: "cityCache") as? [String: String] ?? [:]   // id → "서울|종로" / "-"(못 찾음)
        defer { UserDefaults.standard.set(cache, forKey: "cityCache") }

        for index in events.indices where events[index].city.isEmpty {
            let event = events[index]
            if let cachedValue = cache[event.id] { apply(cachedValue, at: index); continue }
            if let found = PlaceFinder.find(in: event.place + " " + event.title, region: event.region), !found.city.isEmpty {
                cache[event.id] = "\(found.region)|\(found.city)"; apply(cache[event.id]!, at: index)
            }
        }
        // 그래도 없으면 포스터 읽기 (한 번에 최대 40장, 결과는 저장)
        let targets = events.filter { $0.city.isEmpty && $0.posterURL != nil && cache[$0.id] == nil }.prefix(40)
        for event in targets {
            guard let posterURLString = event.posterURL, let url = URL(string: posterURLString) else { continue }
            let text = await PlaceFinder.readPoster(url) ?? ""
            if let found = PlaceFinder.find(in: text, region: event.region) {
                cache[event.id] = "\(found.region)|\(found.city)"
                if let index = events.firstIndex(where: { $0.id == event.id }) { apply(cache[event.id]!, at: index) }
            } else {
                cache[event.id] = "-"
            }
        }
    }

    // 저장해 둔 "서울|종로" 문자열을 잘라서 index번째 행사의 지역 · 시·군에 넣기
    private func apply(_ cachedValue: String, at index: Int) {
        let parts = cachedValue.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { return }
        if events[index].region == "기타" { events[index].region = parts[0] }       // 지역 모르던 행사만 지역도 고침
        if events[index].region == parts[0], !parts[1].isEmpty { events[index].city = parts[1] }
    }
}
