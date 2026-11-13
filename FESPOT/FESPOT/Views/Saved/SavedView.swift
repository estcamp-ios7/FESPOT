//
//  SavedView.swift
//  FESPOT
//
//  ③ 찜 탭 — ♡ 누른 행사만 모아서 포스터 격자로 보여줘요
//
//  · 찜 목록(store.saved)에는 행사 id만 저장돼 있고, 여기서 전체 행사 중 그 id인 것만 골라내요
//  · 찜한 게 없으면 [행사 둘러보기] 버튼 → 누르면 추천 탭으로 (탭 바꾸기는 ContentView 가 onBrowse 로 넘겨줘요)
//

import SwiftUI

struct SavedView: View {
    @EnvironmentObject var store: EventStore
    var onBrowse: () -> Void = {}                  // [행사 둘러보기]를 눌렀을 때 할 일 (추천 탭으로 이동)

    var body: some View {
        let list = store.events.filter { store.saved.contains($0.id) }
        Group {
            if list.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 20) {
                        ForEach(list) { savedEvent in
                            NavigationLink(value: savedEvent) { PosterCard(event: savedEvent) }.buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.paper)
        .navigationTitle("찜한 행사")
    }

    // 찜한 행사가 없을 때: 하트 · 안내 문구 · [행사 둘러보기] 를 화면 한가운데에
    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart").font(.largeTitle).foregroundStyle(Color.inkSub)
            Text("마음에 드는 행사에 하트를 누르면\n 이곳에서 모아볼 수 있어요.").foregroundStyle(Color.inkSub)
            Button { onBrowse() } label: {
                Text("행사 둘러보기")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 30).frame(height: 44)
                    .background(Color.coral, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 25)
        }
        .multilineTextAlignment(.center)
                .padding(.bottom, 100)          // ← 추가: 숫자를 키울수록 더 위로 (120이면 약 60pt 올라감)
                .frame(maxWidth: .infinity, maxHeight: .infinity)      // 남은 공간 전체를 쓰고 그 가운데에 놓기
    }
}

#Preview("찜 없음") {
    let store = EventStore()
    store.saved = []
    return NavigationStack { SavedView() }
        .environmentObject(store)
}
