import AVFoundation
@testable import MiSay
import XCTest

/// 組塊 S 片 S1：接回之後硬體格式可能變了，同一個檔要接著寫。不開麥克風，直接餵不同格式的聲音。
final class MicrophoneCaptureTests: XCTestCase {
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func test錄音換硬體格式後同一個檔接著寫長度對得上() throws {
        let url = directory.appending(path: "switch.wav")
        let capture = try MicrophoneCapture(
            creatingAt: url,
            onSamples: { _, _ in },
            onEngineStopped: {}
        )
        // 48 kHz 單聲道一秒，再換 44.1 kHz 雙聲道一秒（像接上藍牙耳機），每段 0.1 秒。
        try feed(capture, sampleRate: 48000, channels: 1, tenthsOfSecond: 10)
        try feed(capture, sampleRate: 44100, channels: 2, tenthsOfSecond: 10)
        XCTAssertFalse(capture.hasWriteFailure)
        try capture.finish()

        let bytes = try Data(contentsOf: url)
        let dataBytes = bytes.littleEndianUInt32(at: 40)
        XCTAssertEqual(Int(dataBytes), bytes.count - WAVFileWriter.headerByteCount)
        // 轉換器有內部緩衝，頭尾會少一點點；兩秒左右就對。
        XCTAssertEqual(Double(dataBytes) / 32000, 2, accuracy: 0.15)
        XCTAssertEqual(dataBytes % 2, 0, "16-bit 一個樣本兩個 byte，不能錯位")
    }

    func test錄音回報音量與寫到的秒數() throws {
        let url = directory.appending(path: "level.wav")
        let reported = ReportedSamples()
        let capture = try MicrophoneCapture(
            creatingAt: url,
            onSamples: { level, elapsed in
                reported.level = level
                reported.elapsed = elapsed
            },
            onEngineStopped: {}
        )
        try feed(capture, sampleRate: 48000, channels: 1, tenthsOfSecond: 10)
        XCTAssertGreaterThan(reported.level, 0)
        XCTAssertLessThanOrEqual(reported.level, 1)
        XCTAssertEqual(reported.elapsed, Double(capture.writtenByteCount) / 32000, accuracy: 0.001)
        try capture.finish()
    }

    private func feed(
        _ capture: MicrophoneCapture,
        sampleRate: Double,
        channels: AVAudioChannelCount,
        tenthsOfSecond: Int
    ) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)
        )
        let frames = AVAudioFrameCount(sampleRate / 10)
        for _ in 0 ..< tenthsOfSecond {
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
            buffer.frameLength = frames
            let channelData = try XCTUnwrap(buffer.floatChannelData)
            for channel in 0 ..< Int(channels) {
                for frame in 0 ..< Int(frames) {
                    channelData[channel][frame] = sin(Float(frame) * 0.05) * 0.5
                }
            }
            capture.handle(buffer)
        }
    }

    private final class ReportedSamples {
        var level: Double = 0
        var elapsed: Double = 0
    }
}
