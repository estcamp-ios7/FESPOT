//
//  RouteView.swift
//  FESPOT
//
//  앱 안 길찾기 화면 — TMAP 경로를 우리 지도에 그려서 보여주고 안내해요 (다른 지도 앱으로 안 넘어가요)
//
//  · 위: 닫기 · "출발지 → 행사 이름" · 도보 / 자동차 탭 (탭마다 예상 시간)
//      - 출발지는 기본이 '내 위치', 출발지 줄을 누르면 지도에서 직접 고를 수 있어요 (StartPointPicker.swift)
//  · 가운데: 지도 + 코랄색 경로선 + 출발 핀(고른 경우) + 도착 핀
//  · 아래: 총 시간·거리 · [안내 시작] · 펼치면 단계별 안내 목록
//  · [안내 시작] 하면
//      - 지도가 내 위치를 따라가고, 위에 "다음 안내까지 남은 거리 + 안내 문구"를 크게 보여줘요
//      - 안내 지점 20m 안에 들어오면 다음 단계로 넘어가요
//      - 경로선에서 50m 넘게 벗어나면 경로를 다시 받아요 (너무 자주 요청하지 않게 15초 간격)
//        단, 지도에서 고른 출발지면 다시 계산하지 않고, 출발지에서 멀면 "출발지까지 …"를 먼저 보여줘요
//      - 행사 위치 30m 안에 오면 "도착했어요"
//  · 경로 받는 코드는 Services/TmapRouteService.swift
//

import SwiftUI
import MapKit

struct RouteView: View {
    let event: EventItem
    @EnvironmentObject var location: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var mode: RouteMode = .walk
    @State private var routes: [RouteMode: TmapRoute] = [:]        // 받은 경로 (탭마다 하나)
    @State private var loadingModes: Set<RouteMode> = []
    @State private var errorText: String?
    @State private var position: MapCameraPosition = .automatic
    @State private var showSteps = false                          // 단계 목록 펼침
    @State private var navigating = false                          // [안내 시작] 중
    @State private var stepIndex = 0                               // 지금 향하고 있는 안내 단계
    @State private var arrived = false
    @State private var lastRefresh = Date.distantPast              // 마지막으로 경로를 다시 받은 시각
    @State private var startPoint: StartPoint?                     // 지도에서 고른 출발지 (nil = 내 위치)
    @State private var showStartPicker = false
    @Namespace private var mapScope

    static let stepReachMeters = 20.0       // 이만큼 가까워지면 다음 안내로
    static let offRouteMeters = 50.0        // 경로선에서 이만큼 벗어나면 다시 계산
    static let arriveMeters = 30.0          // 행사 위치까지 이만큼 남으면 도착
    static let refreshInterval = 15.0       // 경로 다시 받기 최소 간격 (초)

    static let farFromStartMeters = 100.0   // 고른 출발지에서 이만큼 떨어져 있으면 "출발지까지 …" 먼저 안내

    var route: TmapRoute? { routes[mode] }

    // 경로의 출발 좌표: 지도에서 고른 곳이 있으면 그곳, 없으면 내 위치
    var startCoordinate: CLLocationCoordinate2D? { startPoint?.coordinate ?? location.coordinate }
    var startName: String { startPoint?.name ?? "내 위치" }

    // 내 위치가 바뀔 때마다 안내를 갱신하려고 쓰는 값 (좌표 자체는 비교가 안 돼서 글자로)
    var locationKey: String {
        guard let me = location.coordinate else { return "" }
        return String(format: "%.6f,%.6f", me.latitude, me.longitude)
    }

