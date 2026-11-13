//
//  Colors.swift
//  FESPOT
//
//  앱 전체에서 쓰는 색 모음 (라이트 · 다크 모드 자동 전환)
//
//  · Color(rgb: 0xFF6A3D) 처럼 16진수 색 코드(디자인 툴의 #FF6A3D)로 색을 만들 수 있게 해줘요
//  · Color(light: 0x..., dark: 0x...) 는 아이폰이 다크 모드면 dark 색, 아니면 light 색으로 알아서 바뀌어요
//  · 쓰는 법: .foregroundStyle(Color.ink)  /  .background(Color.paper)
//
//  ⚠️ 다크 모드 규칙 (새 화면 만들 때 꼭 지켜주세요)
//  · 카드·검색창 배경은 .white 대신 Color.card
//  · 진한 버튼(배경 Color.ink) 위 글자는 .white 대신 Color.onInk
//  · 사진·카테고리 색 위의 글자처럼 '항상 흰색'이어야 하는 곳만 .white 를 그대로 써요
//

import SwiftUI
import UIKit

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }

    // 라이트 / 다크 모드에서 다른 색
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    // ---------- 글자 ----------
    static let ink = Color(light: 0x14161F, dark: 0xF2F3F7)        // 기본 글자 (다크: 거의 흰색)
    static let inkSub = Color(light: 0x5B6170, dark: 0xA3A9B8)     // 보조 글자 (회색)
    static let onInk = Color(light: 0xFFFFFF, dark: 0x14161F)      // Color.ink 배경 버튼 위의 글자

    // ---------- 배경 ----------
    static let paper = Color(light: 0xF6F6F3, dark: 0x0E0F14)      // 화면 전체 배경
    static let card = Color(light: 0xFFFFFF, dark: 0x1D1F27)       // 카드 · 검색창 · 칩 배경

    // ---------- 포인트 색 ----------
    static let coral = Color(rgb: 0xFF6A3D)
    static let liveGreen = Color(rgb: 0x1E9E5A)                     // 진행 중 초록 점
    static let liveText = Color(light: 0x12723F, dark: 0x4FD18B)   // "진행 중" 글자
    static let liveBg = Color(light: 0xE7F6EE, dark: 0x163A27)     // '열린 곳만' 켜졌을 때 배경
    static let soonText = Color(light: 0x2A55B8, dark: 0x8AADFF)   // "곧 시작" 글자
    static let endText = Color(light: 0xB4401C, dark: 0xFF8A65)    // "오늘 종료" 글자
    static let badgeDark = Color(rgb: 0x14161F)                     // 포스터 위 "D-5" 배지 (항상 진한 색)
}
