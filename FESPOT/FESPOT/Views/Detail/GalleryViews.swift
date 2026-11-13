//
//  GalleryViews.swift
//  FESPOT
//
//  사진 갤러리 부품들
//
//  · GalleryImage:      상세 화면 위쪽 칸에 꽉 채워 보여주는 사진
//  · GalleryFullScreen: 사진을 탭하면 뜨는 전체 화면 (옆으로 넘기기)
//  · ZoomableImage:     두 손가락 확대·축소 · 두 번 탭 확대 · 확대 중 끌어서 이동
//

import SwiftUI

struct FullIndex: Identifiable { let id: Int }

// 칸 안에 꽉 채우는 사진 (주소 없으면 자동 포스터)
struct GalleryImage: View {
    let src: String?
    let event: EventItem
    var body: some View {
        if let urlString = src, let url = URL(string: urlString) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } placeholder: { Color.gray.opacity(0.15).overlay(ProgressView()) }
        } else {
            PosterImage(event: event)
        }
    }
}

// 전체 화면 갤러리: 옆으로 넘기기 + 사진마다 확대·축소 (두 손가락 · 두 번 탭)
struct GalleryFullScreen: View {
    let sources: [String?]
    let start: Int
    let event: EventItem
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var zoom: CGFloat = 1          // 지금 보고 있는 사진의 배율 (1 = 원래 크기)

    static let minZoom: CGFloat = 1
    static let maxZoom: CGFloat = 5

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(sources.enumerated()), id: \.offset) { photoIndex, src in
                    // 지금 보는 사진만 배율(zoom)과 연결, 나머지는 원래 크기
                    ZoomableImage(src: src, event: event, scale: photoIndex == index ? $zoom : .constant(1)).tag(photoIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: sources.count > 1 && zoom == 1 ? .always : .never))
            .ignoresSafeArea()
            .onChange(of: index) { _, _ in zoom = 1 }          // 다른 사진으로 넘기면 배율 초기화

            VStack(spacing: 4) {
                Spacer()
                Text(event.title).font(.subheadline.bold()).foregroundStyle(.white)
                    .lineLimit(1).truncationMode(.tail)
                if sources.count > 1 {
                    Text("\(index + 1) / \(sources.count)").font(.caption).foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline.bold()).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel("닫기")
            .padding(.trailing, 16).padding(.top, 8)
        }
        .statusBarHidden()
        .onAppear { index = start }
    }
}

// 두 손가락 확대·축소 · 두 번 탭 확대 · 확대 중 끌어서 이동 (확대 안 했을 땐 옆으로 넘기기가 우선)
struct ZoomableImage: View {
    let src: String?
    let event: EventItem
    @Binding var scale: CGFloat                     // 배율은 바깥(GalleryFullScreen)과 같이 씀 → 사진을 넘기면 원래 크기로
    @State private var pinchStart: CGFloat? = nil   // 두 손가락을 대기 시작했을 때의 배율
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            picture
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { magnifyValue in
                            let base = pinchStart ?? scale
                            pinchStart = base
                            scale = min(GalleryFullScreen.maxZoom, max(GalleryFullScreen.minZoom, base * magnifyValue.magnification))
                        }
                        .onEnded { _ in pinchStart = nil }
                )
                .gesture(
                    DragGesture()
                        .onChanged { dragValue in
                            offset = clamped(CGSize(width: lastOffset.width + dragValue.translation.width,
                                                    height: lastOffset.height + dragValue.translation.height), in: geo.size)
                        }
                        .onEnded { _ in lastOffset = offset },
                    including: scale > 1 ? .all : .subviews      // 확대 안 했으면 이동 끄기 → 옆 넘기기 가능
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) { scale = scale > 1 ? 1 : 2.5 }
                }
                // 배율이 바뀌면 사진이 화면 밖으로 빠지지 않게 위치 다시 맞추기
                .onChange(of: scale) { _, _ in
                    offset = clamped(offset, in: geo.size)
                    lastOffset = offset
                }
        }
    }

    // 확대한 만큼만 움직일 수 있게 제한 (배율 2배면 화면 절반까지)
    func clamped(_ proposedOffset: CGSize, in size: CGSize) -> CGSize {
        let maxX = (scale - 1) * size.width / 2
        let maxY = (scale - 1) * size.height / 2
        return CGSize(width: min(maxX, max(-maxX, proposedOffset.width)), height: min(maxY, max(-maxY, proposedOffset.height)))
    }

    @ViewBuilder var picture: some View {
        if let urlString = src, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()          // 잘리지 않게 "맞추기"
                case .failure: Text("사진을 불러오지 못했어요").foregroundStyle(.white)
                default: ProgressView().tint(.white)
                }
            }
        } else {
            PosterImage(event: event)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(24)
        }
    }
}