    var body: some View {
        Map(position: $position, scope: mapScope) {
            UserAnnotation()
            if let route {
                MapPolyline(coordinates: route.coordinates)
                    .stroke(Color.coral, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            // 지도에서 고른 출발지 (내 위치 출발일 땐 파란 점만)
            if let startPoint {
                Annotation(startPoint.name, coordinate: startPoint.coordinate) {
                    Circle().fill(Color.liveGreen).frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                }
            }
            Annotation(event.title, coordinate: event.coordinate) {
                EventPin(category: event.category, live: false, highlighted: true)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .including([.publicTransport, .parking])))
        .mapControls { MapCompass(); MapScaleView() }
        .overlay(alignment: .bottomTrailing) {
            MapUserLocationButton(scope: mapScope)
                .buttonBorderShape(.circle)
                .tint(Color.ink)
                .controlSize(.large)
                .padding(.trailing, 16).padding(.bottom, 16)
        }
        .mapScope(mapScope)
        .safeAreaInset(edge: .top) {
            if navigating { guidanceBar } else { topBar }
        }
        .safeAreaInset(edge: .bottom) { bottomPanel }
        // 처음 열 때 · 위치가 처음 잡혔을 때 경로 받기
        .task(id: location.coordinate == nil) { await loadFirstRoute() }
        .onChange(of: locationKey) { _, _ in updateNavigation() }
        .onChange(of: mode) { _, _ in
            stepIndex = 0
            Task { await load(mode) }
        }
        // 출발지를 바꾸면 받아 둔 경로를 비우고 새 출발지 기준으로 다시 받기
        .onChange(of: startPoint) { _, _ in
            routes = [:]
            errorText = nil
            stepIndex = 0
            arrived = false
            Task { await loadFirstRoute() }
        }
        .fullScreenCover(isPresented: $showStartPicker) {
            StartPointPicker(initialCenter: startPoint?.coordinate ?? location.coordinate ?? event.coordinate) { picked in
                startPoint = picked
            }
        }
        .onDisappear { location.stopNavigationAccuracy() }
    }

    // =====================================================
    // 위쪽
    // =====================================================

    // 안내 전: 닫기 · 출발/도착 · 수단 탭
    var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                circleButton("xmark", label: "닫기") { dismiss() }
                VStack(alignment: .leading, spacing: 6) {
                    // 출발지 줄: 누르면 지도에서 출발지 고르기
                    Button { showStartPicker = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: startPoint == nil ? "location.fill" : "circle.fill")
                                .font(.caption).foregroundStyle(startPoint == nil ? Color.soonText : Color.liveGreen)
                            Text(startName).font(.caption.bold()).foregroundStyle(Color.ink).lineLimit(1)
                            Spacer(minLength: 4)
                            Text("변경").font(.caption.bold()).foregroundStyle(Color.inkSub)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("출발지 \(startName), 바꾸기")
                    Divider()
                    Label(event.title, systemImage: "mappin.circle.fill").font(.subheadline.bold())
                        .foregroundStyle(Color.ink).lineLimit(1)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            HStack(spacing: 8) {
                ForEach(RouteMode.allCases) { option in modeTab(option) }
            }
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }

    func modeTab(_ option: RouteMode) -> some View {
        let selected = option == mode
        return Button { mode = option } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                Text(option.rawValue)
                if loadingModes.contains(option) {
                    ProgressView().controlSize(.mini)
                } else if let saved = routes[option] {
                    Text(minutesText(saved.totalTime / 60)).monospacedDigit()
                }
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 14).frame(height: 38)
            .background(selected ? Color.ink : Color.card, in: Capsule())
            .foregroundStyle(selected ? Color.onInk : Color.ink)
            .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // 안내 중: 다음 안내를 크게
    var guidanceBar: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: arrived ? "flag.checkered" : "arrow.turn.up.right")
                .font(.title2.bold()).foregroundStyle(Color.onInk)
                .frame(width: 44, height: 44)
                .background(Color.coral, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                if arrived {
                    Text("도착했어요!").font(.title3.bold())
                    Text(event.title).font(.subheadline).foregroundStyle(Color.inkSub).lineLimit(1)
                } else if let toStart = metersToPickedStart, stepIndex == 0 {
                    // 지도에서 고른 출발지가 아직 멀면 → 출발지까지 먼저 안내
                    Text("출발지까지 \(TmapRoute.distanceLabel(toStart))").font(.title3.bold()).monospacedDigit()
                    Text(startName).font(.subheadline).foregroundStyle(Color.inkSub).lineLimit(2)
                } else if let step = currentStep {
                    if let left = metersToCurrentStep {
                        Text(TmapRoute.distanceLabel(left)).font(.title2.bold()).monospacedDigit()
                    }
                    Text(step.instruction).font(.subheadline).foregroundStyle(Color.ink).lineLimit(3)
                } else {
                    Text("경로를 따라 이동하세요").font(.headline)
                }
            }
            .foregroundStyle(Color.ink)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .padding(.horizontal, 16).padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    // =====================================================
    // 아래쪽
    // =====================================================

    var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 내 위치에서 출발하는데 위치를 모를 때 → 지도에서 출발지를 직접 고르면 경로를 볼 수 있어요
            if startPoint == nil && (location.denied || location.coordinate == nil) {
                if location.denied {
                    messageRow("location.slash.fill", "위치 권한이 꺼져 있어 내 위치를 알 수 없어요", button: "설정") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } else {
                    messageRow("location.circle", "내 위치를 찾는 중이에요…", button: nil) {}
                }
                Button { showStartPicker = true } label: {
                    Label("지도에서 출발지 고르기", systemImage: "mappin.and.ellipse")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity).frame(height: 46)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.35)))
                        .foregroundStyle(Color.ink)
                }
                .buttonStyle(.plain)
            } else if let errorText {
                messageRow("exclamationmark.triangle.fill", errorText, button: "다시 시도") {
                    Task { await load(mode, refresh: true) }
                }
            } else if let route {
                HStack(alignment: .firstTextBaseline) {
                    Text(minutesText(route.totalTime / 60)).font(.title2.bold()).foregroundStyle(Color.ink)
                    Text(TmapRoute.distanceLabel(route.totalDistance)).font(.subheadline).foregroundStyle(Color.inkSub)
                    Spacer()
                    Button(showSteps ? "안내 접기" : "단계별 안내") { withAnimation { showSteps.toggle() } }
                        .font(.subheadline.bold()).foregroundStyle(Color.inkSub)
                }
                if showSteps { stepList(route) }
                Button { navigating ? stopNavigation() : startNavigation() } label: {
                    Label(navigating ? "안내 종료" : "안내 시작",
                          systemImage: navigating ? "stop.fill" : "location.north.line.fill")
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                        .background(navigating ? Color.coral : Color.ink, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(navigating ? Color.white : Color.onInk)
                }
                .buttonStyle(.plain)
            } else {
                messageRow("point.topleft.down.to.point.bottomright.curvepath", "경로를 찾는 중이에요…", button: nil) {}
            }
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
        .padding(.horizontal, 12).padding(.bottom, 4)
    }

    func stepList(_ route: TmapRoute) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(route.steps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(step.id + 1)").font(.caption.bold().monospacedDigit())
                            .foregroundStyle(step.id == stepIndex && navigating ? Color.onInk : Color.inkSub)
                            .frame(width: 24, height: 24)
                            .background(step.id == stepIndex && navigating ? Color.coral : Color.gray.opacity(0.15),
                                        in: Circle())
                        Text(step.instruction).font(.subheadline).foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    Divider().padding(.leading, 34)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    func messageRow(_ icon: String, _ text: String, button: String?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.coral)
            Text(text).font(.subheadline).foregroundStyle(Color.ink)
            Spacer(minLength: 0)
            if let button {
                Button(button, action: action).font(.subheadline.bold())
            }
        }
        .padding(.vertical, 6)
    }

    func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.headline.bold()).foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
                .background(Color.card, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .accessibilityLabel(label)
    }

    // =====================================================
    // 경로 받기
    // =====================================================

    // 처음: 출발지에서 2km 이내면 도보, 더 멀면 자동차 탭으로 시작
    func loadFirstRoute() async {
        guard let start = startCoordinate else { return }
        if routes.isEmpty { mode = meters(start, event.coordinate) <= 2_000 ? .walk : .car }
        await load(mode)
    }

    func load(_ target: RouteMode, refresh: Bool = false) async {
        guard let start = startCoordinate else { return }
        if !refresh, routes[target] != nil { fitCamera(); return }
        guard !loadingModes.contains(target) else { return }       // 이미 받는 중이면 또 요청하지 않기
        loadingModes.insert(target)
        defer { loadingModes.remove(target) }
        do {
            let found = try await TmapRouteService.route(from: start, to: event, mode: target,
                                                         startName: startName, refresh: refresh)
            routes[target] = found
            if target == mode {
                errorText = nil
                if !navigating { fitCamera() }
            }
        } catch {
            if target == mode { errorText = error.localizedDescription }
        }
    }

    // 경로 전체가 화면에 보이게 카메라 맞추기
    func fitCamera() {
        guard let route, !route.coordinates.isEmpty else { return }
        let lats = route.coordinates.map(\.latitude), lons = route.coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        // 위아래 안내판에 가리지 않게 넉넉히 (1.6배)
        let span = MKCoordinateSpan(latitudeDelta: max(0.004, (maxLat - minLat) * 1.6),
                                    longitudeDelta: max(0.004, (maxLon - minLon) * 1.6))
        withAnimation(.easeInOut(duration: 0.5)) { position = .region(MKCoordinateRegion(center: center, span: span)) }
    }

    // =====================================================
    // 안내 (내 위치가 바뀔 때마다)
    // =====================================================

    var currentStep: RouteStep? {
        guard let route, route.steps.indices.contains(stepIndex) else { return nil }
        return route.steps[stepIndex]
    }

    var metersToCurrentStep: Double? {
        guard let me = location.coordinate, let step = currentStep else { return nil }
        return meters(me, step.coordinate)
    }

    // 지도에서 고른 출발지까지 남은 거리 (100m 넘게 떨어져 있을 때만, 아니면 nil)
    var metersToPickedStart: Double? {
        guard let startPoint, let me = location.coordinate else { return nil }
        let distance = meters(me, startPoint.coordinate)
        return distance > Self.farFromStartMeters ? distance : nil
    }

    func startNavigation() {
        navigating = true
        arrived = false
        stepIndex = 0
        showSteps = false
        location.startNavigationAccuracy()
        withAnimation { position = .userLocation(followsHeading: true, fallback: .automatic) }
        updateNavigation()
    }

    func stopNavigation() {
        navigating = false
        location.stopNavigationAccuracy()
        fitCamera()
    }

    func updateNavigation() {
        guard navigating, let me = location.coordinate, let route else { return }

        // 도착
        if meters(me, event.coordinate) <= Self.arriveMeters { arrived = true; return }

        // 안내 지점에 가까워지면 다음 단계로 (여러 개를 한 번에 지나쳤을 수도 있어서 while)
        while let step = currentStep, meters(me, step.coordinate) <= Self.stepReachMeters,
              stepIndex < route.steps.count - 1 {
            stepIndex += 1
        }

        // 경로선에서 너무 멀어지면 다시 계산 (지도에서 고른 출발지면 안 함 → 출발지로 가는 중일 수 있어서,
        // 다시 계산하면 고른 출발지가 내 위치로 바뀌어 버려요)
        if startPoint == nil,
           distanceToRoute(me, route.coordinates) > Self.offRouteMeters,
           Date().timeIntervalSince(lastRefresh) > Self.refreshInterval {
            lastRefresh = Date()
            Task {
                await load(mode, refresh: true)
                stepIndex = 0
            }
        }
    }

    // 내 위치에서 경로선까지 가장 가까운 거리 (미터, 선분마다 계산)
    func distanceToRoute(_ point: CLLocationCoordinate2D, _ line: [CLLocationCoordinate2D]) -> Double {
        guard line.count >= 2 else { return line.first.map { meters(point, $0) } ?? .infinity }
        // 좁은 범위라서 평면처럼 계산해도 충분해요 (경도 1도의 길이는 위도에 따라 줄어서 cos 를 곱함)
        let metersPerLat = 111_000.0
        let metersPerLon = 111_000.0 * cos(point.latitude * .pi / 180)
        func flat(_ c: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            ((c.longitude - point.longitude) * metersPerLon, (c.latitude - point.latitude) * metersPerLat)
        }
        var best = Double.infinity
        for index in 0..<(line.count - 1) {
            let start = flat(line[index]), end = flat(line[index + 1])
            let dx = end.x - start.x, dy = end.y - start.y
            let lengthSquared = dx * dx + dy * dy
            // 선분 위에서 내 위치(원점)와 가장 가까운 점의 비율 (0 = 시작점, 1 = 끝점)
            let ratio = lengthSquared == 0 ? 0 : max(0, min(1, -(start.x * dx + start.y * dy) / lengthSquared))
            let nearestX = start.x + ratio * dx, nearestY = start.y + ratio * dy
            best = min(best, (nearestX * nearestX + nearestY * nearestY).squareRoot())
        }
        return best
    }
}
