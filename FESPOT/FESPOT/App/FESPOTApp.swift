//
//  FESPOTApp.swift
//  FESPOT
//
//  Created by Ned Park on 11/9/26.
//
//  앱의 시작점 (@main) — 앱이 켜지면 가장 먼저 실행되는 곳
//  · WindowGroup 안에 있는 ContentView 가 첫 화면이 돼요 (App/ContentView.swift)
//
//  📁 폴더 구성 (처음 보는 분은 이 순서로 읽어보세요)
//  · App/         앱 시작점 · 하단 탭 뼈대
//  · Models/      데이터 '모양' (행사 · 카테고리 · 프로필 · 상태 계산)
//  · Data/        예시 행사 데이터
//  · Stores/      앱 전체가 같이 쓰는 데이터 창고 (EventStore)
//  · Services/    인터넷 API · 위치 · 포스터 글자 읽기
//  · Utilities/   거리 계산 · 문자열 정리 같은 작은 도우미
//  · Design/      색
//  · Views/       화면들 (탭별 폴더 + Components = 여러 화면에서 같이 쓰는 부품)
//


import SwiftUI
import UserNotifications

@main
struct FESPOTApp: App {
    init() {
        // 앱을 보고 있을 때도 알림 배너가 뜨게 (Services/Notifier.swift)
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
