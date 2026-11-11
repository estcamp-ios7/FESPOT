//
//  MeView.swift
//  FESPOT
//
//  ④ 내 정보 탭 — 프로필 카드 · 요약 숫자 · 관심 카테고리 · 행사 데이터 상태(진단)
//
//  · '행사 데이터' 칸에 API가 잘 불러와졌는지 문구가 떠요 → 데이터가 안 보일 때 여기부터 확인!
//

import SwiftUI

struct MeView: View {
    @EnvironmentObject var store: EventStore
    var p: Profile { store.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 프로필 카드
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        Avatar(profile: p)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.nickname.isEmpty ? "닉네임을 정해주세요" : p.nickname).font(.title3.bold())
                            Label(p.detail.isEmpty ? p.sido : "\(p.sido) · \(p.detail)", systemImage: "house")
                                .font(.subheadline).foregroundStyle(Color.inkSub)
                        }
                        Spacer()
                    }
                    if !p.bio.isEmpty { Text(p.bio).font(.subheadline) }
                    NavigationLink { ProfileEditView() } label: {
                        Text("프로필 편집").font(.subheadline.bold())
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35)))
                            .foregroundStyle(Color.ink)
                    }
                }
                .padding(18)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))

                // 요약 숫자
                HStack(spacing: 12) {
                    StatBox(value: "\(store.saved.count)", label: "찜한 행사")
                    StatBox(value: "\(p.interests.count)", label: "관심 카테고리")
                    StatBox(value: "\(p.radiusKm)km", label: "관심 반경")
                }

                // 관심 카테고리
                VStack(alignment: .leading, spacing: 10) {
                    Text("관심 있는 행사").font(.headline)
                    if p.interests.isEmpty {
                        Text("프로필 편집에서 고르면 추천 탭에 먼저 보여드려요").font(.subheadline).foregroundStyle(Color.inkSub)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(p.interests) { c in
                                    Label(c.rawValue, systemImage: c.icon).font(.subheadline.bold())
                                        .padding(.horizontal, 12).frame(height: 36)
                                        .background(c.color.opacity(0.15), in: Capsule())
                                        .foregroundStyle(Color.ink)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))

                // 알림 켜기/끄기 (NotificationSettingsCard.swift)
                NotificationSettingsCard()

                // 행사 데이터 상태
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("행사 데이터").font(.subheadline.bold())
                        Text(store.dataNote).font(.caption).foregroundStyle(Color.inkSub)
                        Text("공연·전시: \(store.cultureNote)").font(.caption2).foregroundStyle(Color.inkSub)
                    }
                    Spacer()
                    if store.loading { ProgressView() }
                    else {
                        Button("새로고침") { Task { await store.loadFestivals() } }
                            .font(.subheadline.bold()).foregroundStyle(Color.ink)
                    }
                }
                .padding(18)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                Text("행사 정보 출처: 한국관광공사 TourAPI").font(.caption2).foregroundStyle(Color.inkSub)
            }
            .padding(16)
        }
        .background(Color.paper)
        .navigationTitle("내 정보")
    }
}

struct StatBox: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).foregroundStyle(Color.ink)
            Text(label).font(.caption).foregroundStyle(Color.inkSub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}
