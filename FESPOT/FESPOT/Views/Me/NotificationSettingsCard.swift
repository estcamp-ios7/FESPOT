//
//  NotificationSettingsCard.swift
//  FESPOT
//
//  내 정보 탭의 '알림 설정' 카드 — 근처 · 관심 알림을 하나씩 켜고 끄기
//
//  · @AppStorage 로 저장돼서 앱을 껐다 켜도 그대로예요 (기본값 = 모두 켜짐)
//  · 실제 알림을 보내는 쪽은 Services/Notifier.swift 이고, 같은 키 이름으로 설정을 읽어가요
//  · 아이폰 설정에서 알림을 꺼 두면 여기서 켜도 안 와요 → 그럴 땐 안내와 [설정 열기] 버튼이 떠요
//

import SwiftUI

struct NotificationSettingsCard: View {
    @EnvironmentObject var store: EventStore
    @AppStorage(Notifier.Kind.nearby.rawValue) private var nearby = true
    @AppStorage(Notifier.Kind.interest.rawValue) private var interest = true
    @State private var denied = false                   // 아이폰 설정에서 알림이 꺼져 있나?
    @State private var previewSent = false

    // Kind 하나에 맞는 스위치 값 연결
    func binding(_ kind: Notifier.Kind) -> Binding<Bool> {
        switch kind {
        case .nearby: return $nearby
        case .interest: return $interest
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("알림 설정").font(.headline)

            ForEach(Notifier.Kind.allCases) { kind in
                Toggle(isOn: binding(kind)) {
                    HStack(spacing: 12) {
                        Image(systemName: kind.icon).font(.title3).foregroundStyle(Color.coral)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title).font(.subheadline.bold()).foregroundStyle(Color.ink)
                            Text(kind.detail).font(.caption).foregroundStyle(Color.inkSub)
                        }
                    }
                }
                .tint(Color.liveGreen)
                if kind != Notifier.Kind.allCases.last { Divider() }
            }

            // 아이폰 설정에서 알림을 꺼 둔 경우
            if denied {
                HStack(spacing: 8) {
                    Image(systemName: "bell.slash.fill").foregroundStyle(Color.coral)
                    Text("아이폰 설정에서 알림이 꺼져 있어요").font(.caption).foregroundStyle(Color.ink)
                    Spacer()
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .font(.caption.bold())
                }
                .padding(10)
                .background(Color.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            // 켜 둔 알림이 어떻게 오는지 바로 확인 (2초 뒤부터 차례로 도착)
            Button {
                Task {
                    await Notifier.sendPreview(events: store.events, profile: store.profile)
                    denied = await Notifier.permissionDenied()
                    previewSent = !denied
                }
            } label: {
                Label(previewSent ? "알림을 보냈어요 · 잠시 기다려 주세요" : "알림 미리 보기", systemImage: "bell.badge")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35)))
                    .foregroundStyle(Color.ink)
            }
            .buttonStyle(.plain)
            .disabled(!(nearby || interest))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .task { denied = await Notifier.permissionDenied() }
        // 스위치를 켜면 알림 권한 묻기
        .onChange(of: nearby) { _, on in if on { askPermission() } }
        .onChange(of: interest) { _, on in if on { askPermission() } }
    }

    func askPermission() {
        Task {
            _ = await Notifier.requestPermission()
            denied = await Notifier.permissionDenied()
        }
    }
}
