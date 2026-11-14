import AVFoundation
import SwiftUI

/// 詳情頁「⋯ → 聽原音與重點」（K5、K6）：上面是錄音中標的重點，下面是一段一段的文字稿，點了就從那裡附近開始播。
/// 轉錄不給每句話的時間（gpt-transcribe 沒有時間戳），位置照字數比例估，誤差約幾十秒，所以從前 10 秒開始放。
/// 錄音已經刪了（超過 7 天）的篇只列重點與段落，不能播。
/// 2026-11-09 米：要一邊聽一邊對文字稿，抓 AI 聽錯的地方。所以段落整段顯示不截斷，播到哪段就標出來、捲過去。
struct OriginalAudioSheet: View {
    let transcript: Transcript
    let audioURL: URL?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var loadFailed = false

    static let leadInSeconds: Double = 10
    static let skipSeconds: Double = 15
    static let previewCharacterCount = 40
    /// 重點那欄每筆只給兩行（米說重點那欄 OK，只改文字稿那欄）。
    static let markLineLimit = 2
    static let noAudioMessage = "錄音已經刪了（或這篇是接著錄的好幾段），只能看文字。"
        + "設定 → 進階可以讓錄音一直留著。"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if let marks = transcript.marks, !marks.isEmpty {
                        Section("重點") {
                            ForEach(marks, id: \.self) { mark in
                                row(time: mark, text: Self.nearbyText(at: mark, in: transcript))
                                    .lineLimit(Self.markLineLimit)
                            }
                        }
                    }
                    Section("文字稿") {
                        ForEach(paragraphs, id: \.offset) { paragraph in
                            paragraphRow(paragraph)
                        }
                    }
                }
                .onChange(of: playingParagraphOffset) { _, offset in
                    follow(offset, with: proxy)
                }
            }
            .safeAreaInset(edge: .bottom) { controls }
            .navigationTitle("聽原音與重點")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .task { await tick() }
        .onDisappear { player?.stop() }
    }

    private var paragraphs: [Paragraph] {
        Self.paragraphs(of: transcript)
    }

    /// 播到（或停在）哪一段；還沒按過播放是 nil，什麼都不標。
    private var playingParagraphOffset: Int? {
        guard player != nil else {
            return nil
        }
        return Self.paragraph(at: currentTime, in: paragraphs)?.offset
    }

    /// 播放中換到下一段就捲過去；暫停時不動，人可能正往回找。
    private func follow(_ offset: Int?, with proxy: ScrollViewProxy) {
        guard let offset, isPlaying else {
            return
        }
        if reduceMotion {
            proxy.scrollTo(offset, anchor: .top)
        } else {
            withAnimation { proxy.scrollTo(offset, anchor: .top) }
        }
    }

    /// 文字稿的段落整段顯示。正在播的那段換底色、時間那行換成一句話：位置是估的，所以寫「大約」。
    private func paragraphRow(_ paragraph: Paragraph) -> some View {
        let isPlayingHere = paragraph.offset == playingParagraphOffset
        return row(
            time: paragraph.time,
            text: paragraph.text,
            playingLabel: isPlayingHere ? "大約播到這段" : nil
        )
        .id(paragraph.offset)
        .listRowBackground(
            isPlayingHere ? Token.Colors.accentSoft : Token.Colors.rowBackground
        )
    }

    private func row(time: Double, text: String, playingLabel: String? = nil) -> some View {
        Button {
            play(from: time - Self.leadInSeconds)
        } label: {
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                Text(playingLabel ?? "\(RecordingSheetView.formatElapsed(max(0, time))) 附近")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(
                        playingLabel == nil ? Token.Colors.textSecondary : Token.Colors.link
                    )
                Text(text)
                    .font(Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .lineSpacing(Token.Space.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(audioURL == nil)
    }

    @ViewBuilder
    private var controls: some View {
        if audioURL == nil {
            StatusStrip(glyph: .note, message: Self.noAudioMessage)
                .padding(Token.Space.l)
        } else if loadFailed {
            StatusStrip(glyph: .failed, message: "錄音打不開，文字稿不受影響。")
                .padding(Token.Space.l)
        } else {
            HStack(spacing: Token.Space.xl) {
                Button("往前 15 秒", systemImage: "gobackward.15") { skip(-Self.skipSeconds) }
                Button(
                    isPlaying ? "暫停" : "播放",
                    systemImage: isPlaying ? "pause.fill" : "play.fill"
                ) {
                    if isPlaying {
                        pause()
                    } else {
                        play(from: currentTime)
                    }
                }
                Button("往後 15 秒", systemImage: "goforward.15") { skip(Self.skipSeconds) }
                Text(RecordingSheetView.formatElapsed(currentTime))
                    .font(Token.Fonts.secondary)
                    .monospacedDigit()
            }
            .labelStyle(.iconOnly)
            .font(Token.Fonts.rowTitle)
            .tint(Token.Colors.link)
            .padding(Token.Space.l)
            .frame(maxWidth: .infinity)
            .background(Token.Colors.rowBackground)
        }
    }

    private func play(from seconds: Double) {
        guard let player = loadedPlayer() else {
            return
        }
        player.currentTime = min(max(0, seconds), player.duration)
        player.play()
        isPlaying = true
        currentTime = player.currentTime
    }

    private func pause() {
        player?.pause()
        isPlaying = false
    }

    private func skip(_ seconds: Double) {
        play(from: currentTime + seconds)
    }

    /// 第一次按才開檔：只是打開這頁看重點的人不用等。
    private func loadedPlayer() -> AVAudioPlayer? {
        if let player {
            return player
        }
        guard let audioURL else {
            return nil
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            let loaded = try AVAudioPlayer(contentsOf: audioURL)
            player = loaded
            return loaded
        } catch {
            loadFailed = true
            return nil
        }
    }

    /// 播放進度半秒更新一次；頁面關掉，`.task` 被取消就停。
    private func tick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            if let player {
                currentTime = player.currentTime
                isPlaying = player.isPlaying
            }
        }
    }
}

