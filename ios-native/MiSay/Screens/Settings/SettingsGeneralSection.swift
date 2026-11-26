import SwiftUI
import VeggieKit

/// 設定頁「一般」區（蔬菜家族共用規格）：外觀、觸覺回饋。
/// 米說只有繁中、不發提醒通知，所以沒有語言、通知兩列（準則 3-4：現在能用的才放）。
struct SettingsGeneralSection: View {
    @AppStorage(Appearance.storageKey) private var appearanceCode = Appearance.system.rawValue
    @AppStorage(VeggieHaptics.storageKey) private var isHapticsOn = true

    var body: some View {
        Section {
            appearanceRow
            VeggieToggleRow(
                icon: "iphone.radiowaves.left.and.right",
                title: VeggieText.haptics,
                isOn: $isHapticsOn
            )
            .accessibilityIdentifier("settings-haptics")
        } header: {
            Text(VeggieText.general)
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    private var appearance: Appearance {
        Appearance(rawValue: appearanceCode) ?? .system
    }

    /// 三選一，選完馬上換：套在視窗上，彈出來的面板也一起換。
    private var appearanceRow: some View {
        Menu {
            Picker(VeggieText.appearance, selection: $appearanceCode) {
                ForEach(Appearance.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
        } label: {
            VeggieRow(
                icon: "circle.lefthalf.filled",
                title: VeggieText.appearance,
                value: appearance.title
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-appearance")
        .onChange(of: appearanceCode) {
            appearance.apply()
        }
    }
}
