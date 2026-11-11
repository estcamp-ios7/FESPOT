//
//  PosterCard.swift
//  FESPOT
//
//  포스터 카드 1장 (추천 탭 · 찜 탭 격자에서 씀) — 포스터 + 배지 + ♡ + 제목 + 기간
//

import SwiftUI

struct PosterCard: View {
    @EnvironmentObject var store: EventStore
    let event: EventItem
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                // 빈 3:4 틀을 먼저 만들고 → 그 위에 사진을 꽉 채운 뒤 → 틀 밖은 잘라냄
                Color.clear
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay { PosterImage(event: event) }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))   // 터치 영역도 포스터 틀 크기로 딱 맞춤
                if let b = event.badge {
                    BadgeView(badge: b).padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { store.toggleSave(event) } label: {
                    Image(systemName: store.saved.contains(event.id) ? "heart.fill" : "heart")
                        .font(.subheadline.bold())
                        .foregroundStyle(store.saved.contains(event.id) ? Color.coral : Color.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.25), in: Circle())
                }
                .accessibilityLabel("찜하기")
                .padding(6)
            }
            Text(event.placeTypeLabel).font(.caption.bold()).foregroundStyle(event.category.color)
                .lineLimit(1)
            Text(event.title).font(.subheadline.bold()).foregroundStyle(Color.ink)
                .lineLimit(1).truncationMode(.tail)          // 길면 "…"
            Label(event.dateRange, systemImage: "calendar")          // 주소 대신 행사 기간
                .font(.caption).foregroundStyle(Color.inkSub)
                .labelStyle(.titleAndIcon)
                .lineLimit(1).truncationMode(.tail)
        }
    }
}
