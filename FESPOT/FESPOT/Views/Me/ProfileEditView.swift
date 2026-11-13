import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var store: EventStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = Profile()
    @State private var photoItem: PhotosPickerItem?
    @State private var loaded = false

    // 변경: 사진 삭제 확인창 표시 여부
    @State private var isShowingPhotoDeleteAlert = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Avatar(profile: draft, size: 96)

                        // 사진 바꾸기
                        PhotosPicker(
                            selection: $photoItem,
                            matching: .images
                        ) {
                            Text("사진 바꾸기")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.plain)

                        // 변경: 사진첩 대신 삭제 확인창 표시
                        if draft.photo != nil {
                            Button {
                                isShowingPhotoDeleteAlert = true
                            } label: {
                                Text("사진 지우기")
                                    .font(.caption)
                                    .foregroundStyle(.red)
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
                    ForEach(sidoList, id: \.self) {
                        Text($0).tag($0)
                    }
                }

                TextField(
                    "구·동 (예: 성동구 성수동)",
                    text: $draft.detail
                )
            } header: {
                Text("사는 곳")
            } footer: {
                Text("추천 탭이 사는 지역 행사부터 보여줘요.")
            }

            Section("관심 있는 행사") {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 92), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    ForEach(EventCategory.allCases) { category in
                        let isSelected = draft.interests.contains(category)

                        Button {
                            if isSelected {
                                draft.interests.removeAll {
                                    $0 == category
                                }
                            } else {
                                draft.interests.append(category)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                isSelected
                                ? category.color
                                : Color.gray.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(
                                isSelected ? Color.white : Color.ink
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("관심 반경") {
                Picker("반경", selection: $draft.radiusKm) {
                    ForEach([1, 3, 5, 10], id: \.self) {
                        Text("\($0)km").tag($0)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    store.profile = draft
                    dismiss()
                }
                .bold()
            }
        }
        .onAppear {
            if !loaded {
                draft = store.profile
                loaded = true
            }
        }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(
                    type: Data.self
                ),
                let uiImage = UIImage(data: data),
                let small = uiImage.jpegData(
                    compressionQuality: 0.6
                ) {
                    draft.photo = small
                }
            }
        }

        // 변경: 기존 fullScreenCover를 삭제 확인창으로 교체
        .alert(
            "진짜 진짜 진짜 진짜 삭제하시겠습니까?",
            isPresented: $isShowingPhotoDeleteAlert
        ) {
            Button("N", role: .cancel) {
                // 사진을 유지하고 확인창만 닫기
            }

            Button("Y", role: .destructive) {
                // 편집 중인 프로필 사진 제거
                draft.photo = nil
                photoItem = nil
            }
        } message: {
            Text("프로필 사진만 제거됩니다. 사진첩의 원본 사진은 삭제되지 않습니다.")
        }
    }
}
