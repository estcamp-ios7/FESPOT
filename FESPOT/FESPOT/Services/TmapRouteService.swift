//
//  TmapRouteService.swift
//  FESPOT
//
//  TMAP(SK open API) 길찾기 — 내 위치에서 행사까지 도보 · 자동차 경로 받아오기
//
//  · 키 설정: Info.plist 의 TMAP_API_KEY (SK open API → My Project → App Key)
//  · 흐름: 출발·도착 좌표를 POST 로 보내기 → GeoJSON 응답 받기 → 경로선 좌표 · 단계별 안내 · 총 시간/거리로 정리
//  · 응답 모양 (FeatureCollection)
//      Point      = 안내 지점 (예: "시청역 4번출구에서 좌회전 후 세종대로를 따라 155m 이동")
//                   첫 번째 Point 에만 totalDistance(m) · totalTime(초) 가 들어 있어요
//      LineString = 안내 지점 사이의 길 (좌표 묶음) → 순서대로 이어 붙이면 전체 경로선
//  · ⚠️ TMAP 좌표는 [경도, 위도] 순서예요 (위도, 경도가 아님!)
//

import Foundation
import CoreLocation

// 이동 수단
enum RouteMode: String, CaseIterable, Identifiable {
    case walk = "도보", car = "자동차"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .car: return "car.fill"
        }
    }

    // TMAP 주소 (도보와 자동차가 서로 달라요)
    var endpoint: String {
        switch self {
        case .walk: return "https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1"
        case .car: return "https://apis.openapi.sk.com/tmap/routes?version=1"
        }
    }
}

// 안내 한 단계 (예: "120m 앞에서 우회전")
struct RouteStep: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let instruction: String
}

// 경로 하나 = 지도에 그릴 선 + 단계별 안내 + 총 거리·시간
struct TmapRoute {
    let mode: RouteMode
    let coordinates: [CLLocationCoordinate2D]
    let steps: [RouteStep]
    let totalDistance: Double        // 미터
    let totalTime: Double            // 초

    var summary: String { "\(minutesText(totalTime / 60)) · \(TmapRoute.distanceLabel(totalDistance))" }

    static func distanceLabel(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters))m" : String(format: "%.1fkm", meters / 1000)
    }
}

// 화면에 보여줄 오류 문구
enum TmapRouteError: LocalizedError {
    case noKey, network, limit, noRoute(String?)

    var errorDescription: String? {
        switch self {
        case .noKey: return "TMAP 키가 없어요 (Info.plist 의 TMAP_API_KEY 를 확인해 주세요)"
        case .network: return "인터넷 연결을 확인해 주세요"
        case .limit: return "오늘 길찾기 사용량을 다 썼어요. 잠시 후 다시 시도해 주세요"
        case .noRoute(let message): return "경로를 찾지 못했어요" + (message.map { " (\($0))" } ?? "")
        }
    }
}

enum TmapRouteService {
    static var apiKey: String? {
        let key = Bundle.main.object(forInfoDictionaryKey: "TMAP_API_KEY") as? String
        return (key ?? "").isEmpty ? nil : key
    }

    // 한 번 받은 경로는 기억해 두기 (탭을 바꿀 때마다 다시 요청하면 무료 사용량이 빨리 닳아요)
    private static var cache: [String: TmapRoute] = [:]

    // 출발 위치는 소수점 4자리(약 10m)까지만 비교 → 조금 움직인 정도는 같은 경로로 봐요
    private static func cacheKey(_ start: CLLocationCoordinate2D, _ event: EventItem, _ mode: RouteMode) -> String {
        String(format: "%@|%@|%.4f|%.4f", mode.rawValue, event.id, start.latitude, start.longitude)
    }

    // 경로 받기. refresh: true 면 기억해 둔 경로를 무시하고 새로 받아요 (경로를 벗어났을 때)
    static func route(from start: CLLocationCoordinate2D, to event: EventItem, mode: RouteMode,
                      refresh: Bool = false) async throws -> TmapRoute {
        guard let key = apiKey else { throw TmapRouteError.noKey }
        let cacheID = cacheKey(start, event, mode)
        if !refresh, let saved = cache[cacheID] { return saved }

        guard let url = URL(string: mode.endpoint) else { throw TmapRouteError.network }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "appKey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 출발·도착 이름은 TMAP 규칙상 URL 인코딩해서 보내요
        let startName = "내 위치".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let endName = event.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body: [String: Any] = [
            "startX": start.longitude, "startY": start.latitude,
            "endX": event.longitude, "endY": event.latitude,
            "startName": startName, "endName": endName,
            "reqCoordType": "WGS84GEO", "resCoordType": "WGS84GEO"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TmapRouteError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 429 { throw TmapRouteError.limit }
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message
            throw TmapRouteError.noRoute(message)
        }

        let collection: FeatureCollection
        do {
            collection = try JSONDecoder().decode(FeatureCollection.self, from: data)
        } catch {
            throw TmapRouteError.noRoute(nil)
        }
        let route = makeRoute(collection, mode: mode)
        guard route.coordinates.count >= 2 else { throw TmapRouteError.noRoute(nil) }
        cache[cacheID] = route
        return route
    }

    // GeoJSON → 우리 앱의 TmapRoute 로 정리
    private static func makeRoute(_ collection: FeatureCollection, mode: RouteMode) -> TmapRoute {
        var coordinates: [CLLocationCoordinate2D] = []
        var steps: [RouteStep] = []
        var totalDistance = 0.0, totalTime = 0.0

        for feature in collection.features {
            switch feature.geometry.coordinates {
            case .point(let pair):
                guard let point = coordinate(pair) else { continue }
                if let distance = feature.properties.totalDistance { totalDistance = distance }
                if let time = feature.properties.totalTime { totalTime = time }
                let text = (feature.properties.description ?? "").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    steps.append(RouteStep(id: steps.count, coordinate: point, instruction: text))
                }
            case .line(let pairs):
                for pair in pairs {
                    guard let point = coordinate(pair) else { continue }
                    // 앞 선의 끝점과 다음 선의 시작점이 같으면 한 번만
                    if let last = coordinates.last, last.latitude == point.latitude, last.longitude == point.longitude { continue }
                    coordinates.append(point)
                }
            }
        }
        return TmapRoute(mode: mode, coordinates: coordinates, steps: steps,
                         totalDistance: totalDistance, totalTime: totalTime)
    }

    // [경도, 위도] → CLLocationCoordinate2D
    private static func coordinate(_ pair: [Double]) -> CLLocationCoordinate2D? {
        guard pair.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
    }

    // ---------- 받은 JSON 을 풀어 담을 그릇들 ----------
    private struct FeatureCollection: Decodable { let features: [Feature] }

    private struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties
    }

    private struct Geometry: Decodable {
        let coordinates: Coordinates
    }

    // Point 는 [경도, 위도], LineString 은 [[경도, 위도], ...] 라서 둘 다 받을 수 있게
    private enum Coordinates: Decodable {
        case point([Double])
        case line([[Double]])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let pairs = try? container.decode([[Double]].self) { self = .line(pairs); return }
            self = .point(try container.decode([Double].self))
        }
    }

    private struct Properties: Decodable {
        let totalDistance: Double?
        let totalTime: Double?
        let description: String?
    }

    // 오류 응답: { "error": { "code": "INVALID_API_KEY", "message": "Forbidden" } }
    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable { let message: String? }
        let error: Body
    }
}
