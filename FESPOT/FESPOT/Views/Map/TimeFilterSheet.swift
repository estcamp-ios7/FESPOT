//
//  TimeFilterSheet.swift
//  FESPOT
//
//  '언제 갈까요?' 요일·시간 고르는 작은 시트 + 시간 버튼 부품
//
//  · @Binding: 부모 화면의 값을 '빌려와서' 여기서 바꾸면 부모 쪽 값도 같이 바뀌어요
//

import SwiftUI

// 언제 갈지 고르는 작은 시트 (예전 타임라인 기능)
struct TimeFilterSheet: View {
    @Binding var day: Day
    @Binding var hour: Int?
    @Environment(\.dismiss) private var dismiss
    private let hours = [10, 12, 14, 16, 18, 20, 22]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("언제 갈까요?").font(.title3.bold())
            Picker("요일", selection: $day) {
                ForEach(Day.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                TimeButton(label: "지금", on: hour == nil) { hour = nil }
                ForEach(hours, id: \.self) { hourOption in
                    TimeButton(label: "\(hourOption)시", on: hour == hourOption) { hour = hourOption }
                }
            }
            Button { dismiss() } label: {
                Text("이 시간으로 지도 보기").font(.headline)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.ink, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color.onInk)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }
}

struct TimeButton: View {
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(on ? Color.ink : Color.card, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(on ? Color.onInk : Color.ink)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Color.clear : Color.gray.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}
