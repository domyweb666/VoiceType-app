import SwiftUI
import VeggieKit

/// 這一區自己的數值（Tokens.swift 沒有，也不屬於設計代號）。
private enum Metrics {
    /// 長按版本號複製好之後，那句「已複製版本資訊」留多久
    static let noticeSeconds: Double = 2
}

/// 設定頁最下面（蔬菜家族共用規格）：「關於」一區，加上頁尾。
/// 關於：蔬菜家族的其他 app（清單在 VeggieKit，不連網；一個都沒有就整列藏）、隱私權政策（有網址才出現）。
/// 沒有開源授權那列：程式只用自家的 VeggieKit，沒有要附授權全文的東西。
/// 頁尾取代原本的「版本」列：app 圖示、「米說 0.2.18（28）」、Made by DOMYWEB、官網臉書 IG；長按版本號複製版本資訊。
struct SettingsAboutSection: View {
    @State private var notice: String?

    private let config = VeggieConfig.misay

    var body: some View {
        if hasAboutRows {
            Section {
                if !VeggieApp.others(excluding: config.slug).isEmpty {
                    NavigationLink {
                        VeggieFamilyView(config: config)
                            .veggieStyle(.misay)
                    } label: {
                        VeggieRow(icon: "square.grid.2x2", title: VeggieText.family)
                    }
                    .accessibilityIdentifier("about-family")
                }
                if let url = config.privacyURL {
                    Link(destination: url) {
                        VeggieRow(
                            icon: "hand.raised",
                            title: VeggieText.privacy,
                            accessory: .external
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("about-privacy")
                }
            } header: {
                Text(VeggieText.about)
            }
            .listRowBackground(Token.Colors.rowBackground)
        }
        Section {
            VeggieFooter(config: config, logo: Image("AppLogo")) { text in
                notice = text
            }
            .listRowInsets(EdgeInsets())
        } footer: {
            if let notice {
                Text(notice)
                    .font(Token.Fonts.footnote)
                    .frame(maxWidth: .infinity)
            }
        }
        .listRowBackground(Color.clear)
        .task(id: notice) { await clearNotice() }
    }

    /// 整區沒東西就整區不出現（準則 3-4）。
    private var hasAboutRows: Bool {
        !VeggieApp.others(excluding: config.slug).isEmpty || config.privacyURL != nil
    }

    private func clearNotice() async {
        guard notice != nil else {
            return
        }
        do {
            try await Task.sleep(for: .seconds(Metrics.noticeSeconds))
        } catch {
            // 離開這頁被取消：那句提示跟著畫面一起消失，不用再清。
            return
        }
        notice = nil
    }
}
