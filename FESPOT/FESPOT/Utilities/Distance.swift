//
//  Distance.swift
//  FESPOT
//
//  거리 계산 · 거리 문구 만들기
//
//  · meters(a, b):     두 좌표 사이 거리(미터)
//  · distanceText(m):  "도보 12분 · 900m" 처럼 보기 좋은 문구로
//  · defaultCenter:    내 위치를 모를 때 쓰는 기본 위치 (성수역 근처)
//  · seoulCenter:      앱을 켰을 때 지도가 처음 보여주는 곳 (서울시청)
//

import CoreLocation

let defaultCenter = CLLocationCoordinate2D(latitude: 37.5446, longitude: 127.0560)   // 위치 모를 때: 성수역 근처
let seoulCenter = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)     // 첫 화면 지도: 서울시청

func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}
// 2km 이하 = 도보(4.5km/h) · 20km 이하 = 시내 차량(25km/h) · 그 이상 = 장거리 차량(70km/h)
func distanceText(_ m: Double) -> String {
    if m > 3_000_000 { return "위치 정보 없음" }               // 좌표 없는 행사
    let d = m < 1000 ? "\(Int(m))m" : (m < 100_000 ? String(format: "%.1fkm", m / 1000) : String(format: "%.0fkm", m / 1000))
    if m <= 2_000 { return "도보 \(minutesText(m / 75)) · \(d)" }
    if m <= 20_000 { return "차로 \(minutesText(m / 416)) · \(d)" }
    return "차로 약 \(minutesText(m / 1166)) · \(d)"
}
func minutesText(_ minutes: Double) -> String {
    let t = max(1, Int(minutes.rounded()))
    if t < 60 { return "\(t)분" }
    return t % 60 == 0 ? "\(t / 60)시간" : "\(t / 60)시간 \(t % 60)분"
}
