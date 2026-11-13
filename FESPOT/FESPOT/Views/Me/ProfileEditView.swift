
import SwiftUI
import PhotosUI
import Photos

struct ProfileEditView: View {
    @EnvironmentObject var store: EventStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = Profile()
    @State private var photoItem: PhotosPickerItem?
    @State private var loaded = false
    @State private var isShowingPhotoDeleteView = false

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

                        // 사진 지우기
                        if draft.photo != nil {
                            Button {
                                isShowingPhotoDeleteView = true
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
                        InterestCategoryButton(
                            category: category,
                            isSelected: draft.interests.contains(category)
                        ) {
                            if draft.interests.contains(category) {
                                draft.interests.removeAll {
                                    $0 == category
                                }
                            } else {
                                draft.interests.append(category)
                            }
                        }
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
        .fullScreenCover(
            isPresented: $isShowingPhotoDeleteView
        ) {
            PhotoGalleryDeleteView(
                onClose: {
                    isShowingPhotoDeleteView = false
                }
            )
        }
    }
}

// MARK: - 사진첩 삭제 화면

private struct PhotoGalleryDeleteView: View {
    @Environment(\.dismiss) private var dismiss

    let onClose: () -> Void

    @State private var photos: [PHAsset] = []
    @State private var selectedPhotos: Set<String> = []
    @State private var hasPermission = false
    @State private var isLoading = true
    @State private var showDeleteError = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("사진을 불러오는 중...")
                } else if !hasPermission {
                    ContentUnavailableView(
                        "사진 접근 권한이 필요합니다",
                        systemImage: "photo",
                        description: Text(
                            "설정에서 FESPOT의 사진 접근을 허용해 주세요."
                        )
                    )
                } else if photos.isEmpty {
                    ContentUnavailableView(
                        "사진이 없습니다",
                        systemImage: "photo"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: columns,
                            spacing: 2
                        ) {
                            ForEach(
                                photos,
                                id: \.localIdentifier
                            ) { photo in

                                PhotoGalleryThumbnail(
                                    asset: photo,
                                    isSelected: selectedPhotos.contains(
                                        photo.localIdentifier
                                    )
                                ) {
                                    toggleSelection(photo)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("사진첩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 좌측 상단 닫기
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                // 우측 상단 삭제
                ToolbarItem(placement: .topBarTrailing) {
                    Button("삭제") {
                        deleteSelectedPhotos()
                    }
                    .foregroundStyle(.red)
                    .disabled(selectedPhotos.isEmpty)
                }
            }
            .alert(
                "사진 삭제 실패",
                isPresented: $showDeleteError
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("사진을 삭제하지 못했습니다. 다시 시도해 주세요.")
            }
            .onAppear {
                loadPhotos()
            }
        }
    }

    // 사진 선택 및 해제
    private func toggleSelection(_ photo: PHAsset) {
        let id = photo.localIdentifier

        if selectedPhotos.contains(id) {
            selectedPhotos.remove(id)
        } else {
            selectedPhotos.insert(id)
        }
    }

    // 사진첩 불러오기
    private func loadPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(
            for: .readWrite
        )

        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(
                for: .readWrite
            ) { newStatus in
                DispatchQueue.main.async {
                    hasPermission =
                        newStatus == .authorized ||
                        newStatus == .limited

                    fetchPhotos()
                }
            }
        } else {
            hasPermission =
                status == .authorized ||
                status == .limited

            fetchPhotos()
        }
    }

    // 사진 목록 가져오기
    private func fetchPhotos() {
        guard hasPermission else {
            isLoading = false
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(
                key: "creationDate",
                ascending: false
            )
        ]

        let result = PHAsset.fetchAssets(
            with: .image,
            options: options
        )

        var fetchedPhotos: [PHAsset] = []

        result.enumerateObjects { asset, _, _ in
            fetchedPhotos.append(asset)
        }

        photos = fetchedPhotos
        isLoading = false
    }

    // 선택한 사진 삭제
    private func deleteSelectedPhotos() {
        let selectedAssets = PHAsset.fetchAssets(
            withLocalIdentifiers: Array(selectedPhotos),
            options: nil
        )

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(
                selectedAssets
            )
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    selectedPhotos.removeAll()
                    fetchPhotos()
                } else {
                    print("사진 삭제 오류:", error?.localizedDescription ?? "")
                    showDeleteError = true
                }
            }
        }
    }
}

// MARK: - 사진 썸네일

private struct PhotoGalleryThumbnail: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(
                    width: thumbnailSize,
                    height: thumbnailSize
                )
                .clipped()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue, .white)
                        .padding(6)
                }
            }
            .overlay {
                if isSelected {
                    Rectangle()
                        .stroke(.blue, lineWidth: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
    }

    private var thumbnailSize: CGFloat {
        (UIScreen.main.bounds.width - 4) / 3
    }

    // 사진 썸네일 불러오기
    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(
                width: 300,
                height: 300
            ),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result {
                DispatchQueue.main.async {
                    image = result
                }
            }
        }
    }
}

// MARK: - 관심 행사 버튼

private struct InterestCategoryButton: View {
    let category: EventCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
