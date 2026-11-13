//
//  Notifier.swift
//  FESPOT
//
//  행사 알림 2종류 — 서버 없이 '기기 안에서' 보내는 로컬 알림이에요
//
//  · [근처 행사 알림] 내 주변(관심 반경 안)에 새 행사가 올라오면
//  · [관심 행사 알림] 내 관심 카테고리의 새 행사가 올라오면
//
//  '새 행사'는 어떻게 아나요?
//  → 행사를 불러올 때마다 본 적 있는 행사 id를 기기에 저장해 두고, 다음에 처음 보는 id가 나오면 '새 행사'
//  → 앱을 처음 켰을 땐 전부 '본 것'으로만 저장하고 알림은 안 보내요 (한꺼번에 수백 개 알림 방지)
//  → 예시 데이터(발표용)는 알림 대상이 아니에요
//
//  켜기/끄기 설정은 @AppStorage 키(notifyNearby · notifyInterest)로 저장 → MeView 에서 바꿔요
//

import Foundation
import CoreLocation
import UserNotifications

enum Notifier {
    // ---------- 설정 키 (MeView 의 @AppStorage 와 같은 이름) ----------
    enum Kind: String, CaseIterable, Identifiable {
        case nearby = "notifyNearby", interest = "notifyInterest"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .nearby: return "근처 행사 알림"
            case .interest: return "관심 행사 알림"
            }
        }
        var detail: String {
            switch self {
            case .nearby: return "사용자 위치 근처에 새 행사가 올라오면 알려드려요"
            case .interest: return "관심 카테고리의 새 행사가 올라오면 알려드려요"
            }
        }
        var icon: String {
            switch self {
            case .nearby: return "location.circle.fill"
            case .interest: return "heart.circle.fill"
            }
        }
        // 켜져 있나? (한 번도 안 바꿨으면 기본값 = 켜짐)
        var isOn: Bool { UserDefaults.standard.object(forKey: rawValue) as? Bool ?? true }
    }

    static let center = UNUserNotificationCenter.current()
    private static let seenKey = "notifiedSeenIDs"          // 본 적 있는 행사 id

    // 알림 권한 묻기 (이미 정했으면 바로 결과만 돌려줘요)
    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // 지금 알림 권한 상태 (설정에서 꺼 두면 .denied)
    static func permissionDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    // =====================================================
    // ① 새 행사 확인 → 근처 · 관심 알림
    // =====================================================
    static func checkNewEvents(_ events: [EventItem], profile: Profile) async {
        let real = events.filter { $0.id.hasPrefix("tour-") || $0.id.hasPrefix("culture-") }
        guard !real.isEmpty else { return }

        let saved = UserDefaults.standard.stringArray(forKey: seenKey)
        var seen = Set(saved ?? [])
        let fresh = real.filter { !seen.contains($0.id) }
        seen.formUnion(real.map(\.id))
        UserDefaults.standard.set(Array(seen.suffix(3000)), forKey: seenKey)   // 너무 커지지 않게 최근 것만

        guard saved != nil, !fresh.isEmpty else { return }       // 처음 실행이면 저장만 하고 끝
        guard Kind.nearby.isOn || Kind.interest.isOn, await requestPermission() else { return }

        // 근처: 내 위치에서 관심 반경 안 (위치를 모르면 내가 사는 시·도)
        if Kind.nearby.isOn {
            let myLocation = CLLocationManager().location?.coordinate        // 마지막으로 알려진 내 위치
            let radius = Double(profile.radiusKm) * 1000
            let near = fresh.filter { event in
                if let myLocation, event.latitude != 0 { return meters(myLocation, event.coordinate) <= radius }
                return event.region == profile.sido
            }
            if let first = near.min(by: { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }) {
                let month = first.startDate.map { Calendar.current.component(.month, from: $0) }
                    ?? Calendar.current.component(.month, from: Date())
                await send(id: "nearby-\(first.id)",
                           title: "[근처 행사 알림]",
                           body: "\(month)월 주최되는 새로운 행사가 올라왔습니다.\n\(summary(near))")
            }
        }

        // 관심: 내 관심 카테고리 중 새 행사가 가장 많은 것 하나로 묶어서
        if Kind.interest.isOn, !profile.interests.isEmpty {
            let hits = profile.interests
                .map { category in (category, fresh.filter { $0.tags.contains(category) }) }
                .filter { !$0.1.isEmpty }
                .max { $0.1.count < $1.1.count }
            if let (category, matches) = hits {
                await send(id: "interest-\(category.rawValue)-\(matches[0].id)",
                           title: "[관심 행사 알림]",
                           body: "\(category.rawValue) 관련 새로운 행사가 올라왔습니다.\n\(summary(matches))")
            }
        }
    }

    // "‘한강 야시장’ 외 3개"
    static func summary(_ list: [EventItem]) -> String {
        guard let first = list.first else { return "" }
        return list.count > 1 ? "‘\(first.title)’ 외 \(list.count - 1)개" : "‘\(first.title)’"
    }

    // =====================================================
    // ② 정리: 예전 버전에서 예약해 둔 '찜한 행사 마감 알림'이 남아 있으면 지우기
    // =====================================================
    static func removeOldDeadlineAlerts() async {
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("deadline-") }
        center.removePendingNotificationRequests(withIdentifiers: old)
    }

    // =====================================================
    // ③ 미리 보기: 켜 둔 알림 종류를 예시 내용으로 하나씩 보내기 (발표 · 테스트용)
    // =====================================================
    static func sendPreview(events: [EventItem], profile: Profile) async {
        guard await requestPermission() else { return }
        let sample = events.first
        let month = Calendar.current.component(.month, from: Date())
        let name = sample.map { "‘\($0.title)’" } ?? "‘한강 야시장’"
        let categoryName = profile.interests.first?.rawValue ?? EventCategory.festival.rawValue
        let items: [(Kind, String)] = [
            (.nearby, "\(month)월 주최되는 새로운 행사가 올라왔습니다.\n\(name)"),
            (.interest, "\(categoryName) 관련 새로운 행사가 올라왔습니다.\n\(name)")
        ]
        for (order, item) in items.enumerated() where item.0.isOn {
            await send(id: "preview-\(item.0.rawValue)", title: "[\(item.0.title)]", body: item.1,
                       trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(2 + order * 2), repeats: false))
        }
    }

    // 알림 하나 보내기 (trigger 를 안 주면 1초 뒤)
    static func send(id: String, title: String, body: String, trigger: UNNotificationTrigger? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let notificationTrigger = trigger ?? UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: notificationTrigger))
    }
}

// 앱을 보고 있는 중에도 알림 배너가 위에 뜨게 해주는 도우미 (기본은 앱이 켜져 있으면 안 뜸)
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
