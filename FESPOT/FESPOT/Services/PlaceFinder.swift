//
//  PlaceFinder.swift
//  FESPOT
//
//  주소가 없는 행사의 시·군·구 찾기
//
//  순서: ① 장소 이름·제목 글자 → ② 그래도 없으면 포스터 이미지 속 글자 읽기(Apple Vision, 폰 안에서 처리)
//  예:  "국립현대미술관 서울" → 서울 · 종로 / 포스터에 "남원시" → 전북 · 남원
//  ※ 한 번 찾은 결과는 기기에 저장해서 다음엔 포스터를 다시 안 읽어요
//

import Foundation
import UIKit
import Vision

enum PlaceFinder {
    // ---------- ① 잘 알려진 공연장·미술관 (띄어쓰기 없이 비교) ----------
    static let venues: [(key: String, region: String, city: String)] = [
        ("국립현대미술관서울", "서울", "종로구"), ("국립현대미술관덕수궁", "서울", "중구"),
        ("국립현대미술관과천", "경기", "과천시"), ("국립현대미술관청주", "충북", "청주시"),
        ("국립중앙박물관", "서울", "용산구"), ("예술의전당", "서울", "서초구"), ("국립국악원", "서울", "서초구"),
        ("세종문화회관", "서울", "종로구"), ("국립극장", "서울", "중구"), ("동대문디자인플라자", "서울", "중구"),
        ("DDP", "서울", "중구"), ("롯데콘서트홀", "서울", "송파구"), ("블루스퀘어", "서울", "용산구"),
        ("국립아시아문화전당", "광주", "동구"), ("국립민속국악원", "전북", "남원시"),
        ("영화의전당", "부산", "해운대구"), ("국립부산국악원", "부산", "부산진구")
    ]

    // ---------- 시·도별 시·군·구 이름 ----------
    static let cities: [String: [String]] = [
        "서울": ["종로구","중구","용산구","성동구","광진구","동대문구","중랑구","성북구","강북구","도봉구","노원구","은평구","서대문구",
                "마포구","양천구","강서구","구로구","금천구","영등포구","동작구","관악구","서초구","강남구","송파구","강동구"],
        "부산": ["중구","서구","동구","영도구","부산진구","동래구","남구","북구","해운대구","사하구","금정구","강서구","연제구","수영구","사상구","기장군"],
        "대구": ["중구","동구","서구","남구","북구","수성구","달서구","달성군","군위군"],
        "인천": ["중구","동구","미추홀구","연수구","남동구","부평구","계양구","서구","강화군","옹진군"],
        "광주": ["동구","서구","남구","북구","광산구"],
        "대전": ["동구","중구","서구","유성구","대덕구"],
        "울산": ["중구","남구","동구","북구","울주군"],
        "경기": ["수원시","성남시","의정부시","안양시","부천시","광명시","평택시","동두천시","안산시","고양시","과천시","구리시",
                "남양주시","오산시","시흥시","군포시","의왕시","하남시","용인시","파주시","이천시","안성시","김포시","화성시",
                "광주시","양주시","포천시","여주시","연천군","가평군","양평군"],
        "강원": ["춘천시","원주시","강릉시","동해시","태백시","속초시","삼척시","홍천군","횡성군","영월군","평창군","정선군",
                "철원군","화천군","양구군","인제군","고성군","양양군"],
        "충북": ["청주시","충주시","제천시","보은군","옥천군","영동군","증평군","진천군","괴산군","음성군","단양군"],
        "충남": ["천안시","공주시","보령시","아산시","서산시","논산시","계룡시","당진시","금산군","부여군","서천군","청양군",
                "홍성군","예산군","태안군"],
        "전북": ["전주시","군산시","익산시","정읍시","남원시","김제시","완주군","진안군","무주군","장수군","임실군","순창군","고창군","부안군"],
        "전남": ["목포시","여수시","순천시","나주시","광양시","담양군","곡성군","구례군","고흥군","보성군","화순군","장흥군",
                "강진군","해남군","영암군","무안군","함평군","영광군","장성군","완도군","진도군","신안군"],
        "경북": ["포항시","경주시","김천시","안동시","구미시","영주시","영천시","상주시","문경시","경산시","의성군","청송군",
                "영양군","영덕군","청도군","고령군","성주군","칠곡군","예천군","봉화군","울진군","울릉군"],
        "경남": ["창원시","진주시","통영시","사천시","김해시","밀양시","거제시","양산시","의령군","함안군","창녕군","고성군",
                "남해군","하동군","산청군","함양군","거창군","합천군"],
        "제주": ["제주시","서귀포시"]
    ]
    static let sidoOrder = ["서울","경기","인천","부산","대구","광주","대전","울산","세종","강원","충북","충남","전북","전남","경북","경남","제주"]

    // 글자 속에서 (시·도, 짧은 시·군·구) 찾기. region이 "기타"가 아니면 그 시·도 안에서만 찾음
    static func find(in raw: String, region: String) -> (region: String, city: String)? {
        let text = raw.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        let known = region != "기타"

        for venue in venues where text.contains(venue.key) && (!known || venue.region == region) {
            return (venue.region, short(venue.city, sido: venue.region))
        }
        for sido in (known ? [region] : sidoOrder) {
            for full in cities[sido] ?? [] where text.contains(full) {
                return (sido, short(full, sido: sido))
            }
        }
        // 시·군은 못 찾았지만 시·도 이름은 보임 → 지역만이라도 바로잡기
        if !known, let sido = sidoOrder.first(where: { text.contains($0) }) { return (sido, "") }
        return nil
    }

    static func short(_ full: String, sido: String) -> String {
        TourAPI.withMetro(TourAPI.shortCity(full) ?? full, sido: sido)
    }

    // ---------- ② 포스터 이미지 속 글자 읽기 ----------
    static func readPoster(_ url: URL) async -> String? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return await Task.detached(priority: .utility) { PlaceFinder.ocr(data) }.value   // 화면 안 멈추게 뒤에서
    }

    nonisolated static func ocr(_ data: Data) -> String? {
        guard let cgImage = UIImage(data: data)?.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]     // 한국어 인식 (iOS 16 이상)
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }
}
