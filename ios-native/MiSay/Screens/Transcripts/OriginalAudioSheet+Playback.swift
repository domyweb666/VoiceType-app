import AVFoundation
import SwiftUI

/// 「聽原音與重點」底下的播放列與播放動作。從 `OriginalAudioSheet.swift` 原樣搬過來，行為沒有改。
extension OriginalAudioSheet {
    @ViewBuilder
    var controls: some View {
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

    func play(from seconds: Double) {
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
    func tick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Self.tickMilliseconds))
            if let player {
                currentTime = player.currentTime
                isPlaying = player.isPlaying
            }
        }
    }
}
