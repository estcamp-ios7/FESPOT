//
//
//  ContentView.swift
//  FESPOT
//
//  앱의 '뼈대' 화면 — 하단 탭 4개(지도 · 추천 · 찜 · 내 정보)를 묶는 곳
//
//  · 앱이 켜지면 FESPOTApp → ContentView 순서로 화면이 만들어져요
//  · EventStore(행사 창고)와 LocationManager(내 위치)를 여기서 딱 한 번 만들고
//    .environmentObject(...) 로 아래 모든 화면에 나눠줘요
//    → 다른 화면에서는 @EnvironmentObject 로 꺼내 쓰기만 하면 돼요
//

import SwiftUI

// 하단 탭 4개의 이름표 — 지금 어떤 탭이 선택됐는지 tab 변수에 이 값이 들어가요
enum AppTab: Hashable { case map, picks, saved, me }

struct ContentView: View {
    // @StateObject: 이 화면이 '주인'이 되어 객체를 만들고 계속 들고 있어요 (화면이 다시 그려져도 새로 안 만듦)
    @StateObject private var store = EventStore()
    @StateObject private var location = LocationManager()
    // @State: 이 화면 안에서만 쓰는 값 — 바뀌면 화면이 자동으로 다시 그려져요
    @State private var tab: AppTab = .map
    // @AppStorage: UserDefaults(기기 저장소)에 바로 저장되는 값 — 앱을 껐다 켜도 남아요
    @AppStorage("didOnboard") private var didOnboard = false     // 첫 실행 질문을 봤는지

    var body: some View {
        // 탭마다 NavigationStack 으로 감싸야 그 탭 안에서 '다음 화면으로 이동'이 돼요
        // navigationDestination: NavigationLink(value: 행사) 를 누르면 어떤 화면을 띄울지 정해요
        TabView(selection: $tab) {
            NavigationStack { MapHomeView() }
                .tabItem { Label("지도", systemImage: "map") }.tag(AppTab.map)
            NavigationStack { RegionPicksView().navigationDestination(for: EventItem.self) { EventDetailView(event: $0) } }
                .tabItem { Label("추천", systemImage: "square.grid.2x2") }.tag(AppTab.picks)
            // 찜 탭이 비었을 때 [행사 둘러보기] → 추천 탭으로
            NavigationStack { SavedView(onBrowse: { tab = .picks }).navigationDestination(for: EventItem.self) { EventDetailView(event: $0) } }
                .tabItem { Label("찜", systemImage: "heart") }.tag(AppTab.saved)
            NavigationStack { MeView() }
                .tabItem { Label("내 정보", systemImage: "person") }.tag(AppTab.me)
        }
        .tint(Color.ink)
        // 아래 모든 화면에 store · location 을 나눠주기 (받는 쪽은 @EnvironmentObject 로 꺼내 씀)
        .environmentObject(store)
        .environmentObject(location)
        .onAppear { location.request() }                 // 화면이 뜨면 위치 권한 요청
        .task { await store.loadFestivals() }            // 화면이 뜨면 인터넷에서 행사 불러오기 (await = 끝날 때까지 기다림)
        // 첫 실행이면 관심 카테고리 질문 화면 (OnboardingView.swift)
        .fullScreenCover(isPresented: Binding(get: { !didOnboard }, set: { _ in })) {
            OnboardingView { didOnboard = true }
                .environmentObject(store)
        }
    }
}

#Preview {
    ContentView()
}
