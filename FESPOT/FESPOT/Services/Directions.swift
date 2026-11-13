//
//  Directions.swift
//  FESPOT
//
//  길찾기 — 네이버 지도 · 카카오맵 · Apple 지도 앱 열기
//
//  · 다른 앱은 'URL 스킴'으로 열어요 (웹 주소처럼 생겼는데 https:// 대신 nmap:// , kakaomap:// 로 시작)
//  · 출발지를 안 넣으면 각 지도 앱이 '현재 위치'를 출발지로 써요
//  · 앱이 설치돼 있지 않으면 열기가 실패 → App Store 설치 화면으로 보내요
//  · 행사 좌표가 없으면(위도 0) 길찾기 대신 장소 이름으로 검색해요
//

import UIKit
import CoreLocation
import MapKit

enum MapApp: String, CaseIterable, Identifiable {
    case naver = "네이버 지도", kakao = "카카오맵", apple = "Apple 지도"
    var id: String { rawValue }
    
    // App Store 설치 화면 주소
    var appStoreURL: URL? {
        switch self {
        case .naver: return URL(string: "https://apps.apple.com/kr/app/id311867728")
        case .kakao: return URL(string: "https://apps.apple.com/kr/app/id304608425")
        case .apple: return nil                                       // 아이폰에 기본으로 있음
        }
    }
    
    // 이 지도 앱을 여는 주소 만들기
    // walk: true = 도보, false = 자동차 (가까우면 도보로 여는 게 자연스러워서 거리로 정해요)
    func url(for event: EventItem, walk: Bool) -> URL? {
        let name = event.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let place = event.place.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let hasCoord = event.latitude != 0
        let lat = event.latitude, lon = event.longitude
        
        switch self {
        case .naver:
            // appname: 네이버가 "어느 앱에서 불렀는지" 알기 위한 값 (우리 앱 번들 ID)
            let app = Bundle.main.bundleIdentifier ?? "FESPOT"
            return hasCoord
            ? URL(string: "nmap://route/\(walk ? "walk" : "car")?dlat=\(lat)&dlng=\(lon)&dname=\(name)&appname=\(app)")
            : URL(string: "nmap://search?query=\(place)&appname=\(app)")
        case .kakao:
            return hasCoord
            ? URL(string: "kakaomap://route?ep=\(lat),\(lon)&by=\(walk ? "FOOT" : "CAR")")
            : URL(string: "kakaomap://search?q=\(place)")
        case .apple:
            return nil                                                // Apple 지도는 아래 open() 에서 MapKit 으로 직접 열어요
        }
    }
    
    // 지도 앱 열기 (설치 안 돼 있으면 App Store로)
    @MainActor
    func open(for event: EventItem, walk: Bool) async {
        if self == .apple {
            if event.latitude != 0 {
                // 1. 행사 좌표로 CLLocation 생성
                let location = CLLocation(
                    latitude: event.coordinate.latitude,
                    longitude: event.coordinate.longitude
                )
                
                // 2. 새로운 초기화 방식으로 MKMapItem 생성
                let item = MKMapItem(
                    location: location,
                    address: nil
                )
                
                // 3. 행사 이름 설정
                item.name = event.title
                
                // 4. Apple 지도 실행 및 이동 경로 설정
                item.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey:
                        walk
                    ? MKLaunchOptionsDirectionsModeWalking
                    : MKLaunchOptionsDirectionsModeDriving
                ])
                
            } else if let q = event.place.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ),
                      let u = URL(string: "maps://?q=\(q)") {
                await UIApplication.shared.open(u)
            }
            
            return
        }
    }
}
