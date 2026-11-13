//
//  String+HTML.swift
//  FESPOT
//
//  문자열 도우미 — API가 보내는 HTML 특수문자(&lt; &amp; 등)를 원래 글자로 되돌리기
//
//  · 쓰는 법: "MMCA&times;LG".htmlDecoded  →  "MMCA×LG"
//

import Foundation

// HTML 특수문자 되돌리기: "MMCA&times;LG" → "MMCA×LG", "&lt;네이처&gt;" → "<네이처>"
extension String {
    var htmlDecoded: String {
        // 순서가 지켜지는 배열 (사전은 순서가 랜덤이라 안 됨) — &amp; 는 반드시 마지막
        let map: [(String, String)] = [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
                   ("&times;", "×"), ("&middot;", "·"), ("&nbsp;", " "), ("&lsquo;", "‘"), ("&rsquo;", "’"),
                   ("&ldquo;", "“"), ("&rdquo;", "”"), ("&hellip;", "…"), ("&amp;", "&")]
        var result = self
        for (entity, character) in map { result = result.replacingOccurrences(of: entity, with: character) }
        return result
    }
}
