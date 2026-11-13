//
//  InfoRow.swift
//  FESPOT
//
//  "운영  10:00 – 22:00" 처럼 왼쪽 이름 + 오른쪽 값 한 줄
//

import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(Color.inkSub)
                .frame(width: 38, alignment: .leading)
            
            Text(value)
                .foregroundStyle(Color.ink)
        }
        .font(.subheadline)
    }
}
