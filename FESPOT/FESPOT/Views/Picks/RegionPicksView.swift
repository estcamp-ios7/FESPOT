//
//  RegionPicksView.swift
//  FESPOT
//
//  ② 추천 탭 — 지역 칩을 고르면 그 지역 행사를 포스터 격자로 보여줘요
//
//  · 정렬: 추천순(관심 카테고리 먼저) · 거리순 · 날짜순 (PickSort)
//  · @AppStorage: 고른 정렬 방식을 기기에 기억해서 다음에 켜도 그대로
//

import SwiftUI
import CoreLocation

// 추천 탭 정렬 방식
enum PickSort: String, CaseIterable, Identifiable {
    case date = "날짜순", distance = "거리순", interest = "추천순"      // 메뉴에 이 순서대로 보여요
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .interest: return "heart.text.square"
        case .distance: return "location"
        case .date: return "calendar"
        }
    }
}

struct RegionPicksView: View {
    @EnvironmentObject var store: EventStore
    @EnvironmentObject var location: LocationManager
    @State private var region: String = ""
    @AppStorage("picksSort") private var sort: PickSort = .interest     // 고른 정렬 기억

    var me: CLLocationCoordinate2D { location.coordinate ?? defaultCenter }

    // 행사가 있는 지역만 칩으로: 우리 동네 먼저 → 행사 많은 순 (0개 지역은 숨김)
    var regionChips: [(name: String, count: Int)] {
        let counts = Dictionary(grouping: store.events, by: \.region).mapValues(\.count)
        return counts
            .filter { $0.key != "기타" && $0.value > 0 }
            .map { (name: $0.key, count: $0.value) }
            .sorted {
                if ($0.name == store.profile.sido) != ($1.name == store.profile.sido) { return $0.name == store.profile.sido }
                return $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name
            }
    }
    var defaultRegion: String { regionChips.first?.name ?? store.profile.sido }

    var list: [EventItem] {
        let base = store.events.filter { $0.region == region }
        switch sort {
        case .interest:                                   // 관심 분야 먼저 → 이름순
            let interests = store.profile.interests
            return base.sorted {
                let a = interests.contains($0.category) ? 0 : 1, b = interests.contains($1.category) ? 0 : 1
                return a != b ? a < b : $0.title < $1.title
            }
        case .distance:                                   // 내 위치에서 가까운 순
            return base.sorted { meters(me, $0.coordinate) < meters(me, $1.coordinate) }
        case .date:                                       // 시작일 빠른 순 (같으면 먼저 끝나는 순)
            return base.sorted {
                let s0 = $0.startDate ?? .distantFuture, s1 = $1.startDate ?? .distantFuture
                if s0 != s1 { return s0 < s1 }
                return ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(regionChips, id: \.name) { c in
                            Chip(label: c.name == store.profile.sido ? "📍\(c.name) \(c.count)" : "\(c.name) \(c.count)",
                                 on: region == c.name) { region = c.name }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                // 정렬: 오른쪽 ≡ 버튼
                HStack {
                    Spacer()
                    Menu {
                        Picker("정렬", selection: $sort) {
                            ForEach(PickSort.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(sort.rawValue).font(.subheadline.bold())
                            Image(systemName: "line.3.horizontal").font(.subheadline.bold())
                        }
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 12).frame(height: 34)
                        .background(Color.card, in: Capsule())
                        .overlay(Capsule().stroke(Color.gray.opacity(0.25)))
                    }
                    .accessibilityLabel("정렬 방식: \(sort.rawValue)")
                }
                .padding(.horizontal, 16)
                if list.isEmpty {
                    Text("이 지역은 아직 등록된 행사가 없어요").foregroundStyle(Color.inkSub)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 20) {
                    ForEach(list) { e in
                        NavigationLink(value: e) { PosterCard(event: e) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
        .background(Color.paper)
        .navigationTitle("지역별 추천 행사")
        .onAppear { if region.isEmpty { region = defaultRegion } }
        .onChange(of: store.events.count) { _, _ in                     // 데이터 새로 받으면 빈 지역이면 바꿔주기
            if !regionChips.contains(where: { $0.name == region }) { region = defaultRegion }
        }
        .refreshable { await store.loadFestivals() }
    }
}
