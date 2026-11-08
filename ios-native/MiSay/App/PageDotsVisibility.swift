import SwiftUI

/// 三頁最上面那排小點要不要藏。推進去的頁（文字稿詳情、詞彙、待轉錄）在畫面上時藏起來，
/// 把那一條高度還給內容（2026-11-08 米：詳情頁打字時只剩兩行）。
@Observable
final class PageDotsVisibility {
    private var hidingPages: Set<UUID> = []

    var isHidden: Bool {
        !hidingPages.isEmpty
    }

    func hide(for page: UUID) {
        hidingPages.insert(page)
    }

    func show(for page: UUID) {
        hidingPages.remove(page)
    }
}

private struct HidesPageDots: ViewModifier {
    /// 測試或預覽沒放這個環境值時就什麼都不做。
    @Environment(PageDotsVisibility.self) private var dots: PageDotsVisibility?
    @State private var page = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { dots?.hide(for: page) }
            .onDisappear { dots?.show(for: page) }
    }
}

extension View {
    /// 這頁在畫面上時，三頁的小點藏起來。
    func hidesPageDots() -> some View {
        modifier(HidesPageDots())
    }
}
