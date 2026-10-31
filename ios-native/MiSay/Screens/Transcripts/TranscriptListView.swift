import SwiftUI

/// 文字稿清單（推入頁）。片 A2 只有殼；清單是片 D7、搜尋是片 E6。
struct TranscriptListView: View {
    var body: some View {
        Token.Colors.groupedBackground
            .ignoresSafeArea()
            .navigationTitle("文字稿")
    }
}
