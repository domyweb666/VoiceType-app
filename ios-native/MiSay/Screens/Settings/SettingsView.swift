import SwiftUI

/// 設定（推入頁）。片 A2 只有殼；金鑰那一列是片 B3，其餘是組塊 F。
struct SettingsView: View {
    var body: some View {
        Token.Colors.groupedBackground
            .ignoresSafeArea()
            .navigationTitle("設定")
    }
}
