//
//  Avatar.swift
//  FESPOT
//
//  동그란 프로필 사진 — 사진이 없으면 닉네임 첫 글자를 보여줘요
//

import SwiftUI

struct Avatar: View {
    let profile: Profile
    var size: CGFloat = 72
    var body: some View {
        Group {
            if let d = profile.photo, let ui = UIImage(data: d) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Text(String(profile.nickname.prefix(1)).isEmpty ? "?" : String(profile.nickname.prefix(1)))
                    .font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.coral)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
