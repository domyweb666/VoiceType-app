import AVFoundation
import SwiftUI

/// 詳情頁「⋯ → 聽原音與重點」（K5、K6）：上面是錄音中標的重點，下面是一段一段的文字稿，點了就從那裡附近開始播。
/// 轉錄不給每句話的時間（gpt-transcribe 沒有時間戳），位置照字數比例估，誤差約幾十秒，所以從前 10 秒開始放。
/// 錄音已經刪了（超過 7 天）的篇只列重點與段落，不能播。
struct OriginalAudioSheet: View {
    let transcript: Transcript
    let audioURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var loadFailed = false

    static let leadInSeconds: Double = 10
    static let skipSeconds: Double = 15
    static let previewCharacterCount = 40
    static let noAudioMessage = "錄音已經刪了（或這篇是接著錄的好幾段），只能看文字。"
        + "設定 → 進階可以讓錄音一直留著。"

    var body: some View {
        NavigationStack {
            List {
                if let marks = transcript.marks, !marks.isEmpty {
                    Section("重點") {
                        ForEach(marks, id: \.self) { mark in
                            row(time: mark, text: Self.nearbyText(at: mark, in: transcript))
                        }
                    }
                }
                Section("文字稿") {
                    ForEach(Self.paragraphs(of: transcript), id: \.offset) { paragraph in
                        row(time: paragraph.time, text: paragraph.preview)
                    }
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

    private func row(time: Double, text: String) -> some View {
        Button {
            play(from: time - Self.leadInSeconds)
        } label: {
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                Text("\(RecordingSheetView.formatElapsed(max(0, time))) 附近")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                Text(text)
                    .font(Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .lineLimit(2)
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
                    isPlaying ? pause() : play(from: currentTime)
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
        let preview: String
    }

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
                let preview = String(trimmed.prefix(previewCharacterCount))
                paragraphs.append(Paragraph(offset: offset, time: time, preview: preview))
            }
            offset += line.count + 1
        }
        return paragraphs
    }

    /// 重點附近那句：照時間比例找到字的位置，往前後各抓一點，一樣用字數估。
    static func nearbyText(at seconds: Double, in transcript: Transcript) -> String {
        let text = transcript.displayText
        guard !text.isEmpty, transcript.durationSeconds > 0 else {
            return ""
        }
        let ratio = min(1, max(0, seconds / transcript.durationSeconds))
        let center = Int(Double(text.count) * ratio)
        let start = max(0, center - previewCharacterCount / 2)
        let slice = text.dropFirst(start).prefix(previewCharacterCount)
        return slice.replacingOccurrences(of: "\n", with: " ")
    }
}
