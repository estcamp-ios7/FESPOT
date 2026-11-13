//
//  EventBadge.swift
//  FESPOT
//
//  포스터 왼쪽 위에 붙는 작은 배지 — "D-5" · "진행 중" · "마감 D-2" · "오늘 마감"
//
//  · 배지를 그리는 화면 부품은 Views/Components/BadgeView.swift 에 있어요
//

import SwiftUI

// D-day · 마감 배지: 시작 전 "D-5" / 진행 중 "진행 중" / 3일 이내 마감 "마감 D-2" / 마지막 날 "오늘 마감"
struct EventBadge {
    let text: String
    let color: Color
}
extension EventItem {
    var badge: EventBadge? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = startDate, let end = endDate else {                       // 예시 데이터: 지금 열려 있으면만
            return status(of: self, nowMinutes: nowMinutes()).isLive ? EventBadge(text: "진행 중", color: .liveGreen) : nil
        }
        let startDay = calendar.startOfDay(for: start), endDay = calendar.startOfDay(for: end)
        if today < startDay {
            let daysUntilStart = calendar.dateComponents([.day], from: today, to: startDay).day ?? 0
            return EventBadge(text: daysUntilStart == 1 ? "내일 시작" : "D-\(daysUntilStart)", color: .badgeDark)
        }
        let left = calendar.dateComponents([.day], from: today, to: endDay).day ?? 0
        if left <= 0 { return EventBadge(text: "오늘 마감", color: Color(rgb: 0xE5383B)) }
        if left <= 3 { return EventBadge(text: "마감 D-\(left)", color: Color(rgb: 0xF0642A)) }
        return EventBadge(text: "진행 중", color: .liveGreen)
    }
}
