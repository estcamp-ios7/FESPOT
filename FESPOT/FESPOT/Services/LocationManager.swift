//
//  LocationManager.swift
//  FESPOT
//
//  내 현재 위치 받아오기 (CoreLocation)
//
//  · ⚠️ TARGETS → Info → "Privacy - Location When In Use Usage Description" 이 꼭 있어야 위치 권한 창이 떠요
//  · 위치가 바뀌면 coordinate 가 바뀌고(@Published) → 지도·거리 표시가 자동으로 갱신돼요
//

import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 30
    }
    // 위치 권한을 물어보고 위치 받기 시작
    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    // ↓ 아래 함수들은 iOS가 알아서 불러줘요 (delegate = '일이 생기면 나한테 알려줘')
    // 권한이 바뀌었을 때 (사용자가 '허용'을 누르면 여기로 옴)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    // 새 위치가 들어왔을 때
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }
    // 위치를 못 받았을 때 (지금은 따로 처리 안 함 → defaultCenter 를 씀)
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
