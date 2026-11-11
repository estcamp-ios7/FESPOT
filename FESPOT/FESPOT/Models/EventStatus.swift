//
//  EventStatus.swift
//  FESPOT
//
//  '지금 이 순간' 행사가 어떤 상태인지 계산 — 진행 중 / 곧 시작 / 오늘 종료 / 휴무
//
//  · status(of:nowMinutes:) 에 행사와 '지금 시각(자정부터 몇 분)'을 넣으면 상태 문구·색이 나와요
//  · nowMinutes(): 지금이 하루 중 몇 분째인지 (예: 오후 1시 30분 → 810)
//

import SwiftUI

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
