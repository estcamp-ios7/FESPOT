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
        guard let r = text.range(of: pattern, options: .regularExpression) else { return nil }
        let found = String(text[r])
        let digits = found.filter(\.isNumber)
        guard (8...12).contains(digits.count), let url = URL(string: "tel:\(digits)") else { return nil }
        self.url = url
        self.display = PhoneNumber.format(digits)
    }

    // 숫자만 있는 번호에 "-" 넣기: 0212345678 → 02-1234-5678, 01012345678 → 010-1234-5678, 15881234 → 1588-1234
    static func format(_ d: String) -> String {
        let c = Array(d)
        func s(_ a: Int, _ b: Int) -> String { String(c[a..<b]) }
        if d.count == 8 { return "\(s(0, 4))-\(s(4, 8))" }                                // 대표번호
        if d.hasPrefix("02") {                                                             // 서울
            return d.count == 9 ? "02-\(s(2, 5))-\(s(5, 9))" : "02-\(s(2, 6))-\(s(6, c.count))"
        }
        if d.count == 10 { return "\(s(0, 3))-\(s(3, 6))-\(s(6, 10))" }
        if d.count == 11 { return "\(s(0, 3))-\(s(3, 7))-\(s(7, 11))" }
        return d
    }
}
