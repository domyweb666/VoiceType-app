import SwiftUI

/// 備份區裡「自動備份到資料夾」那幾列（2026-11-24）：開關、現在的資料夾、沒成功時講是哪裡。
/// 第一次打開要先選資料夾；在選資料夾的畫面按取消，開關就留在關。
struct AutoBackupRows: View {
    private let autoBackup = AutoBackup.shared
    @State private var isPickingFolder = false
    @State private var pickFailed = false

    var body: some View {
        Toggle("自動備份到資料夾", isOn: isOn)
            .tint(Token.Colors.link)
            .fileImporter(
                isPresented: $isPickingFolder,
                allowedContentTypes: [.folder],
                onCompletion: picked
            )
        if autoBackup.isOn {
            Button {
                isPickingFolder = true
            } label: {
                LabeledContent("資料夾", value: autoBackup.folderName ?? "還沒選")
            }
            .tint(Token.Colors.link)
            .accessibilityHint("點兩下換一個資料夾")
        }
        if let problem {
            HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Token.Colors.danger)
                    .accessibilityHidden(true)
                Text(problem)
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textPrimary)
            }
        }
    }

    private var problem: String? {
        if pickFailed {
            return AutoBackup.Failure.cannotAccess.message
        }
        return autoBackup.isOn ? autoBackup.lastFailure?.message : nil
    }

    private var isOn: Binding<Bool> {
        Binding(
            get: { autoBackup.isOn },
            set: { newValue in
                pickFailed = false
                if newValue, autoBackup.folderName == nil {
                    isPickingFolder = true
                } else {
                    autoBackup.setOn(newValue)
                    backUpNow()
                }
            }
        )
    }

    /// 選好馬上寫第一份，成不成功當場看得到。按取消不動。
    private func picked(_ result: Result<URL, Error>) {
        guard case let .success(folder) = result else {
            return
        }
        do {
            try autoBackup.use(folder: folder)
            pickFailed = false
        } catch {
            pickFailed = true
            return
        }
        backUpNow()
    }

    private func backUpNow() {
        Task { await autoBackup.runIfDue() }
    }
}
