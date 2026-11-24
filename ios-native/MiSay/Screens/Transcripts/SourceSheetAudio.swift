import AVFoundation
import SwiftUI

/// 「錄音與原稿」裡的「聽原音與重點」（K5、K6）：上面是錄音中標的重點，下面是口語稿，點了就從那裡開始播。
/// 2026-11-15 米：要像有聲書那樣標出正在講哪句、重點的範圍太模糊。所以改成放口語稿（錄音講的原話，
/// 時間對得上），播到哪句就把那句標出來、還沒講到的字變淡；重點是按下去那句加前一句，在口語稿裡畫底線。
/// 轉錄不給每句話的時間（gpt-transcribe 沒有時間戳），位置是在每 5 分鐘一段裡照字數估的（`SpokenTimeline`），
/// 會差幾秒，所以從前 3 秒開始放。錄音已經刪了（超過 7 天）的篇只列重點與口語稿，不能播。
struct SourceSheetAudio: View {
    let transcript: Transcript
    let audioURL: URL?
    private let sentences: [SpokenTimeline.Sentence]
    private let blocks: [SpokenTimeline.Block]
    private let passages: [SpokenTimeline.Passage]
    private let markedSentences: Set<Int>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var loadFailed = false

    static let leadInSeconds: Double = 3
    static let skipSeconds: Double = 15
    static let tickMilliseconds = 250
    static let noAudioMessage = "錄音已經刪了（或這篇是接著錄的好幾段），只能看文字。"
        + "設定 → 進階可以讓錄音一直留著。"
    static let preciseNote = "位置是照每 5 分鐘一段估的，可能差幾秒。畫底線的是你錄音時標的重點。"
    static let roughNote = "這篇錄的時候還沒記下每一段的時間，位置是照整篇字數估的，可能差幾十秒。"

    init(transcript: Transcript, audioURL: URL?) {
        self.transcript = transcript
        self.audioURL = audioURL
        let sentences = SpokenTimeline.sentences(of: transcript)
        let passages = SpokenTimeline.passages(marks: transcript.marks ?? [], in: sentences)
        self.sentences = sentences
        self.passages = passages
        blocks = SpokenTimeline.blocks(sentences)
        markedSentences = Set(passages.flatMap(\.sentenceIndexes))
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !passages.isEmpty {
                    Section("重點") {
                        ForEach(passages) { passage in
                            row(time: passage.markSeconds, startsAt: passage.start) {
                                Text(passage.text)
                                    .foregroundStyle(Token.Colors.textPrimary)
                            }
                        }
                    }
                }
                Section {
                    ForEach(blocks) { block in
                        blockRow(block)
                    }
                } header: {
                    Text("口語稿")
                } footer: {
                    Text(footnote)
                        .font(Token.Fonts.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: playingBlockID) { _, blockID in
                follow(blockID, with: proxy)
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        .task { await tick() }
        .onDisappear { player?.stop() }
    }

    private var footnote: String {
        SpokenTimeline.isPrecise(transcript) ? Self.preciseNote : Self.roughNote
    }

    /// 播到（或停在）哪一句；還沒按過播放是 nil，什麼都不標。
    private var playingSentenceIndex: Int? {
        guard player != nil else {
            return nil
        }
        return SpokenTimeline.sentence(at: currentTime, in: sentences)?.index
    }

    private var playingBlockID: Int? {
        guard let index = playingSentenceIndex else {
            return nil
        }
        return blocks.first { $0.sentences.contains { $0.index == index } }?.id
    }

    /// 播放中換到下一列就捲過去；暫停時不動，人可能正往回找。
    private func follow(_ blockID: Int?, with proxy: ScrollViewProxy) {
        guard let blockID, isPlaying else {
            return
        }
        if reduceMotion {
            proxy.scrollTo(blockID, anchor: .center)
        } else {
            withAnimation { proxy.scrollTo(blockID, anchor: .center) }
        }
    }

    private func blockRow(_ block: SpokenTimeline.Block) -> some View {
        row(time: block.start, startsAt: block.start) {
            Text(Self.styled(block, playing: playingSentenceIndex, marked: markedSentences))
        }
        .id(block.id)
    }

    private func row(
        time: Double,
        startsAt start: Double,
        @ViewBuilder text: () -> some View
    ) -> some View {
        Button {
            play(from: start - Self.leadInSeconds)
        } label: {
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                Text("\(RecordingSheetView.formatElapsed(max(0, time))) 附近")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                text()
                    .font(Token.Fonts.body)
                    .lineSpacing(Token.Space.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(audioURL == nil)
        .listRowBackground(Token.Colors.rowBackground)
    }

    /// 一列的字：正在講的那句換底色，還沒講到的變淡，重點畫底線。還沒播的時候全部照平常的顏色。
    static func styled(
        _ block: SpokenTimeline.Block,
        playing: Int?,
        marked: Set<Int>
    ) -> AttributedString {
        var result = AttributedString()
        for sentence in block.sentences {
            var piece = AttributedString(sentence.text)
            let isUpcoming = playing.map { sentence.index > $0 } ?? false
            piece.swiftUI.foregroundColor = isUpcoming
                ? Token.Colors.textSecondary
                : Token.Colors.textPrimary
            if sentence.index == playing {
                piece.swiftUI.backgroundColor = Token.Colors.accentSoft
            }
            if marked.contains(sentence.index) {
                piece.swiftUI.underlineStyle = .single
            }
            result += piece
        }
        return result
    }
}

/// 底下那排播放鈕與播放本身（拆出來：主型別超過 200 行）。
extension SourceSheetAudio {
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

    /// 播放進度一秒更新四次（一句話兩三秒，半秒一次會慢半拍）；頁面關掉，`.task` 被取消就停。
    private func tick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Self.tickMilliseconds))
            if let player {
                currentTime = player.currentTime
                isPlaying = player.isPlaying
            }
        }
    }
}
