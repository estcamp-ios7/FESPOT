//
//  EventMapFullScreen.swift
//  FESPOT
//
//  행사 상세의 작은 지도를 누르면 뜨는 '큰 지도' 화면
//
//  · 두 손가락으로 확대·축소, 한 손가락으로 끌어서 이동, 두 손가락 돌리기 모두 돼요
//  · 오른쪽 아래 버튼: 내 위치로 이동 / '행사 위치로' 버튼: 다시 행사 핀으로 돌아오기
//  · 아래 '길찾기' 버튼은 상세 화면과 똑같이 네이버 · 카카오 · Apple 지도 중 골라서 열어요
//

import SwiftUI
import MapKit

struct EventMapFullScreen: View {
    let event: EventItem
    let live: Bool                                    // 지금 열려 있으면 핀에 초록 점
    @EnvironmentObject var location: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var showMapChoice = false
    @Namespace private var mapScope

    init(event: EventItem, live: Bool) {
        self.event = event
        self.live = live
        // 처음엔 행사 위치를 가운데에 (작은 지도보다 살짝 넓게)
        _position = State(initialValue: .region(Self.eventRegion(event)))
    }

    static func eventRegion(_ targetEvent: EventItem) -> MKCoordinateRegion {
        MKCoordinateRegion(center: targetEvent.coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200)
    }

    var body: some View {
        // interactionModes 를 안 적으면 = 확대 · 축소 · 이동 · 회전 전부 가능
        Map(position: $position, scope: mapScope) {
            UserAnnotation()
            Annotation(event.title, coordinate: event.coordinate) {
                EventPin(category: event.category, live: live, highlighted: true)
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
        .safeAreaInset(edge: .top) { topBar }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .confirmationDialog("어떤 지도로 길찾기 할까요?", isPresented: $showMapChoice, titleVisibility: .visible) {
            ForEach(MapApp.allCases) { app in
                Button(app.rawValue) {
                    let walk = location.coordinate.map { meters($0, event.coordinate) <= 2_000 } ?? true
                    Task { await app.open(for: event, walk: walk) }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    // 맨 위: 닫기 · 행사 이름 · 행사 위치로 돌아오기
    var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline.bold()).foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.card, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            .accessibilityLabel("닫기")

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.subheadline.bold()).foregroundStyle(Color.ink).lineLimit(1)
                Text(event.place).font(.caption).foregroundStyle(Color.inkSub).lineLimit(1)
            }
            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Button {
                withAnimation(.easeInOut(duration: 0.5)) { position = .region(Self.eventRegion(event)) }
            } label: {
                Image(systemName: "scope").font(.headline.bold()).foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.card, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            .accessibilityLabel("행사 위치로")
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }

    // 맨 아래: 길찾기
    var bottomBar: some View {
        Button { showMapChoice = true } label: {
            Label("길찾기", systemImage: "location.north.line.fill")
                .font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.ink, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color.onInk)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.bottom, 8)       // 내 위치 버튼은 자동으로 이 버튼 바로 위에 놓여요
    }
}
