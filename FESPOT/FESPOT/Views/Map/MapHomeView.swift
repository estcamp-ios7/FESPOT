//
//  MapHomeView.swift
//  FESPOT
//
//  ① 지도 탭 — 지도 위에 행사 핀 표시 · 검색 · 카테고리 칩 · '열린 곳만' 필터
//
//  · 핀을 누르면 행사 상세(EventDetailView)가 아래에서 올라와요
//  · shown: 지금 필터 조건에 맞는 행사만 골라낸 목록 (지도 핀 · 검색 결과 둘 다 이걸 씀)
//  · topBar: 화면 위쪽 검색창 + 칩 + 안내 문구 묶음
//

import SwiftUI
import MapKit

struct MapHomeView: View {
    @EnvironmentObject var store: EventStore
    @EnvironmentObject var location: LocationManager
    // 지도가 지금 보여주는 위치·확대 정도 (바꾸면 지도가 그쪽으로 이동)
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(center: defaultCenter, latitudinalMeters: 3500, longitudinalMeters: 3500))
    @State private var query = ""                        // 검색창에 친 글자
    @State private var picked: EventCategory? = nil      // nil = 전체
    @State private var openOnly = false                  // '열린 곳만' 켜짐?
    @State private var day: Day = .today
    @State private var hour: Int? = nil                  // nil = 지금 이 순간
    @State private var showTime = false
    @State private var selected: EventItem? = nil        // 누른 핀의 행사 (값이 생기면 상세 시트가 뜸)
    @State private var focusedID: String? = nil           // 검색으로 고른 행사 (핀 강조)
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showSearch = false                // true 면 꽉 찬 검색 화면(MapSearchView)이 열림
    @State private var notice: String? = nil              // 칩 누르면 잠깐 뜨는 안내 ("체험 8곳")
    @State private var noticeTask: Task<Void, Never>? = nil

    var timeLabel: String { hour == nil ? "\(day.rawValue) · 지금" : "\(day.rawValue) · \(hour!)시" }

    // 선택한 시간에 열려 있나?
    func isOpen(_ e: EventItem) -> Bool {
        if let h = hour { return e.isOpen(on: day, hour: h) }
        if day == .today { return status(of: e, nowMinutes: nowMinutes()).isLive }
        let h = Calendar.current.component(.hour, from: Date())
        return e.isOpen(on: day, hour: h)
    }
    func runsThatDay(_ e: EventItem) -> Bool { e.days.contains(day) }

    // 지도에 보여줄 행사 = 전체 행사에서 조건 4개를 차례로 걸러낸 것
    var shown: [EventItem] {
        store.events
            .filter { e in picked.map { e.tags.contains($0) } ?? true }   // 행사가 가진 카테고리 중 하나라도 맞으면
            .filter { query.isEmpty || matches($0, query) }
            .filter { $0.latitude != 0 }                       // 위치 없는 행사는 지도에서만 빼기
            .filter { !openOnly || isOpen($0) }
    }

    // 검색어에 걸리는지 (EventItem.matches 는 MapSearchView.swift 맨 아래에 있어요)
    func matches(_ e: EventItem, _ q: String) -> Bool { e.matches(q) }

    // 칩 선택 → 내 주변(10km)에 있으면 그것들, 없으면 전국 것들이 다 보이게 이동 + 개수 안내
    func showPicked() {
        let me = location.coordinate ?? defaultCenter
        guard let c = picked else {                                     // "전체" → 전국 행사가 전부 보이게 줌아웃
            let all = shown
            moveCamera(to: all)
            flash(all.isEmpty ? "행사가 없어요" : "전체 \(all.count)곳")
            return
        }
        let list = shown
        if list.isEmpty {
            let all = store.events.filter { $0.tags.contains(c) }
            flash(all.isEmpty ? "\(c.rawValue) 행사가 없어요"
                              : "\(c.rawValue) \(all.count)곳은 위치 정보가 없어요 · 추천 탭에서 볼 수 있어요")
            return
        }
        let near = list.filter { meters(me, $0.coordinate) < 10_000 }
        moveCamera(to: near.isEmpty ? list : near)
        flash(near.isEmpty ? "\(c.rawValue) \(list.count)곳 (전국)" : "내 주변 \(c.rawValue) \(near.count)곳")
    }
    func flash(_ text: String?) {
        noticeTask?.cancel()
        withAnimation { notice = text }
        guard text != nil else { return }
        noticeTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { withAnimation { notice = nil } }
        }
    }

    // 검색 결과 위치로 지도 이동: 1개면 그곳으로 확대, 여러 개면 전부 보이게
    func moveCamera(to list: [EventItem]) {
        guard !list.isEmpty else { return }
        if list.count == 1 {
            withAnimation(.easeInOut(duration: 0.6)) {
                position = .region(MKCoordinateRegion(center: list[0].coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
            }
            return
        }
        let lats = list.map(\.latitude), lons = list.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.02, (lats.max()! - lats.min()!) * 1.5),
                                    longitudeDelta: max(0.02, (lons.max()! - lons.min()!) * 1.5))
        withAnimation(.easeInOut(duration: 0.6)) { position = .region(MKCoordinateRegion(center: center, span: span)) }
    }

    var body: some View {
        // $position: '$'를 붙이면 값을 읽기만 하는 게 아니라 지도가 직접 바꿀 수도 있게 연결(Binding)돼요
        Map(position: $position) {
            UserAnnotation()
            ForEach(shown) { e in
                let open = isOpen(e)
                Annotation(e.title, coordinate: e.coordinate, anchor: .center) {
                    Button { selected = e } label: {
                        // 칩으로 고른 카테고리가 이 행사에 있으면 그 색·아이콘으로 표시
                        EventPin(category: picked.flatMap { e.tags.contains($0) ? $0 : nil } ?? e.category,
                                 live: open, dimmed: !open, highlighted: focusedID == e.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // 카테고리 칩을 누르면 그 행사들이 있는 곳으로 지도 이동 (화면 밖에 있어서 안 보이던 문제 해결)
        .onChange(of: picked) { _, _ in showPicked() }
        // 타자를 멈추고 0.6초 지나면 자동으로 결과 위치로 이동
        .onChange(of: query) { _, q in
            searchTask?.cancel()
            guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { return }   // 비워질 땐 핀 강조 유지 (결과 하나 고른 경우)
            focusedID = nil                                                          // 새 검색어 → 이전 강조 지우기
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                if !Task.isCancelled { moveCamera(to: shown) }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
        .safeAreaInset(edge: .top) { topBar }
        .toolbar(.hidden, for: .navigationBar)
        // 핀 탭 → 바로 상세 (아래에서 올라오는 시트)
        .sheet(item: $selected) { e in
            NavigationStack {
                EventDetailView(event: e)
                    .navigationDestination(for: EventItem.self) { EventDetailView(event: $0) }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("닫기") { selected = nil }
                        }
                    }
            }
            .presentationDetents([.large])              // 처음부터 화면 가득 (풀시트)
            .presentationDragIndicator(.visible)
            .environmentObject(store)
            .environmentObject(location)
        }
        // 검색창 탭 → 화면 가득 검색 화면
        .fullScreenCover(isPresented: $showSearch) {
            MapSearchView(
                initialQuery: query,
                onSubmit: { q in                         // 키보드 '검색' · 최근 검색어 → 그 검색어로 지도 걸러 보기
                    query = q
                    moveCamera(to: shown)
                },
                onSelect: { e in                         // 결과 하나 → 검색어는 비우고 그 행사로 이동 + 핀 강조
                    query = ""
                    focusedID = e.id
                    moveCamera(to: [e])
                })
            .environmentObject(store)
        }
    }

    // 검색 · 카테고리 · 언제 · 열린 곳만
    var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 검색창 모양의 버튼 — 여기서는 글자를 치지 않고, 누르면 검색 화면이 따로 열려요
            HStack(spacing: 10) {
                Button { showSearch = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.inkSub)
                        Text(query.isEmpty ? "행사·장소·지역·종류 검색 (예: 뮤지컬, 커피, 부산)" : query)
                            .foregroundStyle(query.isEmpty ? Color.inkSub : Color.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(query.isEmpty ? "검색" : "검색어 \(query), 다시 검색")
                if !query.isEmpty {
                    Button { query = ""; focusedID = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.inkSub) }
                        .accessibilityLabel("검색어 지우기")
                }
            }
            .padding(.horizontal, 14).frame(height: 50)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(label: "전체", on: picked == nil) { picked = nil }
                    ForEach(EventCategory.allCases) { c in
                        Chip(label: c.rawValue, on: picked == c) { picked = c }
                    }
                }
            }

            HStack(spacing: 8) {
                Button { openOnly.toggle() } label: {
                    HStack(spacing: 8) {
                        Circle().fill(openOnly ? Color.liveGreen : Color.gray.opacity(0.5)).frame(width: 8, height: 8)
                        Text("열린 곳만").font(.subheadline.bold())
                    }
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(openOnly ? Color(rgb: 0xE7F6EE) : Color.white, in: Capsule())
                    .foregroundStyle(openOnly ? Color.liveText : Color.ink)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                Spacer()
                if let n = notice {                                    // 잠깐 뜨는 안내
                    Text(n).font(.caption.bold()).foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12).frame(height: 32)
                        .background(Color.ink.opacity(0.85), in: Capsule())
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }
}
