import SwiftUI
import VeggieKit

/// 設定頁「支援」區（蔬菜家族共用規格）：意見回饋、在 App Store 評分、分享給朋友。
/// 意見回饋開系統寫信畫面，信尾只帶版本、iOS、機型、語言，不帶金鑰、錄音、文字稿。
/// 評分要有 Apple ID 才出現（`VeggieSetup.swift` 還沒填）。米說沒有內購，所以沒有「購買」區。
struct SettingsSupportSection: View {
    @Environment(\.openURL) private var openURL
    @State private var isWritingMail = false
    /// 寄不出去時講一句；平常不放說明（準則 3-4）。
    @State private var mailProblem: String?

    private let config = VeggieConfig.misay

    var body: some View {
        Section {
            feedbackRow
            if let url = config.writeReviewURL {
                Link(destination: url) {
                    VeggieRow(icon: "star", title: VeggieText.rate, accessory: .external)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-rate")
            }
            ShareLink(item: config.shareText) {
                VeggieRow(
                    icon: "square.and.arrow.up",
                    title: VeggieText.share,
                    accessory: .external
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-share")
        } header: {
            Text(VeggieText.support)
        } footer: {
            if let mailProblem {
                Text(mailProblem)
                    .font(Token.Fonts.footnote)
            }
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    @ViewBuilder
    private var feedbackRow: some View {
        if let address = config.supportEmail {
            Button {
                writeFeedback(to: address)
            } label: {
                VeggieRow(icon: "envelope", title: VeggieText.feedback, accessory: .push)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-feedback")
            .sheet(isPresented: $isWritingMail) {
                FeedbackMailView(recipient: address, feedback: Feedback(config: config)) {
                    isWritingMail = false
                }
                .ignoresSafeArea()
            }
        }
    }

    /// 手機有設郵件帳號就開系統寫信畫面；沒有就交給別的寄信 app（mailto），連那也沒有才說寄不出去。
    private func writeFeedback(to address: String) {
        mailProblem = nil
        if Feedback.canUseMailSheet {
            isWritingMail = true
            return
        }
        guard let url = Feedback(config: config).mailtoURL(to: address) else {
            mailProblem = Self.noMailApp
            return
        }
        openURL(url) { accepted in
            if !accepted {
                mailProblem = Self.noMailApp
            }
        }
    }

    static let noMailApp = "這支手機沒有可以寄信的 app。"
}
