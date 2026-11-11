//
//  OnboardingView.swift
//  FESPOT
//
//  앱을 처음 켰을 때 딱 한 번 뜨는 '관심 카테고리 고르기' 화면
//
//  · 고른 카테고리는 store.profile.interests 에 저장 → 추천 탭에서 먼저 보여줘요
//  · 다 고르면 onFinish() 를 불러서 ContentView 가 "봤음(didOnboard)" 으로 표시해요
//  · EventCategory 는 Models/, EventStore 는 Stores/, Color.ink 등은 Design/Colors.swift 에 있어요
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: EventStore
    let onFinish: () -> Void                         // 끝나면 호출 (다시 안 뜨게 표시)
    @State private var picked: [EventCategory] = []

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 질문
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Q.")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(Color.coral)
                        Text("우선으로 보여질\n관심 카테고리를 선택해주세요!")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.ink)
                        Text("*중복 선택 가능")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSub)
                    }
                    .padding(.top, 24)

                    // 카테고리 타일
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(EventCategory.allCases) { c in
                            CategoryTile(category: c, on: picked.contains(c)) { toggle(c) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            // 아래 버튼
            VStack(spacing: 10) {
                Button {
                    store.profile.interests = picked
                    onFinish()
                } label: {
                    Text(picked.isEmpty ? "하나 이상 골라주세요" : "\(picked.count)개 선택 · 시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(picked.isEmpty ? Color.gray.opacity(0.3) : Color.ink, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(picked.isEmpty)

                Button("나중에 할게요") { onFinish() }
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSub)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.paper)
        }
        .background(Color.paper.ignoresSafeArea())
        .onAppear { picked = store.profile.interests }      // 이미 고른 게 있으면 체크된 채로
    }

    func toggle(_ c: EventCategory) {
        if let i = picked.firstIndex(of: c) { picked.remove(at: i) } else { picked.append(c) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// 카테고리 한 칸
struct CategoryTile: View {
    let category: EventCategory
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(category.color, in: Circle())
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(on ? category.color : Color.gray.opacity(0.4))
                }
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(category.blurb)
                    .font(.caption)
                    .foregroundStyle(Color.inkSub)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? category.color.opacity(0.12) : Color.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(on ? category.color : Color.gray.opacity(0.2), lineWidth: on ? 2 : 1)
            )
            .scaleEffect(on ? 1.0 : 0.98)
            .animation(.spring(response: 0.3), value: on)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.rawValue), \(category.blurb)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// 카테고리 한 줄 설명
extension EventCategory {
    var blurb: String {
        switch self {
        case .festival: return "지역 축제 · 문화제"
        case .concert: return "음악 · 뮤지컬 · 연극"
        case .exhibit: return "미술 · 사진 · 박람회"
        case .market: return "마켓 · 장터 · 야시장"
        case .food: return "음식 · 커피 · 술 축제"
        case .night: return "불꽃 · 빛 · 야간 행사"
        case .experience: return "클래스 · 만들기 · 게임"
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environmentObject(EventStore())
}
