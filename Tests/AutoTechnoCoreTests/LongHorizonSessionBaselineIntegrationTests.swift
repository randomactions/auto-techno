#if canImport(CryptoKit)
import AutoTechnoCore
@testable import AutoTechnoDSP
import CryptoKit
import Foundation
import Testing

@Suite("Exact local long-horizon session baseline", .serialized)
struct LongHorizonSessionBaselineIntegrationTests {
    private struct Corpus: Decodable {
        struct SelectionPolicy: Decodable { let selectionCount: Int }
        struct Case: Decodable {
            let id: String
            let ordinal: Int
            let rootSeed: UInt64
            let checkpoint: String
            let continuationClass: String
        }
        let schema: String
        let selectionPolicy: SelectionPolicy
        let cases: [Case]
    }

    private struct Manifest: Encodable {
        let schema = "autotechno-long-horizon-session-baseline-manifest.v1"
        let manifestVersion = 1
        let corpusSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let analyzerSchemaVersion: Int
        let analyzerSchemaIdentifier: String
        let buildConfiguration: String
        let observationRoute = "score-only-canonical-planning"
        let requestedHours: Int
        let requestedBars: Int
        let segmentBarCount: Int
        let maximumBarCount: Int
        let maximumSegmentCount: Int
        let entries: [Entry]
    }

    private struct Entry: Encodable {
        let id: String
        let caseId: String
        let ordinal: Int
        let rootSeed: UInt64
        let checkpoint: String
        let continuationClass: String
        let initialStateFingerprint: String
        let outgoingStateFingerprint: String
        let startingPhraseIndex: Int
        let nextExpectedPhraseIndex: Int
        let startingBar: Int
        let nextExpectedBar: Int
        let observedPhraseCount: Int
        let observedBarCount: Int
        let segmentCount: Int
        let reportFingerprint: String
        let artifactPath: String
        let artifactSha256: String
    }

    private struct Artifact: Encodable {
        let schema = "autotechno-long-horizon-session-baseline-artifact.v1"
        let artifactVersion = 1
        let caseId: String
        let ordinal: Int
        let rootSeed: UInt64
        let checkpoint: String
        let continuationClass: String
        let requestedHours: Int
        let requestedBars: Int
        let buildConfiguration: String
        let observationRoute = "score-only-canonical-planning"
        let initialStateFingerprint: String
        let outgoingStateFingerprint: String
        let phrases: [LongHorizonSessionBaselinePhraseInput]
        let report: LongHorizonSessionBaselineReport
    }

