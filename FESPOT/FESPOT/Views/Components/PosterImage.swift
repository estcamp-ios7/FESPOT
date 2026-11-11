//
//  PosterImage.swift
//  FESPOT
//
//  포스터 이미지 — 사진 주소가 있으면 인터넷에서 받아 보여주고, 없으면 카테고리 색으로 포스터를 자동으로 그려요
//
//  · AsyncImage: 인터넷 사진을 받아오는 동안 placeholder(대신 보여줄 화면)를 먼저 보여줘요
//

import SwiftUI

// 포스터: 주소가 있으면 진짜 이미지, 없으면 자동으로 만든 포스터
struct PosterImage: View {
    let event: EventItem
    var body: some View {
        if let s = event.posterURL, let url = URL(string: s) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)        // 가로로 긴 사진이 틀 밖으로 삐져나와 옆 카드 터치를 가로채지 않게
            } placeholder: { generated }
        } else {
            generated
        }
    }
    var generated: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [event.category.color, event.category.color.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            Image(systemName: event.category.icon)
                .font(.system(size: 90, weight: .bold))
                .foregroundStyle(.white.opacity(0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
                .rotationEffect(.degrees(-8))
            VStack(alignment: .leading, spacing: 4) {
                Text(event.region.uppercased()).font(.caption2.bold()).foregroundStyle(.white.opacity(0.85))
                Text(event.title).font(.system(size: 20, weight: .heavy)).foregroundStyle(.white).lineLimit(2)
                Text(event.allDay ? "~ \(event.untilNote)" : "\(event.startHour):00 – \(event.endHour):00").font(.caption.bold()).foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
        }
    }
}
