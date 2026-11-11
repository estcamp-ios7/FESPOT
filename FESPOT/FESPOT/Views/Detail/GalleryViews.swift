//
//  GalleryViews.swift
//  FESPOT
//
//  사진 갤러리 부품들
//
//  · GalleryImage:      상세 화면 위쪽 칸에 꽉 채워 보여주는 사진
//  · GalleryFullScreen: 사진을 탭하면 뜨는 전체 화면 (옆으로 넘기기)
//  · ZoomableImage:     두 손가락 확대 · 두 번 탭 확대 · 확대 중 끌어서 이동
//

import SwiftUI

struct FullIndex: Identifiable { let id: Int }

// 칸 안에 꽉 채우는 사진 (주소 없으면 자동 포스터)
struct GalleryImage: View {
    let src: String?
    let event: EventItem
    var body: some View {
        if let s = src, let url = URL(string: s) {
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

// 전체 화면 갤러리: 옆으로 넘기기 + 사진마다 확대
struct GalleryFullScreen: View {
    let sources: [String?]
    let start: Int
    let event: EventItem
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(sources.enumerated()), id: \.offset) { i, src in
                    ZoomableImage(src: src, event: event).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: sources.count > 1 ? .always : .never))
            .ignoresSafeArea()

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

// 두 손가락 확대 · 두 번 탭 확대 · 확대 중 이동 (확대 안 했을 땐 옆으로 넘기기가 우선)
struct ZoomableImage: View {
    let src: String?
    let event: EventItem
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        picture
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { v in scale = max(1, min(4, lastScale * v)) }
                    .onEnded { _ in
                        lastScale = scale
                        if scale == 1 { withAnimation { offset = .zero; lastOffset = .zero } }
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { v in
                        offset = CGSize(width: lastOffset.width + v.translation.width,
                                        height: lastOffset.height + v.translation.height)
                    }
                    .onEnded { _ in lastOffset = offset },
                including: scale > 1 ? .all : .subviews          // 확대 안 했으면 이동 끄기 → 옆 넘기기 가능
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                    else { scale = 2.5; lastScale = 2.5 }
                }
            }
    }

    @ViewBuilder var picture: some View {
        if let s = src, let url = URL(string: s) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()          // 잘리지 않게 "맞추기"
                case .failure: Text("사진을 불러오지 못했어요").foregroundStyle(.white)
                default: ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            PosterImage(event: event)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