    @Test("Export seven exact four-hour canonical planning journeys")
    func exportAll() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_SESSION_TRAJECTORY_BASELINE"
        ] == "1" else { return }
        let root = repositoryRoot
        let corpusURL = root.appendingPathComponent("docs/BASELINE_CORPUS.json")
        let corpusData = try Data(contentsOf: corpusURL)
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        let snapshotData = try Data(contentsOf: root.appendingPathComponent(
            "docs/ROADMAP_EXECUTION_BASELINE.json"
        ))
        let snapshot = try #require(
            try JSONSerialization.jsonObject(with: snapshotData)
                as? [String: Any]
        )
        let output = root.appendingPathComponent(
            "docs/local/reports/long-horizon-session-baseline-v1",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: output,
            withIntermediateDirectories: true
        )
        let requestedHours = 4
        let requestedBars = Int((
            Double(requestedHours * 60) * AutonomousSessionDirector.bpm / 4
        ).rounded(.up))
        let buildConfiguration: String
        #if DEBUG
        buildConfiguration = "debug"
        #else
        buildConfiguration = "release"
        #endif

        #expect(corpus.schema == "autotechno-baseline-corpus.v1")
        #expect(corpus.selectionPolicy.selectionCount == 7)
        #expect(corpus.cases.count == 7)
        var entries: [Entry] = []
        for fixture in corpus.cases.sorted(by: { $0.ordinal < $1.ordinal }) {
            entries.append(try export(
                fixture,
                requestedHours: requestedHours,
                requestedBars: requestedBars,
                buildConfiguration: buildConfiguration,
                output: output
            ))
        }
        let manifest = Manifest(
            corpusSha256: digest(corpusData),
            contractBaselineFingerprint: try #require(
                snapshot["snapshotFingerprint"] as? String
            ),
            sourceFingerprint: try sourceFingerprint(root),
            gitHead: try gitHead(root),
            engineVersion: QualityQualificationContract.engineVersion,
            analyzerSchemaVersion:
                LongHorizonSessionBaselineSchema.schemaVersion,
            analyzerSchemaIdentifier:
                LongHorizonSessionBaselineSchema.schemaIdentifier,
            buildConfiguration: buildConfiguration,
            requestedHours: requestedHours,
            requestedBars: requestedBars,
            segmentBarCount:
                LongHorizonSessionBaselineSchema.segmentBarCount,
            maximumBarCount:
                LongHorizonSessionBaselineSchema.maximumBarCount,
            maximumSegmentCount:
                LongHorizonSessionBaselineSchema.maximumSegmentCount,
            entries: entries
        )
        try encoded(manifest).write(
            to: output.appendingPathComponent("manifest.json"),
            options: .atomic
        )

        #expect(entries.count == 7)
        #expect(entries.map(\.ordinal) == Array(0..<7))
        #expect(entries.allSatisfy { $0.observedBarCount >= requestedBars })
        #expect(entries.allSatisfy {
            $0.observedBarCount <=
                LongHorizonSessionBaselineSchema.maximumBarCount
        })
    }

    private func export(
        _ fixture: Corpus.Case,
        requestedHours: Int,
        requestedBars: Int,
        buildConfiguration: String,
        output: URL
    ) throws -> Entry {
        let director = AutonomousSessionDirector(rootSeed: fixture.rootSeed)
        var state = director.initialState()
        let initialStateFingerprint =
            AutonomousTypedFingerprint.sessionState(state)
        var phrases: [LongHorizonSessionBaselinePhraseInput] = []
        while state.memory.totalBars < requestedBars {
            let plan = director.plan(from: state)
            phrases.append(try #require(
                LongHorizonSessionBaselinePhraseInput.make(
                    plan: plan,
                    incomingState: state
                )
            ))
            state.advancePlanning(using: plan)
        }
        let report: LongHorizonSessionBaselineReport
        switch LongHorizonSessionBaselineAnalyzer.analyze(phrases) {
        case let .available(value): report = value
        case let .unavailable(reason):
            throw ExportError.unavailable(reason)
        }
        let outgoingStateFingerprint =
            AutonomousTypedFingerprint.sessionState(state)
        let artifact = Artifact(
            caseId: fixture.id,
            ordinal: fixture.ordinal,
            rootSeed: fixture.rootSeed,
            checkpoint: fixture.checkpoint,
            continuationClass: fixture.continuationClass,
            requestedHours: requestedHours,
            requestedBars: requestedBars,
            buildConfiguration: buildConfiguration,
            initialStateFingerprint: initialStateFingerprint,
            outgoingStateFingerprint: outgoingStateFingerprint,
            phrases: phrases,
            report: report
        )
        let artifactData = try encoded(artifact)
        let filename = String(format: "%02d", fixture.ordinal) + "-" +
            fixture.id.lowercased() + ".json"
        try artifactData.write(
            to: output.appendingPathComponent(filename),
            options: .atomic
        )
        return Entry(
            id: "session-baseline--" + String(format: "%02d", fixture.ordinal),
            caseId: fixture.id,
            ordinal: fixture.ordinal,
            rootSeed: fixture.rootSeed,
            checkpoint: fixture.checkpoint,
            continuationClass: fixture.continuationClass,
            initialStateFingerprint: initialStateFingerprint,
            outgoingStateFingerprint: outgoingStateFingerprint,
            startingPhraseIndex: report.startingPhraseIndex,
            nextExpectedPhraseIndex: report.nextExpectedPhraseIndex,
            startingBar: report.startingBar,
            nextExpectedBar: report.nextExpectedBar,
            observedPhraseCount: report.observedPhraseCount,
            observedBarCount: report.observedBarCount,
            segmentCount: report.segments.count,
            reportFingerprint: report.reportFingerprint,
            artifactPath:
                "docs/local/reports/long-horizon-session-baseline-v1/" +
                filename,
            artifactSha256: digest(artifactData)
        )
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        return try encoder.encode(value)
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func gitHead(_ root: URL) throws -> String {
        try git(
            ["rev-parse", "HEAD"],
            root: root
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceFingerprint(_ root: URL) throws -> String {
        let output = try git([
            "ls-files", "--cached", "--others", "--exclude-standard", "--",
            "Package.swift", "Sources", "Tests", "scripts",
            "docs/BASELINE_CORPUS.json",
            "docs/ROADMAP_EXECUTION_BASELINE.json",
        ], root: root)
        let paths = output.split(whereSeparator: \.isNewline).map(String.init)
            .sorted()
        var data = Data()
        for path in paths {
            data.append(Data(path.utf8))
            data.append(0)
            data.append(try Data(contentsOf: root.appendingPathComponent(path)))
        }
        return digest(data)
    }

    private func git(_ arguments: [String], root: URL) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path] + arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExportError.git(String(
                decoding: errors.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            ))
        }
        return String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
    }

    private enum ExportError: Error {
        case unavailable(LongHorizonSessionBaselineUnavailableReason)
        case git(String)
    }
}
#endif
