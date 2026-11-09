import SwiftUI

/// W6 一篇的標籤（2026-11-09）：上面打新的，下面列出用過的，點一下加上或拿掉；按「完成」才存。
struct TagEditorSheet: View {
    /// 標籤最多幾個字：清單列上要放得下。
    static let maxTagLength = 20

    /// 其他篇用過的標籤，讓人點選，不用每次重打。
    let knownTags: [String]
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tags: [String]
    @State private var newTag = ""
    /// 打太長被擋下來時說一聲，字留在框裡給人改。
    @State private var isTooLong = false

    init(tags: [String], knownTags: [String], onSave: @escaping ([String]) -> Void) {
        _tags = State(initialValue: tags)
        self.knownTags = knownTags
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("新標籤", text: $newTag)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(addNewTag)
                } footer: {
                    Text(isTooLong ? "標籤最多 \(Self.maxTagLength) 個字，改短一點。" :
                        "例如：讀書心得、課程、Podcast。打完按鍵盤的完成就加上。")
                        .foregroundStyle(isTooLong ? Token.Colors.danger : Token.Colors
                            .textSecondary)
                }
                if !shownTags.isEmpty {
                    Section("點一下加上或拿掉") {
                        ForEach(shownTags, id: \.self) { tagRow($0) }
                    }
                }
            }
            .font(Token.Fonts.body)
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .navigationTitle("標籤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .tint(Token.Colors.link)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        addNewTag()
                        guard !isTooLong else {
                            return
                        }
                        onSave(tags)
                        dismiss()
                    }
                    .tint(Token.Colors.link)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    /// 去掉前後空白和開頭的 #；空的、太長的不收，回 nil。
    static func cleaned(_ input: String) -> String? {
        var tag = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while tag.hasPrefix("#") || tag.hasPrefix("＃") {
            tag.removeFirst()
        }
        tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, tag.count <= maxTagLength else {
            return nil
        }
        return tag
    }

    /// 這篇的加上用過的，不重複，照字排。
    private var shownTags: [String] {
        var all = tags
        for tag in knownTags
            where !all.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
        {
            all.append(tag)
        }
        return all.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func tagRow(_ tag: String) -> some View {
        let isOn = tags.contains(tag)
        return Button {
            if isOn {
                tags.removeAll { $0 == tag }
            } else {
                tags.append(tag)
            }
        } label: {
            HStack {
                Text(tag)
                    .foregroundStyle(Token.Colors.textPrimary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Token.Colors.link : Token.Colors.textSecondary)
            }
        }
        .accessibilityValue(isOn ? "已加上" : "沒加")
        .listRowBackground(Token.Colors.rowBackground)
    }

    /// 已經有一樣的（不分大小寫）就只是確定它勾著。
    private func addNewTag() {
        guard let tag = Self.cleaned(newTag) else {
            // 空的（或只有 #）就當沒打；超過字數才講太長。
            isTooLong = newTag.trimmingCharacters(in: .whitespacesAndNewlines).count > Self
                .maxTagLength
            if !isTooLong {
                newTag = ""
            }
            return
        }
        isTooLong = false
        newTag = ""
        if let existing = shownTags
            .first(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
        {
            if !tags.contains(existing) {
                tags.append(existing)
            }
        } else {
            tags.append(tag)
        }
    }
}
