//
//  EventPin.swift
//  FESPOT
//
//  지도 위 행사 핀 (카테고리 색 동그라미 + 아이콘, 열려 있으면 초록 점)
//

import SwiftUI

struct EventPin: View {
    let category: EventCategory
    let live: Bool
    var dimmed: Bool = false
    var highlighted: Bool = false
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: category.icon)
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(category.color, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            if live {
                Circle().fill(Color.liveGreen).frame(width: 13, height: 13)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
        .opacity(dimmed && !highlighted ? 0.55 : 1)
        .scaleEffect(highlighted ? 1.35 : (dimmed ? 0.85 : 1))
        .background(
            Circle().fill(category.color.opacity(highlighted ? 0.25 : 0))
                .frame(width: 70, height: 70)
        )
        .animation(.spring(response: 0.35), value: highlighted)
        .accessibilityLabel("\(category.rawValue)\(live ? ", 열려 있음" : "")")
    }
}
