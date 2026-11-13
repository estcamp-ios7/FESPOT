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
                    Text("마음에 드는 행사에 하트를 누르면\n 이곳에서 모아볼 수 있어요.").foregroundStyle(Color.inkSub)
                }
                .padding(.top, 80)
                .multilineTextAlignment(.center)
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
