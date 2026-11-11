//
//  BadgeView.swift
//  FESPOT
//
//  배지(EventBadge)를 실제로 그려주는 작은 캡슐 부품
//

import SwiftUI

struct BadgeView: View {
    let badge: EventBadge
    var body: some View {
        HStack(spacing: 4) {
            if badge.text.contains("마감") { Image(systemName: "alarm.fill").font(.caption2) }
            Text(badge.text).font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(badge.color, in: Capsule())
    }
}
