
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
        .fullScreenCover(
            isPresented: $isShowingPhotoDeleteView
        ) {
            ProfilePhotoDeleteView(
                onSelect: { selectedPhoto in
                    // 선택한 사진으로 프로필 사진 변경
                    draft.photo = selectedPhoto
                    photoItem = nil
                    isShowingPhotoDeleteView = false
                },
                onDelete: {
                    // 프로필 사진 제거
                    draft.photo = nil
                    photoItem = nil
                    isShowingPhotoDeleteView = false
                }
            )
        }
    }
}

// MARK: - 프로필 사진 삭제 및 변경 화면

private struct ProfilePhotoDeleteView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Data) -> Void
    let onDelete: () -> Void

    @State private var photos: [PHAsset] = []
    @State private var hasPermission = false
    @State private var permissionDenied = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if hasPermission {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(
                                photos,
                                id: \.localIdentifier
                            ) { asset in

                                PhotoThumbnail(asset: asset) {
                                    selectPhoto(asset)
                                }
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                            }
                        }
                    }
                } else if permissionDenied {
                    ContentUnavailableView(
                        "사진 접근 권한이 필요합니다",
                        systemImage: "photo",
                        description: Text(
                            "설정에서 FESPOT의 사진 접근을 허용해 주세요."
                        )
                    )
                } else {
                    ProgressView("사진첩 불러오는 중...")
                }
            }
            .navigationTitle("사진첩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 좌측 상단 취소
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                // 우측 상단 삭제
                ToolbarItem(placement: .topBarTrailing) {
                    Button("삭제", role: .destructive) {
                        onDelete()
                    }
                }
            }
            .task {
                loadPhotos()
            }
        }
    }

    // MARK: 사진첩 접근 권한 확인

    private func loadPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(
            for: .readWrite
        )

        if status == .authorized || status == .limited {
            fetchPhotos()

        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(
                for: .readWrite
            ) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized ||
                        newStatus == .limited {
                        fetchPhotos()
                    } else {
                        permissionDenied = true
                    }
                }
            }
        } else {
            permissionDenied = true
        }
    }

    // MARK: 사진 목록 가져오기

    private func fetchPhotos() {
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
        hasPermission = true
    }

    // MARK: 선택한 사진을 프로필에 적용

    private func selectPhoto(_ asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current

        PHImageManager.default().requestImageDataAndOrientation(
            for: asset,
            options: options
        ) { data, _, _, _ in

            guard let data,
                  let image = UIImage(data: data),
                  let jpegData = image.jpegData(
                    compressionQuality: 0.6
                  ) else {
                return
            }

            DispatchQueue.main.async {
                onSelect(jpegData)
            }
        }
    }
}

// MARK: - 사진첩 썸네일

private struct PhotoThumbnail: View {
    let asset: PHAsset
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button {
            onTap()
        } label: {
            GeometryReader { geometry in
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipped()
                .onAppear {
                    loadThumbnail(size: geometry.size)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // 썸네일 이미지 불러오기
    private func loadThumbnail(size: CGSize) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(
                width: size.width * 2,
                height: size.height * 2
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
