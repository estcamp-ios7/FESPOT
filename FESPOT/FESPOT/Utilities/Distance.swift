//
//  Distance.swift
//  FESPOT
//
//  거리 계산 · 거리 문구 만들기
//
//  · meters(start, end):      두 좌표 사이 거리(미터)
//  · distanceText(distance):  "도보 12분 · 900m" 처럼 보기 좋은 문구로
//  · defaultCenter:    내 위치를 모를 때 쓰는 기본 위치 (성수역 근처)
//  · seoulCenter:      앱을 켰을 때 지도가 처음 보여주는 곳 (서울시청)
//

import CoreLocation

let defaultCenter = CLLocationCoordinate2D(latitude: 37.5446, longitude: 127.0560)   // 위치 모를 때: 성수역 근처
let seoulCenter = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)     // 첫 화면 지도: 서울시청

func meters(_ start: CLLocationCoordinate2D, _ end: CLLocationCoordinate2D) -> Double {
    CLLocation(latitude: start.latitude, longitude: start.longitude).distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
}
// 2km 이하 = 도보(4.5km/h) · 20km 이하 = 시내 차량(25km/h) · 그 이상 = 장거리 차량(70km/h)
func distanceText(_ distance: Double) -> String {
    if distance > 3_000_000 { return "위치 정보 없음" }               // 좌표 없는 행사
    let distanceLabel = distance < 1000 ? "\(Int(distance))m" : (distance < 100_000 ? String(format: "%.1fkm", distance / 1000) : String(format: "%.0fkm", distance / 1000))
    if distance <= 2_000 { return "도보 \(minutesText(distance / 75)) · \(distanceLabel)" }
    if distance <= 20_000 { return "차로 \(minutesText(distance / 416)) · \(distanceLabel)" }
    return "차로 약 \(minutesText(distance / 1166)) · \(distanceLabel)"
}
func minutesText(_ minutes: Double) -> String {
    let totalMinutes = max(1, Int(minutes.rounded()))
    if totalMinutes < 60 { return "\(totalMinutes)분" }
    return totalMinutes % 60 == 0 ? "\(totalMinutes / 60)시간" : "\(totalMinutes / 60)시간 \(totalMinutes % 60)분"
}
