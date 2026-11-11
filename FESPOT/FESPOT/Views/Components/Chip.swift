//
//  Chip.swift
//  FESPOT
//
//  동그란 캡슐 모양 선택 버튼 (카테고리 칩 · 지역 칩에서 같이 씀)
//
//  · on 이 true 면 까만 배경(선택됨), false 면 흰 배경
//

import SwiftUI

struct Chip: View {
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.subheadline.bold())
                .padding(.horizontal, 14).frame(height: 36)
                .background(on ? Color.ink : Color.card, in: Capsule())
                .foregroundStyle(on ? Color.onInk : Color.ink)
                .overlay(Capsule().stroke(on ? Color.clear : Color.gray.opacity(0.25)))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}
