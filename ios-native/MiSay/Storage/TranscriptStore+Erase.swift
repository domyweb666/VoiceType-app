import Foundation

/// 刪除全部資料（S2-9）之後，還開著的編輯頁不准把刪掉的那篇存回來。
/// 編輯頁存檔時，存檔裡找不到這篇會改存手上那份（壞檔被搬走也不掉字）；刪光之後也這樣存，刪掉的就回來了。
/// 所以開頁時記下這是第幾次刪光之後，存之前比一次，對不上就不存。
/// 只記在記憶體、不進資料檔：重開 App 之後，刪光之前開著的編輯頁也不在了。
@MainActor
extension TranscriptStore {
    /// 這次開 App 以來刪過幾次全部資料。
    private(set) static var eraseGeneration = 0

    /// 刪除全部資料一開始就叫：之前開著的編輯頁從此存不進去。
    static func markErased() {
        eraseGeneration += 1
    }

    /// 編輯頁的存檔：`generation` 是開頁時的 `eraseGeneration`。
    /// 開頁之後刪過全部資料就丟 `notFound`、不寫檔，跟這篇被刪掉一樣處理。
    func save(_ transcript: Transcript, openedInGeneration generation: Int) throws {
        guard generation == Self.eraseGeneration else {
            throw Failure.notFound
        }
        try save(transcript)
    }
}
