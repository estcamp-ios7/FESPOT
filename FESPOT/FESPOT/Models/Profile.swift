//
//  Profile.swift
//  FESPOT
//
//  내 프로필 정보 (닉네임 · 사는 곳 · 관심 카테고리 · 반경 · 사진)
//
//  · Codable 이라서 JSON으로 바꿔 기기(UserDefaults)에 저장할 수 있어요 → EventStore.swift 참고
//

import Foundation

struct Profile: Codable, Equatable {
    var nickname = ""
    var sido = "서울"
    var detail = ""                          // 구·동
    var interests: [EventCategory] = []
    var radiusKm = 3
    var photo: Data? = nil
}
