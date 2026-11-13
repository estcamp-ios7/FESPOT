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
                    VStack(spacing: 16) {
                        // 프로필 아바타 이미지
                        Avatar(profile: draft, size: 96)
                        
                        // 1. 사진 바꾸기 버튼 (기교 없이 폰트만 적용)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("사진 바꾸기")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.plain)
                        
                        // 2. 사진 지우기 버튼 (사진이 있을 때만 노출)
                        if draft.photo != nil {
                            Button(role: .destructive) {
                                draft.photo = nil
                                photoItem = nil // 선택된 피커 아이템 초기화
                            } label: {
                                Text("사진 지우기")
                                    .font(.caption)
                                    .foregroundStyle(Color.red)
                            }
                            .buttonStyle(.plain)
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
                    ForEach(EventCategory.allCases) { category in
                        let isSelected = draft.interests.contains(category)
                        Button {
                            if isSelected { draft.interests.removeAll { $0 == category } } else { draft.interests.append(category) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(isSelected ? category.color : Color.gray.opacity(0.12), in: Capsule())
                            .foregroundStyle(isSelected ? Color.white : Color.ink)
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
                .pickerStyle(.menu)
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
                   let uiImage = UIImage(data: data),
                   let small = uiImage.jpegData(compressionQuality: 0.6) {          // 저장 용량 줄이기
                    draft.photo = small
                }
            }
        }
    }
}
