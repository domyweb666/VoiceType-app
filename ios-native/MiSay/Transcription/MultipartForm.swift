import Foundation

/// 方塊 M3：組 OpenAI 轉錄要的 multipart/form-data 正文。只有欄位與檔案兩種部件，不做別的。
struct MultipartForm {
    let boundary: String
    private var parts = Data()

    init(boundary: String = "MiSay-" + UUID().uuidString) {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addField(name: String, value: String) {
        parts.append(Data("--\(boundary)\r\n".utf8))
        parts.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        parts.append(Data("\(value)\r\n".utf8))
    }

    mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        parts.append(Data("--\(boundary)\r\n".utf8))
        let disposition = "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        parts.append(Data(disposition.utf8))
        parts.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        parts.append(data)
        parts.append(Data("\r\n".utf8))
    }

    var body: Data {
        var body = parts
        body.append(Data("--\(boundary)--\r\n".utf8))
        return body
    }
}
