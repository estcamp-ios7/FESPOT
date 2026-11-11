//
//  EventCategory.swift
//  FESPOT
//
//  행사 종류(카테고리) — 축제 · 공연 · 전시 · 플리마켓 · 먹거리 · 야경 · 체험
//
//  · enum = '정해진 선택지 몇 개 중 하나'를 표현하는 타입
//  · 카테고리마다 대표 색(color)과 아이콘(icon, SF Symbols 이름)을 갖고 있어요
//  · 카테고리 한 줄 설명(blurb)은 OnboardingView.swift 맨 아래에 있어요
//

import SwiftUI

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
