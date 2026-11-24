@testable import MiSay
import XCTest

/// 片 S2-5：留存錄音什麼時候可以刪（純判斷）。米 11/07：「就是都 ok 了，才刪。」
final class RetainedRecordingsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000_000)
    private let plentyOfSpace: Int64 = 50_000_000_000

    func test留存還沒有文字稿的不刪空間不夠也不刪() {
        let failing = Transcript(durationSeconds: 60, rawText: "口語稿")
        let doomed = RetainedRecordings.idsToDelete(
            retainedIDs: [failing.id],
            transcripts: [failing],
            deletesOrphans: true,
            now: now,
            availableBytes: 10
        )
        XCTAssertEqual(doomed, [])
    }

    func test留存文字稿存好七天後才刪() {
        let sixDays = transcript(polishedDaysAgo: 6)
        let sevenDays = transcript(polishedDaysAgo: 7)
        let doomed = RetainedRecordings.idsToDelete(
            retainedIDs: [sixDays.id, sevenDays.id],
            transcripts: [sixDays, sevenDays],
            deletesOrphans: true,
            now: now,
            availableBytes: plentyOfSpace
        )
        XCTAssertEqual(doomed, [sevenDays.id])
    }

    func test留存空間不到一GB有文字稿的提早刪() {
        let fresh = transcript(polishedDaysAgo: 0)
        let doomed = RetainedRecordings.idsToDelete(
            retainedIDs: [fresh.id],
            transcripts: [fresh],
            deletesOrphans: true,
            now: now,
            availableBytes: 900_000_000
        )
        XCTAssertEqual(doomed, [fresh.id])
    }

    func test留存那篇刪了錄音跟著刪但有讀不到的篇時不刪() {
        let orphan = UUID()
        let deletes = RetainedRecordings.idsToDelete(
            retainedIDs: [orphan],
            transcripts: [],
            deletesOrphans: true,
            now: now,
            availableBytes: plentyOfSpace
        )
        XCTAssertEqual(deletes, [orphan])
        let keeps = RetainedRecordings.idsToDelete(
            retainedIDs: [orphan],
            transcripts: [],
            deletesOrphans: false,
            now: now,
            availableBytes: plentyOfSpace
        )
        XCTAssertEqual(keeps, [], "讀不到的那篇可能就是它，錄音是僅剩的一份")
    }

    private func transcript(polishedDaysAgo days: Double) -> Transcript {
        Transcript(
            durationSeconds: 60,
            rawText: "口語稿",
            draftText: "文字稿",
            polishedAt: now.addingTimeInterval(-days * 24 * 60 * 60)
        )
    }

    func test併進別篇的錄音從併入起留七天_一直留著就跟著原篇() {
        let fresh = UUID()
        let old = UUID()
        var target = transcript(polishedDaysAgo: 30)
        target.mergedRecordings = [
            MergedRecording(id: fresh, mergedAt: now.addingTimeInterval(-6 * 24 * 60 * 60)),
            MergedRecording(id: old, mergedAt: now.addingTimeInterval(-7 * 24 * 60 * 60)),
        ]
        func doomed(_ listed: [Transcript], trashed: [Transcript], forever: Bool) -> [UUID] {
            RetainedRecordings.idsToDelete(
                retainedIDs: [fresh, old],
                transcripts: listed,
                trashed: trashed,
                deletesOrphans: true,
                keepsForever: forever,
                now: now,
                availableBytes: plentyOfSpace
            )
        }
        XCTAssertEqual(doomed([target], trashed: [], forever: false), [old])
        XCTAssertEqual(doomed([], trashed: [target], forever: false), [old])
        XCTAssertEqual(doomed([target], trashed: [], forever: true), [])
        XCTAssertEqual(doomed([], trashed: [], forever: true), [fresh, old], "原篇真的刪了")
    }
}
