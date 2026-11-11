//
//  Colors.swift
//  FESPOT
//
//  앱 전체에서 쓰는 색 모음
//
//  · Color(rgb: 0xFF6A3D) 처럼 16진수 색 코드(디자인 툴의 #FF6A3D)로 색을 만들 수 있게 해줘요
//  · 쓰는 법: .foregroundStyle(Color.ink)  /  .background(Color.paper)
//

import SwiftUI

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
