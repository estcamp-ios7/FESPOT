//
//  ProfileEditView.swift
//  FESPOT
//
//  프로필 편집 화면 — 사진 · 닉네임 · 사는 곳 · 관심 카테고리 · 반경
//
//  · draft(임시 사본)에서 고치다가 '저장'을 눌러야 진짜 프로필(store.profile)에 반영돼요
//    → 저장 안 하고 뒤로 가면 바뀐 내용이 버려져요
//

import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var store: EventStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Profile()
    @State private var photoItem: PhotosPickerItem?
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Avatar(profile: draft, size: 96)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("사진 바꾸기").font(.subheadline.bold())
                        }
                        if draft.photo != nil {
                            Button("사진 지우기", role: .destructive) { draft.photo = nil }.font(.caption)
                        }
                    }
                    Spacer()
                }
            }
            Section("기본 정보") {
                TextField("닉네임", text: $draft.nickname)
            }
            Section {
                Picker("시·도", selection: $draft.sido) {
                    ForEach(sidoList, id: \.self) { Text($0).tag($0) }
                }
                TextField("구·동 (예: 성동구 성수동)", text: $draft.detail)
            } header: {
                Text("사는 곳")
            } footer: {
                Text("추천 탭이 사는 지역 행사부터 보여줘요.")
            }
            Section("관심 있는 행사") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                    ForEach(EventCategory.allCases) { c in
                        let on = draft.interests.contains(c)
                        Button {
                            if on { draft.interests.removeAll { $0 == c } } else { draft.interests.append(c) }
                        } label: {
                            Label(c.rawValue, systemImage: c.icon).font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(on ? c.color : Color.gray.opacity(0.12), in: Capsule())
                                .foregroundStyle(on ? Color.white : Color.ink)
                                .labelIconToTitleSpacing(15)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("관심 반경") {
                Picker("반경", selection: $draft.radiusKm) {
                    ForEach([1, 3, 5, 10], id: \.self) { Text("\($0)km").tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { store.profile = draft; dismiss() }.bold()
            }
        }
        .onAppear { if !loaded { draft = store.profile; loaded = true } }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data),
                   let small = ui.jpegData(compressionQuality: 0.6) {          // 저장 용량 줄이기
                    draft.photo = small
                }
            }
        }
    }
}
