//
//  Day.swift
//  FESPOT
//
//  '언제' 필터에 쓰는 요일 선택지 — 오늘 · 내일 · 토요일 · 일요일
//

import Foundation

enum Day: String, CaseIterable, Identifiable, Hashable {
    case today = "오늘", tomorrow = "내일", sat = "토요일", sun = "일요일"
    var id: String { rawValue }
}
