//
//  MapSearchView.swift
//  FESPOT
//
//  지도 탭의 검색창을 누르면 화면 가득 열리는 검색 화면
//
//  · 글자를 안 쳤을 때: 최근 검색어 목록 (누르면 다시 검색, X로 하나씩 지우기)
//  · 글자를 쳤을 때:   검색 결과 목록 (누르면 지도로 돌아가서 그 행사 위치로 이동)
//  · 키보드의 '검색' 버튼: 그 검색어에 맞는 행사만 지도에 보여주기
//  · 최근 검색어는 @AppStorage 로 기기에 저장돼서 앱을 껐다 켜도 남아요
//

import SwiftUI

struct MapSearchView: View {
    @EnvironmentObject var store: EventStore
    @Environment(\.dismiss) private var dismiss
    let initialQuery: String                            // 지도에서 이미 쳐 둔 검색어 (있으면 이어서 수정)
    let onSubmit: (String) -> Void                      // 검색어로 지도 보기
    let onSelect: (EventItem) -> Void                   // 결과 하나 고르기

    @State private var text = ""
    @FocusState private var focused: Bool
    // 최근 검색어: 배열은 바로 저장이 안 돼서 줄바꿈("\n")으로 이어 붙인 글자 하나로 저장
    @AppStorage("recentSearches") private var recentRaw = ""

    var recents: [String] { recentRaw.split(separator: "\n").map(String.init) }

    var trimmed: String { text.trimmingCharacters(in: .whitespaces) }

    // 위치가 있는 행사 중 검색어에 걸리는 것 (지도에서 볼 수 있는 것만)
    var results: [EventItem] {
        store.events.filter { $0.latitude != 0 && $0.matches(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if trimmed.isEmpty {
                recentList
            } else {
                resultList
            }
        }
        .background(Color.paper.ignoresSafeArea())
        .onAppear {
            text = initialQuery
            focused = true                              // 열리자마자 키보드 올리기
        }
    }

    // ---------- 맨 위: ‹ 뒤로 + 입력창 ----------
    var searchBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.semibold)).foregroundStyle(Color.ink)
                    .frame(width: 32, height: 44)
            }
            .accessibilityLabel("뒤로")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.inkSub)
                TextField("행사·장소·지역·종류 검색 (예: 뮤지컬, 커피, 부산)", text: $text)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { submit(trimmed) }
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.inkSub)
                    }
                    .accessibilityLabel("검색어 지우기")
                }
            }
            .padding(.horizontal, 14).frame(height: 48)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2)))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // ---------- 글자 없을 때: 최근 검색 ----------
    var recentList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("최근 검색").font(.headline).foregroundStyle(Color.ink)
                    Spacer()
                    if !recents.isEmpty {
                        Button("전체 삭제") { recentRaw = "" }
                            .font(.subheadline).foregroundStyle(Color.inkSub)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 14)

                if recents.isEmpty {
                    Text("최근 검색한 내용이 없어요").font(.subheadline).foregroundStyle(Color.inkSub)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                }
                ForEach(recents, id: \.self) { word in
                    HStack(spacing: 12) {
                        // 줄 전체를 누르면 그 검색어로 다시 검색
                        Button { submit(word) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath").foregroundStyle(Color.inkSub)
                                    .frame(width: 32, height: 32)
                                    .background(Color.gray.opacity(0.12), in: Circle())
                                Text(word).font(.body).foregroundStyle(Color.ink).lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button { removeRecent(word) } label: {
                            Image(systemName: "xmark").font(.subheadline).foregroundStyle(Color.inkSub)
                                .frame(width: 32, height: 32)
                        }
                        .accessibilityLabel("\(word) 삭제")
                    }
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    Divider().padding(.leading, 64)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)        // 목록을 끌어내리면 키보드 내려가기
    }

    // ---------- 글자 있을 때: 검색 결과 ----------
    var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if results.isEmpty {
                    Text("검색 결과가 없어요").font(.subheadline).foregroundStyle(Color.inkSub)
                        .padding(20)
                }
                ForEach(results) { e in
                    Button { select(e) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: e.category.icon).font(.subheadline).foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(e.category.color, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.title).font(.body.bold()).foregroundStyle(Color.ink)
                                    .lineLimit(1).truncationMode(.tail)
                                Text("\(e.placeTypeLabel) · \(e.dateRange)").font(.caption).foregroundStyle(Color.inkSub)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "location.fill").font(.caption).foregroundStyle(Color.inkSub)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 68)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // ---------- 동작 ----------
    // 검색어로 지도 보기 → 최근 검색에 저장하고 닫기
    func submit(_ word: String) {
        let w = word.trimmingCharacters(in: .whitespaces)
        if !w.isEmpty { addRecent(w) }
        onSubmit(w)
        dismiss()
    }

    // 결과 하나 고르기 → 행사 이름을 최근 검색에 저장하고 닫기
    func select(_ e: EventItem) {
        addRecent(e.title)
        onSelect(e)
        dismiss()
    }

    // 같은 검색어는 맨 위로 올리고, 최대 15개까지만 기억
    func addRecent(_ word: String) {
        let list = [word] + recents.filter { $0 != word }
        recentRaw = list.prefix(15).joined(separator: "\n")
    }

    func removeRecent(_ word: String) {
        recentRaw = recents.filter { $0 != word }.joined(separator: "\n")
    }
}

// 이름·장소·지역·종류·세부유형 어디든 걸리면 검색 결과 (지도 · 검색 화면에서 같이 씀)
extension EventItem {
    func matches(_ query: String) -> Bool {
        let t = query.trimmingCharacters(in: .whitespaces)
        return [title, place, region, category.rawValue, subType].contains { $0.localizedCaseInsensitiveContains(t) }
    }
}
