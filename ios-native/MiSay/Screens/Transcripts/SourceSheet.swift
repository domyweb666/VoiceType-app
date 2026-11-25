import SwiftUI

/// 詳情頁「⋯ → 錄音與原稿」（2026-11-24 Y6）：口語稿、AI 改了什麼、聽原音與重點併成一頁，上面分段切，
/// 沒有的那種不出現。從錄音重新轉錄是頁內一顆要確認的鈕。
struct SourceSheet: View {
    enum Mode: String, Identifiable {
        case raw = "口語稿"
        case diff = "AI 改了什麼"
        case audio = "聽原音與重點"

        var id: Self {
            self
        }
    }

    let transcript: Transcript
    let recordingURL: URL?
    let onRetranscribe: () -> Void
    @State private var mode: Mode
    /// 放在這裡，聽完切回「AI 改了什麼」不用重比。
    @State private var comparison: SourceComparison?
    /// 點了「可能改了意思」的一列：切到聽原音後從這裡開始播，播了就清掉。
    @State private var listenSeconds: Double?
    @State private var isConfirmingRetranscribe = false
    @Environment(\.dismiss) private var dismiss

    init(transcript: Transcript, recordingURL: URL?, onRetranscribe: @escaping () -> Void) {
        self.transcript = transcript
        self.recordingURL = recordingURL
        self.onRetranscribe = onRetranscribe
        let modes = Self.modes(for: transcript, hasRecording: recordingURL != nil)
        _mode = State(initialValue: modes.first ?? .raw)
    }

    /// 還沒整理的篇，口語稿就在正文那頁；自己打的新文稿沒有口語稿。錄音還留著或標過重點才有得聽。
    static func modes(for transcript: Transcript, hasRecording: Bool) -> [Mode] {
        var modes: [Mode] = []
        if transcript.draftText != nil, !transcript.rawText.isEmpty {
            modes += [.raw, .diff]
        }
        if hasRecording || !(transcript.marks ?? []).isEmpty {
            modes.append(.audio)
        }
        return modes
    }

    /// S2-5：錄音還留著才有（文字稿存好後留 7 天）。接著錄過的篇錄音不只一段，不給。
    static func canRetranscribe(_ transcript: Transcript, hasRecording: Bool) -> Bool {
        hasRecording && transcript.combinedAt == nil
    }

    var body: some View {
        NavigationStack {
            content
                .safeAreaInset(edge: .top) { modePicker }
                .safeAreaInset(edge: .bottom) { retranscribeButton }
                .background(pageColor)
                .navigationTitle("錄音與原稿")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                            .tint(Token.Colors.link)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    private var hasRecording: Bool {
        recordingURL != nil
    }

    private var pageColor: Color {
        mode == .audio ? Token.Colors.groupedBackground : Token.Colors.rowBackground
    }

    @ViewBuilder
    private var content: some View {
        if mode == .audio {
            SourceSheetAudio(
                transcript: transcript,
                audioURL: playableURL,
                listenSeconds: $listenSeconds
            )
        } else {
            SourceSheetText(
                transcript: transcript,
                showsDiff: mode == .diff,
                comparison: $comparison,
                onListen: listenAction
            )
        }
    }

    /// 接著錄過的篇，留著的錄音只對得上第一段，位置會估錯，不給播。
    private var playableURL: URL? {
        transcript.combinedAt != nil ? nil : recordingURL
    }

    private var listenAction: ((Double) -> Void)? {
        guard playableURL != nil else {
            return nil
        }
        return { seconds in
            listenSeconds = seconds
            mode = .audio
        }
    }

    @ViewBuilder
    private var modePicker: some View {
        let modes = Self.modes(for: transcript, hasRecording: hasRecording)
        if modes.count > 1 {
            Picker("顯示", selection: $mode) {
                ForEach(modes) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Token.Space.l)
            .padding(.vertical, Token.Space.s)
            .background(pageColor)
        }
    }

    @ViewBuilder
    private var retranscribeButton: some View {
        if Self.canRetranscribe(transcript, hasRecording: hasRecording) {
            Button("從錄音重新轉錄") { isConfirmingRetranscribe = true }
                .buttonStyle(TextButtonStyle())
                .frame(maxWidth: .infinity)
                .background(pageColor)
                .confirmationDialog(
                    "用錄音重新轉一次？",
                    isPresented: $isConfirmingRetranscribe,
                    titleVisibility: .visible
                ) {
                    Button("重新轉錄") {
                        dismiss()
                        onRetranscribe()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("口語稿和文字稿都會換成新的，你改過的字會不見。")
                }
        }
    }
}
