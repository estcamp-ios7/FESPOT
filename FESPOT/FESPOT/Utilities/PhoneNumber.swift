//
//  PhoneNumber.swift
//  FESPOT
//
//  API가 준 연락처 글자에서 전화번호 꺼내기
//
//  · API 연락처는 모양이 제각각이에요: "02-1234-5678" · "문의 061)123-4567" · "1588-1234, 010-1234-5678"
//  · 그중 첫 번째 전화번호만 꺼내서 보기 좋은 글자(display)와 전화 걸기 주소(url, "tel:0212345678")를 만들어요
//  · 쓰는 법: if let phone = PhoneNumber(from: "문의 02-1234-5678") { Link(destination: phone.url) { Text(phone.display) } }
//

import Foundation

struct PhoneNumber {
    let display: String        // 화면에 보여줄 번호 예: "02-1234-5678"
    let url: URL               // 누르면 전화 앱으로 넘어가는 주소 예: tel:0212345678

    init?(from text: String?) {
        guard let text, !text.isEmpty else { return nil }
        // 숫자 2~4자리 + (- ) . 공백) + 3~4자리 + 구분 + 4자리  /  또는 1588-1234 같은 대표번호
        let pattern = #"(\d{2,4})[\s\-\).]*(\d{3,4})[\s\-.]*(\d{4})|(1\d{3})[\s\-.]*(\d{4})"#
        guard let matchRange = text.range(of: pattern, options: .regularExpression) else { return nil }
        let found = String(text[matchRange])
        let digits = found.filter(\.isNumber)
        guard (8...12).contains(digits.count), let url = URL(string: "tel:\(digits)") else { return nil }
        self.url = url
        self.display = PhoneNumber.format(digits)
    }

    // 숫자만 있는 번호에 "-" 넣기: 0212345678 → 02-1234-5678, 01012345678 → 010-1234-5678, 15881234 → 1588-1234
    static func format(_ digits: String) -> String {
        let characters = Array(digits)
        func slice(_ start: Int, _ end: Int) -> String { String(characters[start..<end]) }
        if digits.count == 8 { return "\(slice(0, 4))-\(slice(4, 8))" }                                // 대표번호
        if digits.hasPrefix("02") {                                                             // 서울
            return digits.count == 9 ? "02-\(slice(2, 5))-\(slice(5, 9))" : "02-\(slice(2, 6))-\(slice(6, characters.count))"
        }
        if digits.count == 10 { return "\(slice(0, 3))-\(slice(3, 6))-\(slice(6, 10))" }
        if digits.count == 11 { return "\(slice(0, 3))-\(slice(3, 7))-\(slice(7, 11))" }
        return digits
    }
}
