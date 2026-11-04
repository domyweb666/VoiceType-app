import SwiftUI
import UserNotifications

/// 完成面板下方一行（06-首次體驗權限時刻表：第一次完成之後才問，不先跳說明框）。
/// 還沒問過才出現；不按也照常，只是錄音中途停了手機不會響。
struct RecordingAlarmPrompt: View {
    @State private var isAsking = false

    var body: some View {
        if isAsking {
            VStack(spacing: Token.Space.s) {
                Text("錄音如果中途停了，要發通知給你嗎？")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("要，發通知給我") {
                    Task { await requestPermission() }
                }
                .font(Token.Fonts.body)
                .tint(Token.Colors.link)
            }
        } else {
            // 要有一個真的東西在畫面上，.task 才會跑。
            Color.clear
                .frame(height: Token.Space.xs)
                .task { await refresh() }
        }
    }

    @MainActor
    private func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAsking = settings.authorizationStatus == .notDetermined
    }

    @MainActor
    private func requestPermission() async {
        // 按不允許或出錯都不影響錄音和整理，所以不當錯誤；問過就不再出現。
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        )
        isAsking = false
    }
}