/// 位置怎麼估（純函式，CI 測得到）。
extension OriginalAudioSheet {
    struct Paragraph: Equatable {
        let offset: Int
        let time: Double
        let text: String
    }

    /// 重點那句從這些字後面開始抓，才不會從「，」或半句話開頭。
    static let sentenceEnds: Set<Character> = ["。", "！", "？", "!", "?", "\n"]
    /// 往前找不到句子開頭時，至少不要從標點或空白開始。
    static let leadingTrim: Set<Character> = ["，", "、", "。", "！", "？", ",", " ", "　", "\n"]

    /// 文字稿照空行或換行分段；每段的時間＝它前面有幾個字 ÷ 全部字數 × 錄音長度。
    static func paragraphs(of transcript: Transcript) -> [Paragraph] {
        let text = transcript.displayText
        let total = max(1, text.count)
        var paragraphs: [Paragraph] = []
        var offset = 0
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let time = Double(offset) / Double(total) * transcript.durationSeconds
                paragraphs.append(Paragraph(offset: offset, time: time, text: trimmed))
            }
            offset += line.count + 1
        }
        return paragraphs
    }

    /// 播到這個秒數大約在哪一段：開始時間不超過它的最後一段。
    static func paragraph(at seconds: Double, in paragraphs: [Paragraph]) -> Paragraph? {
        paragraphs.last { $0.time <= seconds } ?? paragraphs.first
    }

    /// 重點附近那句：照時間比例找到字的位置，從那裡往前找它所在那句的開頭（最多退一個預覽長度），
    /// 找不到就照舊從位置前面一點開始。一樣用字數估。
    static func nearbyText(at seconds: Double, in transcript: Transcript) -> String {
        let characters = Array(transcript.displayText)
        guard !characters.isEmpty, transcript.durationSeconds > 0 else {
            return ""
        }
        let ratio = min(1, max(0, seconds / transcript.durationSeconds))
        let center = min(characters.count - 1, Int(Double(characters.count) * ratio))
        let roughStart = max(0, center - previewCharacterCount / 2)
        let floor = max(0, center - previewCharacterCount)
        var cursor = center
        while cursor > floor, !sentenceEnds.contains(characters[cursor - 1]) {
            cursor -= 1
        }
        let foundSentence = cursor == 0 || sentenceEnds.contains(characters[cursor - 1])
        let slice = characters[(foundSentence ? cursor : roughStart)...]
            .drop { leadingTrim.contains($0) }
        return String(slice.prefix(previewCharacterCount))
            .replacingOccurrences(of: "\n", with: " ")
    }
}
