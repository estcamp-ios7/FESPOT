//
//  StartPointPicker.swift
//  FESPOT
//
//  길찾기 출발지를 고르는 화면 (검색 또는 지도에서 핀으로)
//
//  · 위쪽 검색창에 "강남역"처럼 치면 TMAP 장소 검색 결과가 아래에 떠요 → 누르면 지도가 그곳으로 이동
//  · 또는 지도를 움직여서 화면 가운데 고정된 핀을 원하는 곳에 맞추고 [여기서 출발]
//  · 지도를 멈추면 핀 자리의 주소를 TMAP 에서 받아 보여줘요 (Services/TmapPlaceService.swift)
//  · [내 위치로] 를 누르면 출발지를 다시 '내 위치'로 되돌려요
//  · 고른 결과는 onPick 으로 길찾기 화면(RouteView)에 돌려줘요 (nil = 내 위치)
//

import SwiftUI
import MapKit

struct StartPointPicker: View {
    let initialCenter: CLLocationCoordinate2D       // 처음 지도 가운데 (지금 출발지 → 내 위치 → 행사 위치 순)
    let onPick: (StartPoint?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    @State private var addressText: String?          // 핀 자리 주소 (nil = 아직 모름)
    @State private var loadingAddress = false
    @State private var addressTask: Task<Void, Never>?
    @State private var skipNextAddressLookup = false  // 검색으로 고른 직후엔 지도 이동이 끝나도 주소로 이름을 덮어쓰지 않기

    // ---------- 검색 ----------
    @State private var query = ""                     // 검색창에 친 글자
    @FocusState private var searchFocused: Bool       // 검색창에 커서가 있나? (키보드 올라옴)
    @State private var results: [TmapPlaceService.Place] = []
    @State private var searchingNow = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @Namespace private var mapScope

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    init(initialCenter: CLLocationCoordinate2D, onPick: @escaping (StartPoint?) -> Void) {
        self.initialCenter = initialCenter
        self.onPick = onPick
        _center = State(initialValue: initialCenter)
        _position = State(initialValue: .region(MKCoordinateRegion(center: initialCenter,
                                                                    latitudinalMeters: 800, longitudinalMeters: 800)))
    }

    var body: some View {
        Map(position: $position, scope: mapScope) {
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .including([.publicTransport, .parking])))
        .mapControls { MapCompass(); MapScaleView() }
        // 지도를 다 움직이고 손을 떼면 → 가운데 좌표의 주소 받기
        .onMapCameraChange(frequency: .onEnd) { context in
            center = context.region.center
            if skipNextAddressLookup { skipNextAddressLookup = false; return }
            lookUpAddress()
        }
        // 화면 가운데 고정 핀 (지도는 움직이고 핀은 가만히 있어요)
        .overlay {
            Image(systemName: "mappin")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color.coral)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .offset(y: -20)                              // 핀 끝이 정확히 가운데를 가리키게
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomTrailing) {
            MapUserLocationButton(scope: mapScope)
                .buttonBorderShape(.circle)
                .tint(Color.ink)
                .controlSize(.large)
                .padding(.trailing, 16).padding(.bottom, 16)
        }
        .mapScope(mapScope)
        .safeAreaInset(edge: .top) { topBar }
        .safeAreaInset(edge: .bottom) { bottomPanel }
        .task { lookUpAddress() }
        // 타자를 멈추고 0.4초 지나면 검색
        .onChange(of: query) { _, _ in runSearch() }
        .onDisappear {
            addressTask?.cancel()
            searchTask?.cancel()
        }
    }

    // 맨 위: 닫기 · 검색창 · 내 위치로 (+ 검색 결과 목록)
    var topBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline.bold()).foregroundStyle(Color.ink)
                        .frame(width: 44, height: 44)
                        .background(Color.card, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .accessibilityLabel("닫기")

                searchField

                myLocationButton
            }
            if !trimmedQuery.isEmpty && searchFocused { resultList }
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }

    // 검색창 (예전 "지도를 움직여 출발지를 맞춰주세요" 자리)
    var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.inkSub)
            TextField("출발지 검색 (예: 강남역)", text: $query)
                .font(.subheadline)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { runSearch(immediately: true) }
            if !query.isEmpty {
                Button { query = ""; results = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.inkSub)
                }
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    // 검색 결과 목록 (누르면 지도가 그곳으로)
    var resultList: some View {
        VStack(spacing: 0) {
            if searchingNow && results.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("찾는 중이에요…").font(.subheadline).foregroundStyle(Color.inkSub)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            } else if let searchError {
                Text(searchError).font(.subheadline).foregroundStyle(Color.inkSub)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            } else if results.isEmpty {
                Text("검색 결과가 없어요").font(.subheadline).foregroundStyle(Color.inkSub)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(results) { place in
                        Button { pick(place) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill").font(.title3).foregroundStyle(Color.coral)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name).font(.subheadline.bold()).foregroundStyle(Color.ink).lineLimit(1)
                                    Text(place.address).font(.caption).foregroundStyle(Color.inkSub).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Text(TmapRoute.distanceLabel(meters(center, place.coordinate)))
                                    .font(.caption).foregroundStyle(Color.inkSub).monospacedDigit()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .frame(maxHeight: 320)
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    // 출발지를 다시 '내 위치'로
    var myLocationButton: some View {
        Button {
            onPick(nil)
            dismiss()
        } label: {
            Label("내 위치로", systemImage: "location.fill")
                .font(.caption.bold()).foregroundStyle(Color.ink)
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.card, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .accessibilityLabel("출발지를 내 위치로")
    }

    // 맨 아래: 핀 자리 주소 + [여기서 출발]
    var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill").font(.title3).foregroundStyle(Color.coral)
                if loadingAddress {
                    ProgressView().controlSize(.small)
                    Text("주소를 찾는 중이에요…").font(.subheadline).foregroundStyle(Color.inkSub)
                } else {
                    Text(addressText ?? "선택한 위치").font(.subheadline.bold()).foregroundStyle(Color.ink)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            Button {
                onPick(StartPoint(name: addressText ?? "선택한 위치", coordinate: center))
                dismiss()
            } label: {
                Text("여기서 출발")
                    .font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.ink, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color.onInk)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
        .padding(.horizontal, 12).padding(.bottom, 4)
    }

    // 검색: 타자를 멈추고 0.4초 뒤 (엔터를 누르면 바로). 새로 치면 이전 요청은 취소
    func runSearch(immediately: Bool = false) {
        searchTask?.cancel()
        let keyword = trimmedQuery
        guard !keyword.isEmpty else {
            results = []
            searchError = nil
            searchingNow = false
            return
        }
        let near = center
        searchTask = Task {
            searchingNow = true
            if !immediately { try? await Task.sleep(for: .milliseconds(400)) }
            guard !Task.isCancelled else { return }
            do {
                let found = try await TmapPlaceService.search(keyword, near: near)
                guard !Task.isCancelled else { return }
                results = found
                searchError = nil
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                searchError = error.localizedDescription
            }
            searchingNow = false
        }
    }

    // 검색 결과 하나 고르기 → 지도를 그곳으로 옮기고 이름 표시 ([여기서 출발]을 누르면 확정)
    func pick(_ place: TmapPlaceService.Place) {
        searchFocused = false
        addressTask?.cancel()
        loadingAddress = false
        addressText = place.name
        center = place.coordinate
        skipNextAddressLookup = true
        withAnimation(.easeInOut(duration: 0.5)) {
            position = .region(MKCoordinateRegion(center: place.coordinate,
                                                  latitudinalMeters: 600, longitudinalMeters: 600))
        }
    }

    // 지도를 멈춘 뒤 0.3초 기다렸다가 주소 받기 (계속 움직이는 중이면 이전 요청은 취소)
    func lookUpAddress() {
        addressTask?.cancel()
        let target = center
        addressTask = Task {
            loadingAddress = true
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let found = await TmapPlaceService.address(at: target)
            guard !Task.isCancelled else { return }
            addressText = found
            loadingAddress = false
        }
    }
}
