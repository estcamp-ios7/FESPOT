//
//  SavedView.swift
//  FESPOT
//
//  ③ 찜 탭 — ♡ 누른 행사만 모아서 포스터 격자로 보여줘요
//
//  · 찜 목록(store.saved)에는 행사 id만 저장돼 있고, 여기서 전체 행사 중 그 id인 것만 골라내요
//

import SwiftUI

struct SavedView: View {
    @EnvironmentObject var store: EventStore
    var body: some View {
        let list = store.events.filter { store.saved.contains($0.id) }
        ScrollView {
            if list.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart").font(.largeTitle).foregroundStyle(Color.inkSub)
                    Text("가장 먼저볼 관심 카테고리를 선택하세요").foregroundStyle(Color.inkSub)
                }
                .padding(.top, 80)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 20) {
                ForEach(list) { savedEvent in
                    NavigationLink(value: savedEvent) { PosterCard(event: savedEvent) }.buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color.paper)
        .navigationTitle("찜한 행사")
    }
}
