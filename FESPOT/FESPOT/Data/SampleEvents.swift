//
//  SampleEvents.swift
//  FESPOT
//
//  발표·테스트용 예시 행사 데이터
//
//  · API 키가 없거나 인터넷 불러오기에 실패하면 이 목록이 대신 보여요
//  · 새 예시를 넣고 싶으면 EventItem(...) 한 줄을 복사해서 값만 바꾸면 돼요
//

import Foundation

// 발표용 예시 행사
let sampleEvents: [EventItem] = [
    // 서울
    EventItem(id: "night-market", title: "한강 야시장", category: .festival, region: "서울", place: "뚝섬한강공원 일대",
              latitude: 37.5297, longitude: 127.0670, days: [.today, .sat], startHour: 18, endHour: 22,
              period: "[시작일] – [종료일] · 매주 금·토", price: "[입장료 / 무료]"),
    EventItem(id: "jazz-park", title: "재즈 인 더 파크", category: .concert, region: "서울", place: "서울숲 야외무대",
              latitude: 37.5444, longitude: 127.0374, days: [.today, .sat, .sun], startHour: 19, endHour: 21,
              period: "[시작일] – [종료일]", price: "[입장료]"),
    EventItem(id: "vintage-market", title: "빈티지 플리마켓", category: .market, region: "서울", place: "성수동 카페거리",
              latitude: 37.5446, longitude: 127.0560, days: [.today, .sat, .sun], startHour: 12, endHour: 19,
              period: "[시작일] – [종료일] · 주말", price: "무료"),
    EventItem(id: "media-art", title: "미디어아트 전시", category: .exhibit, region: "서울", place: "성수 복합문화공간",
              latitude: 37.5470, longitude: 127.0440, days: [.today, .tomorrow, .sat, .sun], startHour: 10, endHour: 20,
              period: "[시작일] – [종료일]", price: "[관람료]"),
    EventItem(id: "food-festa", title: "골목 푸드 페스타", category: .food, region: "서울", place: "성수 연무장길",
              latitude: 37.5410, longitude: 127.0600, days: [.tomorrow, .sat, .sun], startHour: 16, endHour: 23,
              period: "[시작일] – [종료일]", price: "무료 (음식 별도)"),
    EventItem(id: "night-tour", title: "불꽃 야경 투어", category: .night, region: "서울", place: "응봉산 전망대",
              latitude: 37.5520, longitude: 127.0330, days: [.sat], startHour: 20, endHour: 22,
              period: "[날짜] 하루", price: "[참가비]"),
    // 경기
    EventItem(id: "suwon-night", title: "성곽 야간 산책", category: .night, region: "경기", place: "수원 화성 일대",
              latitude: 37.2871, longitude: 127.0119, days: [.today, .tomorrow, .sat, .sun], startHour: 19, endHour: 22,
              period: "[시작일] – [종료일]", price: "무료"),
    EventItem(id: "paju-book", title: "출판도시 책 마켓", category: .market, region: "경기", place: "파주 출판도시",
              latitude: 37.7120, longitude: 126.6880, days: [.sat, .sun], startHour: 11, endHour: 18,
              period: "[시작일] – [종료일] · 주말", price: "무료"),
    // 인천
    EventItem(id: "wolmi-busking", title: "바다 버스킹 나이트", category: .concert, region: "인천", place: "월미도 문화의거리",
              latitude: 37.4752, longitude: 126.5970, days: [.sat, .sun], startHour: 17, endHour: 21,
              period: "[시작일] – [종료일]", price: "무료"),
    EventItem(id: "songdo-food", title: "센트럴파크 푸드 페어", category: .food, region: "인천", place: "송도 센트럴파크",
              latitude: 37.3925, longitude: 126.6390, days: [.tomorrow, .sat], startHour: 16, endHour: 22,
              period: "[시작일] – [종료일]", price: "무료 (음식 별도)"),
    // 부산
    EventItem(id: "gwangalli-drone", title: "바다 위 드론 라이트쇼", category: .night, region: "부산", place: "광안리 해수욕장",
              latitude: 35.1532, longitude: 129.1187, days: [.sat], startHour: 20, endHour: 21,
              period: "[날짜]", price: "무료"),
    EventItem(id: "haeundae-sand", title: "모래 조각 페스티벌", category: .festival, region: "부산", place: "해운대 해수욕장",
              latitude: 35.1587, longitude: 129.1604, days: [.sat, .sun], startHour: 10, endHour: 18,
              period: "[시작일] – [종료일]", price: "무료"),
    // 강원
    EventItem(id: "gangneung-coffee", title: "커피 거리 축제", category: .food, region: "강원", place: "강릉 안목해변",
              latitude: 37.7700, longitude: 128.9480, days: [.sat, .sun], startHour: 10, endHour: 18,
              period: "[시작일] – [종료일]", price: "[체험비]"),
    EventItem(id: "sokcho-market", title: "항구 야시장", category: .market, region: "강원", place: "속초 중앙시장 일대",
              latitude: 38.2070, longitude: 128.5918, days: [.today, .sat], startHour: 18, endHour: 23,
              period: "[시작일] – [종료일]", price: "무료"),
    // 제주
    EventItem(id: "jeju-tangerine", title: "감귤 따기 체험 마켓", category: .market, region: "제주", place: "서귀포 농장 일대",
              latitude: 33.2541, longitude: 126.5600, days: [.today, .tomorrow, .sat, .sun], startHour: 10, endHour: 17,
              period: "[시작일] – [종료일]", price: "[체험비]"),
    EventItem(id: "jeju-art", title: "섬 미디어아트 전시", category: .exhibit, region: "제주", place: "제주시 전시관",
              latitude: 33.4996, longitude: 126.5312, days: [.today, .tomorrow, .sat, .sun], startHour: 10, endHour: 19,
              period: "[시작일] – [종료일]", price: "[관람료]")
]
