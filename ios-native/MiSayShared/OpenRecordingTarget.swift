import AppIntents

/// `OpenIntent` 一定要有一個「打開哪裡」，米說只有一個。
enum OpenRecordingTarget: String, AppEnum {
    case recording

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "米說的畫面"
    static let caseDisplayRepresentations: [OpenRecordingTarget: DisplayRepresentation] = [
        .recording: "錄音",
    ]
}
