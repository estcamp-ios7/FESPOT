//
//  NearbyCard.swift
//  FESPOT
//
//  상세 화면 아래 '근처 행사'에 옆으로 나열되는 카드 1장
//

import SwiftUI
import CoreLocation

// 근처 행사 카드: 포스터 + 행사명 › + "카테고리 · 진행 여부 · 도보 거리"
struct NearbyCard: View {
    let event: EventItem
    let from: CLLocationCoordinate2D

    // 진행 여부를 짧게: "진행 중" / "12.11 시작" / "19시 시작" / "오늘 종료"
    var progress: (text: String, color: Color) {
        let st = status(of: event, nowMinutes: nowMinutes())
        if st.isLive { return ("진행 중", .liveText) }
        if event.allDay { return ("\(event.startNote) 시작", .soonText) }
        return (st.text, st.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(3/4, contentMode: .fit)
                .overlay { PosterImage(event: event) }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 6) {
                Text(event.title)
                    .font(.subheadline.bold()).foregroundStyle(Color.ink)
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")                     // 우측 화살표
                    .font(.subheadline.weight(.bold)).foregroundStyle(Color.ink)
            }
            HStack(spacing: 4) {
                Text(event.category.rawValue).foregroundStyle(event.category.color)
                Text("·").foregroundStyle(Color.inkSub)
                Text(progress.text).foregroundStyle(progress.color)
                Text("·").foregroundStyle(Color.inkSub)
                Text(distanceText(meters(from, event.coordinate))).foregroundStyle(Color.inkSub)
            }
            .font(.caption.bold())
            .lineLimit(1)
        }
        .frame(width: 170)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("탭하면 행사 정보로 이동")
    }
}
