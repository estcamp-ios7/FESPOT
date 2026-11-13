//
//  TmapPlaceService.swift
//  FESPOT
//
//  TMAP 장소 도우미 (길찾기 출발지 고르기 화면에서 씀)
//
//  · 키는 길찾기와 같은 TMAP_API_KEY (TmapRouteService.apiKey)
//  ① 장소 검색 search(_:near:) — "강남역" → 이름 · 주소 · 좌표 목록
//     GET https://apis.openapi.sk.com/tmap/pois?version=1&searchKeyword=..
//     결과가 없으면 TMAP 이 HTTP 204(빈 응답)를 보내요 → 빈 배열
//     좌표는 "37.55326112" 처럼 글자로 와요. 입구 좌표(frontLat/Lon)를 먼저 쓰고, 없으면 중심 좌표(noorLat/Lon)
//  ② 좌표 → 주소 address(at:) — 지도에서 핀으로 고를 때 "세종대로 110 · 서울특별시청" 처럼 보여주려고
//     GET https://apis.openapi.sk.com/tmap/geo/reversegeocoding?version=1&lat=..&lon=..
//     응답의 addressInfo 에서 buildingName · roadName + buildingIndex · legalDong + bunji 를 골라 써요
//

import Foundation
import CoreLocation

// 길찾기 출발지 (지도에서 고른 곳)
struct StartPoint: Equatable {
    let name: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: StartPoint, rhs: StartPoint) -> Bool {
        lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

enum TmapPlaceService {
    // 검색 결과 장소 하나
    struct Place: Identifiable {
        let id: String
        let name: String              // 예: "강남역[수도권2호선]"
        let address: String           // 예: "서울 강남구 역삼동"
        let coordinate: CLLocationCoordinate2D
    }

    // =====================================================
    // ① 장소 검색 — near 가 있으면 그 근처 결과부터
    // =====================================================
    static func search(_ keyword: String, near: CLLocationCoordinate2D?) async throws -> [Place] {
        let trimmed = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        guard let key = TmapRouteService.apiKey else { throw TmapRouteError.noKey }
        guard var components = URLComponents(string: "https://apis.openapi.sk.com/tmap/pois") else { return [] }
        var items = [
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "searchKeyword", value: trimmed),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "reqCoordType", value: "WGS84GEO"),
            URLQueryItem(name: "resCoordType", value: "WGS84GEO")
        ]
        if let near {
            items += [URLQueryItem(name: "centerLat", value: String(near.latitude)),
                      URLQueryItem(name: "centerLon", value: String(near.longitude))]
        }
        components.queryItems = items
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "appKey")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TmapRouteError.network
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 204: return []                                        // 검색 결과 없음
        case 429: throw TmapRouteError.limit
        default: throw TmapRouteError.network
        }
        let pois = (try? JSONDecoder().decode(SearchEnvelope.self, from: data))?.searchPoiInfo.pois.poi ?? []
        return pois.compactMap { poi in
            guard let latitude = Double(poi.frontLat ?? "") ?? Double(poi.noorLat ?? ""),
                  let longitude = Double(poi.frontLon ?? "") ?? Double(poi.noorLon ?? ""),
                  latitude != 0, longitude != 0 else { return nil }
            let address = [poi.upperAddrName, poi.middleAddrName, poi.lowerAddrName].compactMap(clean).joined(separator: " ")
            return Place(id: poi.id ?? "\(poi.name ?? "")-\(latitude)-\(longitude)",
                         name: poi.name ?? trimmed, address: address,
                         coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
    }

    // =====================================================
    // ② 좌표 → 주소 (못 받으면 nil → 화면에선 "선택한 위치")
    // =====================================================
    static func address(at coordinate: CLLocationCoordinate2D) async -> String? {
        guard let key = TmapRouteService.apiKey,
              var components = URLComponents(string: "https://apis.openapi.sk.com/tmap/geo/reversegeocoding") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "coordType", value: "WGS84GEO"),
            URLQueryItem(name: "addressType", value: "A10")         // 도로명 · 지번 · 건물 이름 모두
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "appKey")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let info = try? JSONDecoder().decode(Envelope.self, from: data).addressInfo else { return nil }
        return label(info)
    }

    // "세종대로 110 · 서울특별시청" / 도로명이 없으면 "태평로1가 31"
    private static func label(_ info: AddressInfo) -> String? {
        let road = [info.roadName, info.buildingIndex].compactMap(clean).joined(separator: " ")
        let lot = [info.legalDong ?? info.adminDong, info.bunji].compactMap(clean).joined(separator: " ")
        let address = road.isEmpty ? lot : road
        let building = clean(info.buildingName)
        switch (address.isEmpty, building) {
        case (false, let name?): return "\(address) · \(name)"
        case (false, nil): return address
        case (true, let name?): return name
        case (true, nil): return nil
        }
    }

    private static func clean(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        return value
    }

    // ---------- 받은 JSON 을 풀어 담을 그릇 ----------
    // 장소 검색: { searchPoiInfo: { pois: { poi: [ ... ] } } }
    private struct SearchEnvelope: Decodable {
        struct Info: Decodable { let pois: Pois }
        struct Pois: Decodable { let poi: [Poi] }
        let searchPoiInfo: Info
    }

    private struct Poi: Decodable {
        let id: String?
        let name: String?
        let upperAddrName: String?
        let middleAddrName: String?
        let lowerAddrName: String?
        let frontLat: String?
        let frontLon: String?
        let noorLat: String?
        let noorLon: String?
    }

    // 좌표 → 주소: { addressInfo: { ... } }
    private struct Envelope: Decodable { let addressInfo: AddressInfo? }

    private struct AddressInfo: Decodable {
        let roadName: String?
        let buildingIndex: String?
        let buildingName: String?
        let legalDong: String?
        let adminDong: String?
        let bunji: String?
    }
}
