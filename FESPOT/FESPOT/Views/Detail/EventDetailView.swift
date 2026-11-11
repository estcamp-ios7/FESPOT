//
//  EventDetailView.swift
//  FESPOT
//
//  행사 상세 화면 — 사진 갤러리 · 상태 · 행사 정보 · 소개 · 지도 · 길찾기 · 근처 행사
//  · 포스터를 탭하거나 두 손가락으로 벌리면 전체 화면에서 확대·축소할 수 있어요 (GalleryViews.swift)
//
//  · 화면이 열리면 .task 에서 loadExtra() 로 추가 정보(사진·소개·요금 등)를 인터넷에서 더 받아와요
//  · TourAPI 행사(id가 "tour-"로 시작)와 공연·전시("culture-"로 시작)는 상세 정보를 받는 곳이 달라요
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    @EnvironmentObject var store: EventStore
    @EnvironmentObject var location: LocationManager
    let event: EventItem                           // 보여줄 행사 (바깥에서 넘겨받음)
    @State private var showMapChoice = false       // true 면 '어떤 지도로 열까요?' 메뉴가 뜸
    @State private var showBigMap = false          // true 면 큰 지도(EventMapFullScreen)가 뜸
    @State private var page = 0                    // 지금 보고 있는 사진 번호
    @State private var fullIndex: FullIndex?       // 전체 화면으로 볼 사진 번호
    @State private var extraImages: [String] = []  // TourAPI 홍보 이미지들
    @State private var homepage: URL?
    @State private var overview: String?
    @State private var commonTel: String?          // TourAPI 기본정보의 문의 전화 (주최 연락처가 없을 때 대신)
    @State private var intro: TourAPI.FestivalIntro?      // 운영 시간 · 요금 · 주최 등
    @State private var loadingExtra = false
    @State private var showAllOverview = false

    // 첫 장 = 대표 포스터, 그다음 = 관광공사에 올라온 홍보 이미지 (중복 제외). nil = 자동 생성 포스터
    var gallery: [String?] {
        var arr: [String?] = [event.posterURL]
        for u in event.extraImageURLs + extraImages where u != event.posterURL && !arr.contains(u) { arr.append(u) }
        return arr
    }

    var me: CLLocationCoordinate2D { location.coordinate ?? defaultCenter }

    var body: some View {
        let st = status(of: event, nowMinutes: nowMinutes())
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 옆으로 넘기는 사진들 (탭하거나 두 손가락으로 벌리면 전체 화면)
                TabView(selection: $page) {
                    ForEach(Array(gallery.enumerated()), id: \.offset) { i, src in
                        Color.clear
                            .overlay { GalleryImage(src: src, event: event) }
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { fullIndex = FullIndex(id: i) }
                            // 두 손가락으로 벌리면 → 확대할 수 있는 전체 화면 열기
                            .simultaneousGesture(
                                MagnifyGesture().onEnded { v in
                                    if v.magnification > 1.1 { fullIndex = FullIndex(id: i) }
                                }
                            )
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("사진 \(i + 1), 전체 화면에서 확대해 보기")
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: gallery.count > 1 ? .always : .never))
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .topTrailing) {
                    if gallery.count > 1 {
                        Text("\(page + 1) / \(gallery.count)").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(10)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(10)
                        .allowsHitTesting(false)
                }
                if gallery.count > 1 {
                    Text("← 옆으로 넘기면 공식 홍보 이미지 \(gallery.count - 1)장 더 있어요")
                        .font(.caption).foregroundStyle(Color.inkSub)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(event.placeTypeLabel).font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(event.category.color.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.ink)
                        if let b = event.badge { BadgeView(badge: b) }
                    }
                    Text(event.title).font(.title2.bold()).lineLimit(2)
                    Text("\(event.place) · \(distanceText(meters(me, event.coordinate)))")
                        .font(.subheadline).foregroundStyle(Color.inkSub)
                }

                HStack(spacing: 10) {
                    Circle().fill(st.isLive ? Color.liveGreen : st.color).frame(width: 10, height: 10)
                    Text(st.text).font(.headline).foregroundStyle(st.color)
                    Spacer()
                }
                .padding(16)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.2)))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("행사 정보").font(.headline)
                        if loadingExtra { ProgressView().scaleEffect(0.8) }
                    }
                    InfoRow(label: "운영", value: intro?.playtime ?? event.hoursText)
                    if !event.allDay {
                        InfoRow(label: "요일", value: Day.allCases.filter { event.days.contains($0) }.map(\.rawValue).joined(separator: " · "))
                    }
                    InfoRow(label: "기간", value: event.period)
                    if let v = intro?.place { InfoRow(label: "장소", value: v) }
                    InfoRow(label: "요금", value: intro?.fee ?? event.price)
                    if let v = intro?.discount { InfoRow(label: "할인", value: v) }
                    if let v = intro?.age { InfoRow(label: "연령", value: v) }
                    if let v = intro?.duration { InfoRow(label: "소요", value: v) }
                    if let v = intro?.booking { InfoRow(label: "예매", value: v) }
                    if let host = intro?.host { InfoRow(label: "주최", value: host) }
                    // API가 전화번호를 주면 → 번호를 보여주고, 누르면 전화 앱으로 (Utilities/PhoneNumber.swift)
                    if let phone = PhoneNumber(from: intro?.hostTel) ?? PhoneNumber(from: commonTel) {
                        HStack(alignment: .center, spacing: 12) {
                            Text("전화").foregroundStyle(Color.inkSub).frame(width: 44, alignment: .leading)
                            Link(destination: phone.url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "phone.fill").font(.caption)
                                    Text(phone.display).underline()
                                }
                                .foregroundStyle(Color.liveText)
                            }
                            .accessibilityLabel("전화 걸기 \(phone.display)")
                        }
                        .font(.subheadline)
                    }
                }
                .padding(16)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 18))

                if let prog = intro?.program {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("프로그램").font(.headline)
                        Text(prog).font(.subheadline).foregroundStyle(Color.ink).lineLimit(6)
                    }
                }

                if let ov = overview {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("행사 소개").font(.headline)
                        Text(ov).font(.subheadline).foregroundStyle(Color.ink)
                            .lineLimit(showAllOverview ? nil : 5)
                        Button(showAllOverview ? "접기" : "더 보기") { withAnimation { showAllOverview.toggle() } }
                            .font(.subheadline.bold()).foregroundStyle(Color.inkSub)
                    }
                }
                if let hp = homepage {
                    Link(destination: hp) {
                        Label("공식 홈페이지에서 더 보기", systemImage: "safari")
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).frame(height: 46)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.35)))
                            .foregroundStyle(Color.ink)
                    }
                }

                Map(initialPosition: .region(MKCoordinateRegion(center: event.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)),
                    interactionModes: []) {
                    Annotation(event.title, coordinate: event.coordinate) { EventPin(category: event.category, live: st.isLive) }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                // 작은 지도는 움직이지 않고, 누르면 확대·이동되는 큰 지도가 열려요
                .overlay {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { showBigMap = true }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(10)
                        .allowsHitTesting(false)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("행사 위치 지도, 크게 보기")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { showBigMap = true }

                Button { showMapChoice = true } label: {
                    Label("길찾기", systemImage: "location.north.line.fill")
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.ink, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color.onInk)
                }
                .buttonStyle(.plain)

                let nearby = store.events
                    .filter { $0.id != event.id && $0.latitude != 0 && meters(event.coordinate, $0.coordinate) < 2000 }
                    .sorted { meters(event.coordinate, $0.coordinate) < meters(event.coordinate, $1.coordinate) }
                if !nearby.isEmpty {
                    // 제목: 회색 걷는 사람 픽토그램 + 근처 행사
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.gray)
                            .accessibilityHidden(true)
                        Text("근처 행사").font(.title3.bold()).foregroundStyle(Color.ink)
                    }
                    .padding(.top, 8)

                    // 옆으로 넘기는 포스터 카드 (카드 탭 → 그 행사 상세로 이동)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(nearby) { n in
                                NavigationLink(value: n) {
                                    NearbyCard(event: n, from: event.coordinate)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, -20)                  // 화면 끝까지 넘겨지게
                }
            }
            .padding(20)
        }
        .background(Color.paper)
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.toggleSave(event) } label: {
                    Image(systemName: store.saved.contains(event.id) ? "heart.fill" : "heart")
                        .foregroundStyle(store.saved.contains(event.id) ? Color.coral : Color.ink)
                }
                .accessibilityLabel("찜하기")
            }
        }
        // 길찾기 버튼 → 아래에서 올라오는 지도 앱 선택 메뉴
        .confirmationDialog("어떤 지도로 길찾기 할까요?", isPresented: $showMapChoice, titleVisibility: .visible) {
            ForEach(MapApp.allCases) { app in
                Button(app.rawValue) { openDirections(in: app) }
            }
            Button("취소", role: .cancel) {}
        }
        .fullScreenCover(item: $fullIndex) { f in GalleryFullScreen(sources: gallery, start: f.id, event: event) }
        .fullScreenCover(isPresented: $showBigMap) {
            EventMapFullScreen(event: event, live: status(of: event, nowMinutes: nowMinutes()).isLive)
                .environmentObject(location)
        }
        .task(id: event.id) { await loadExtra() }
    }

    // TourAPI 행사면 홍보 이미지 · 소개글 · 홈페이지를 추가로 불러오기
    func loadExtra() async {
        if event.id.hasPrefix("culture-") { await loadCultureExtra(); return }   // 공연·전시는 따로
        guard let cid = event.contentId, let key = TourAPI.serviceKey else { return }
        loadingExtra = true
        async let imgs = TourAPI.fetchImages(contentId: cid, key: key)
        async let info = TourAPI.fetchCommon(contentId: cid, key: key)
        async let detail = TourAPI.fetchIntro(contentId: cid, key: key)      // 3개를 동시에 요청
        let (i, c, d) = await (imgs, info, detail)
        extraImages = i
        homepage = c.homepage
        overview = c.overview
        commonTel = c.tel
        intro = d
        loadingExtra = false
    }

    // 한국문화정보원 상세: 가격 · 문의 · 홈페이지 · 소개 · 이미지 · 주소
    func loadCultureExtra() async {
        guard let key = Culture.serviceKey else { return }
        loadingExtra = true
        let seq = String(event.id.dropFirst("culture-".count))
        if let d = await Culture.fetchDetail(seq: seq, key: key) {
            intro = TourAPI.FestivalIntro(playtime: nil, fee: d.price, discount: nil,
                                          host: nil, hostTel: d.phone,
                                          age: nil, place: d.address, duration: nil, booking: nil, program: nil)
            homepage = d.link
            overview = d.contents
            if let img = d.image { extraImages = [img] }
        }
        loadingExtra = false
    }

    // 고른 지도 앱으로 길찾기 (Services/Directions.swift) — 2km 이내면 도보, 더 멀면 자동차
    func openDirections(in app: MapApp) {
        let walk = location.coordinate.map { meters($0, event.coordinate) <= 2_000 } ?? true
        Task { await app.open(for: event, walk: walk) }
    }
}
