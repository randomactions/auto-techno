#if canImport(CryptoKit)
import AutoTechnoCore
@testable import AutoTechnoDSP
import CryptoKit
import Foundation
import Testing

struct AT0039FrozenCohortCaseIdentity {
    let id: String
    let ordinal: Int?
    let cohort: String?
    let rootSeed: UInt64
    let checkpoint: CanonicalJourneyCheckpoint
    let targetPhraseIndex: Int?
    let continuationClass: String
    let expectedPlanFingerprint: String?
    let resolvedBarCount: Int?
    let behaviorCounts: [String: Int]?
}

enum AT0039FrozenCohortValidator {
    private static let behaviorNames = FoundationBehavior.allCases
        .map(\.rawValue).sorted()

    static func errors(for cases: [AT0039FrozenCohortCaseIdentity]) -> [String] {
        var errors: [String] = []
        var rootsByBehavior: [String: Set<UInt64>] = [:]
        guard !cases.isEmpty else { return ["AT-0039 cohort has no cases"] }

        for (index, item) in cases.enumerated() {
            guard let ordinal = item.ordinal, let cohort = item.cohort,
                  let phraseIndex = item.targetPhraseIndex,
                  let fingerprint = item.expectedPlanFingerprint,
                  let barCount = item.resolvedBarCount,
                  let counts = item.behaviorCounts,
                  Set(counts.keys) == Set(behaviorNames) else {
                errors.append("case[\(index)] lacks frozen plan or score identity")
                continue
            }
            let range: ClosedRange<Int>
            let tag: String
            switch cohort {
            case "development": range = 7...134; tag = "DEV"
            case "held-out": range = 135...262; tag = "HOLDOUT"
            default:
                errors.append("case[\(index)] has an invalid cohort")
                continue
            }
            guard range.contains(ordinal), item.rootSeed == seed(ordinal),
                  (0..<128).contains(phraseIndex) else {
                errors.append("case[\(index)] has an invalid ordinal, seed, or phrase index")
                continue
            }
            let expectedClass = phraseIndex == 0
                ? "initial" : phraseIndex >= 16 ? "long" : "advanced"
            let expectedID = String(
                format: "AT39-%@-%03d-PHRASE-%03d-%@",
                tag, ordinal, phraseIndex,
                item.checkpoint.rawValue.uppercased().replacingOccurrences(
                    of: "-", with: "_"
                )
            )
            if item.continuationClass != expectedClass || item.id != expectedID {
                errors.append("case[\(index)] identity fields are inconsistent")
            }
            if fingerprint.count != 16 || !fingerprint.allSatisfy({
                ("0"..."9").contains(String($0)) ||
                    ("a"..."f").contains(String($0))
            }) {
                errors.append("case[\(index)] expected plan fingerprint is invalid")
            }
            if !(1...16).contains(barCount) ||
                counts.values.contains(where: { $0 < 0 }) ||
                counts.values.reduce(0, +) != barCount ||
                !behaviorNames.contains(where: { (counts[$0] ?? 0) > 0 }) {
                errors.append("case[\(index)] behavior counts are invalid")
            }
            for behavior in behaviorNames where (counts[behavior] ?? 0) > 0 {
                rootsByBehavior["\(cohort):\(behavior)", default: []]
                    .insert(item.rootSeed)
            }
        }

        for cohort in ["development", "held-out"] {
            for behavior in behaviorNames
            where (rootsByBehavior["\(cohort):\(behavior)"]?.count ?? 0) < 2 {
                errors.append("\(cohort):\(behavior) lacks two distinct score roots")
            }
        }
        return Array(Set(errors)).sorted()
    }

    static func seed(_ ordinal: Int) -> UInt64 {
        precondition(ordinal >= 0)
        var value = UInt64(0x6175746f74656368)
            &+ (UInt64(ordinal) &+ 1) &* 0x9e3779b97f4a7c15
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }

    static func scoreMetadataMatches(
        expectedBarCount: Int?,
        expectedBehaviorCounts: [String: Int]?,
        actualBarCount: Int,
        actualBehaviorCounts: [String: Int]
    ) -> Bool {
        guard let expectedBarCount, let expectedBehaviorCounts else {
            return false
        }
        return expectedBarCount == actualBarCount &&
            expectedBehaviorCounts == actualBehaviorCounts
    }
}

@Suite("AT-0039 score-only foundation cohort selection", .serialized)
struct AT0039FoundationCohortSelectionTests {
    private struct Route: Decodable, Encodable {
        let id: String
        let sampleRate: Int
        let channelCount: Int
        let routeGeneration: Int
        let routeRecovery: Bool
    }

    private struct PhaseOneCorpus: Decodable {
        struct Policy: Decodable { let maximumPhrases: Int }
        let checkpointPolicy: Policy
        let routes: [Route]
    }

    private struct SelectedCase: Encodable {
        let id: String
        let ordinal: Int
        let cohort: String
        let rootSeed: UInt64
        let checkpoint: String
        let targetPhraseIndex: Int
        let continuationClass: String
        let expectedPlanFingerprint: String
        let resolvedBarCount: Int
        let foundationBehaviorBarCounts: [String: Int]
    }

    @Test("AT-0039 candidate seed ordinals are deterministic and disjoint from Phase 1")
    func candidateScheduleIdentity() {
        #expect(splitMix64Seed(0) == 14_191_091_090_230_775_643)
        #expect(splitMix64Seed(6) == 8_323_052_619_921_110_197)
        #expect(splitMix64Seed(7) != splitMix64Seed(135))
        #expect((7...134).count == 128)
        #expect((135...262).count == 128)
    }

    @Test("Frozen candidates cover every behavior at an applicable score checkpoint")
    func continuationScheduleCoverage() {
        let selection = selectCandidates()
        #expect(AT0039FrozenCohortValidator.errors(
            for: selection.cases.map(caseIdentity)
        ).isEmpty)
    }

    @Test("Frozen corpus cases require exact target phrase and score fingerprint")
    func frozenCaseIdentityIsRequired() {
        let valid = syntheticCoverageCases()
        #expect(AT0039FrozenCohortValidator.errors(for: valid).isEmpty)
        var malformed = valid
        malformed[0] = AT0039FrozenCohortCaseIdentity(
            id: malformed[0].id,
            ordinal: malformed[0].ordinal,
            cohort: malformed[0].cohort,
            rootSeed: malformed[0].rootSeed,
            checkpoint: malformed[0].checkpoint,
            targetPhraseIndex: nil,
            continuationClass: malformed[0].continuationClass,
            expectedPlanFingerprint: nil,
            resolvedBarCount: malformed[0].resolvedBarCount,
            behaviorCounts: malformed[0].behaviorCounts
        )
        #expect(AT0039FrozenCohortValidator.errors(for: malformed).contains {
            $0.contains("lacks frozen plan or score identity")
        })
    }

    @Test("Frozen behavior coverage must match the accepted score facts")
    func scoreMetadataMatchesAcceptedPlan() {
        let expected = ["kick": 2, "bass": 2]
        #expect(AT0039FrozenCohortValidator.scoreMetadataMatches(
            expectedBarCount: 4,
            expectedBehaviorCounts: expected,
            actualBarCount: 4,
            actualBehaviorCounts: expected
        ))
        #expect(!AT0039FrozenCohortValidator.scoreMetadataMatches(
            expectedBarCount: 4,
            expectedBehaviorCounts: expected,
            actualBarCount: 4,
            actualBehaviorCounts: ["kick": 4, "bass": 0]
        ))
        #expect(!AT0039FrozenCohortValidator.scoreMetadataMatches(
            expectedBarCount: 3,
            expectedBehaviorCounts: expected,
            actualBarCount: 4,
            actualBehaviorCounts: expected
        ))
    }

    @MainActor
    @Test("Freeze the preregistered score-only cohorts before any audio capture")
    func freezeCohorts() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_FREEZE_AT0039_COHORT"
        ] == "1" else { return }

        let root = repositoryRoot
        guard try acceptedInputsAreClean(root) else {
            Issue.record(
                "AT-0039 cohort selection requires clean Package.swift, Sources, and canonical baseline inputs; no corpus file was written"
            )
            return
        }
        let baselineData = try Data(contentsOf: root.appendingPathComponent(
            "docs/BASELINE_CORPUS.json"
        ))
        let baselineCorpus = try JSONDecoder().decode(
            PhaseOneCorpus.self,
            from: baselineData
        )
        let baseline = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appendingPathComponent(
                "docs/ROADMAP_EXECUTION_BASELINE.json"
            ))
        ) as? [String: Any]
        let baselineFingerprint = try #require(
            baseline?["snapshotFingerprint"] as? String
        )
        let sourceBytesFingerprint = try sourceFingerprint(root)
        let captureHead = try gitHead(root)

        let selection = selectCandidates()
        let behaviorNames = FoundationBehavior.allCases.map(\.rawValue).sorted()
        for cohort in ["development", "held-out"] {
            let missing = behaviorNames.filter {
                (selection.rootsByBehavior["\(cohort):\($0)"]?.count ?? 0) < 2
            }
            guard missing.isEmpty else {
                Issue.record(
                    "AT-0039 \(cohort) score-only checkpoint schedule lacks two distinct roots for: \(missing.joined(separator: ", ")); no corpus file was written"
                )
                return
            }
        }
        let selectedCases = selection.cases
        let behaviorCaseIDs = selection.behaviorCaseIDs
        let schemaErrors = AT0039FrozenCohortValidator.errors(
            for: selectedCases.map(caseIdentity)
        )
        guard schemaErrors.isEmpty else {
            Issue.record("AT-0039 selector emitted invalid frozen cases: \(schemaErrors.joined(separator: "; "))")
            return
        }

        let output = root.appendingPathComponent(
            "docs/local/reports/AT-0039-foundation-cohort-v1",
            isDirectory: true
        )
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw CohortError.destinationAlreadyExists
        }
        try FileManager.default.createDirectory(
            at: output,
            withIntermediateDirectories: true
        )
        let report: [String: Any] = [
            "schema": "autotechno-at0039-foundation-cohort.v1",
            "cohortVersion": 1,
            "purpose": "Outcome-blind score-stratified AT-0039 candidate whole-mix corpus",
            "algorithm": "splitmix64-domain-sequence.v1",
            "domainKeyHex": "6175746f74656368",
            "incrementHex": "9e3779b97f4a7c15",
            "outputMapping": "rootSeed=mix(domainKey+(ordinal+1)*increment modulo 2^64)",
            "cohortOrdinalRanges": [
                "development": [7, 134],
                "held-out": [135, 262],
            ],
            "selectionOrder": "ascending-ordinal-before-audio-listening-or-analyzer-output",
            "selectionRule": "ascending ordinal then phrase index; select the first applicable score-only checkpoint phrase that adds a distinct root for an uncovered behavior",
            "picksPerBehaviorPerCohort": 2,
            "sourceFingerprint": sourceBytesFingerprint,
            "contractBaselineFingerprint": baselineFingerprint,
            "gitHead": captureHead,
            "engineVersion": QualityQualificationContract.engineVersion,
            "corpusVersion": 1,
            "checkpointPolicy": [
                "maximumPhrases": 128,
                "selection": "first canonical score-only phrase/checkpoint for each additional required behavior root",
                "advancement": "AutonomousSessionDirector.plan then AutonomousSessionState.advancePlanning",
            ],
            "routes": baselineCorpus.routes.map { route in
                [
                    "id": route.id,
                    "sampleRate": route.sampleRate,
                    "channelCount": route.channelCount,
                    "routeGeneration": route.routeGeneration,
                    "routeRecovery": route.routeRecovery,
                ] as [String: Any]
            },
            "cases": selectedCases.sorted {
                if $0.cohort != $1.cohort { return $0.cohort < $1.cohort }
                if $0.ordinal != $1.ordinal { return $0.ordinal < $1.ordinal }
                return $0.targetPhraseIndex < $1.targetPhraseIndex
            }.map(encodeCase),
            "behaviorCases": behaviorCaseIDs,
            "requiredCoverage": behaviorNames,
            "scope": "score-only cohort selection; no audio rendering, quality evaluation, listener labeling, or threshold fitting",
        ]
        let data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(
            to: output.appendingPathComponent("corpus.json"),
            options: .atomic
        )
    }

    private func selectCandidates() -> (
        cases: [SelectedCase],
        behaviorCaseIDs: [String: [String]],
        rootsByBehavior: [String: Set<UInt64>]
    ) {
        let behaviorNames = FoundationBehavior.allCases.map(\.rawValue).sorted()
        var selectedCases: [SelectedCase] = []
        var behaviorCaseIDs: [String: [String]] = [:]
        var rootsByBehavior: [String: Set<UInt64>] = [:]
        for cohort in ["development", "held-out"] {
            for behavior in behaviorNames {
                rootsByBehavior["\(cohort):\(behavior)"] = []
            }
        }

        for (cohortName, ordinals) in [
            ("development", 7...134),
            ("held-out", 135...262),
        ] {
            let cohortTag = cohortName == "development" ? "DEV" : "HOLDOUT"
            for ordinal in ordinals {
                let rootSeed = splitMix64Seed(ordinal)
                let director = AutonomousSessionDirector(rootSeed: rootSeed)
                var state = director.initialState()
                var previousChapter: InterlockChapter?
                for _ in 0..<128 {
                    let plan = director.plan(from: state)
                    let chapters = plan.resolvedBars.map(\.interlockChapter)
                    let chapterChanged = zip(chapters, chapters.dropFirst()).contains {
                        $0.0 != $0.1
                    } || (previousChapter.flatMap { previous in
                        chapters.first.map { $0 != previous }
                    } ?? false)
                    let checkpoints = CanonicalJourneyCheckpoint.applicable(
                        phraseIndex: plan.phraseIndex,
                        phraseKind: plan.kind,
                        chapterChanged: chapterChanged
                    )
                    let counts = Dictionary(uniqueKeysWithValues:
                        FoundationBehavior.allCases.map { behavior in
                            (behavior.rawValue, plan.resolvedBars.filter {
                                $0.foundationBehavior == behavior
                            }.count)
                        }
                    )

                    if let checkpoint = checkpoints.first {
                        let additions = behaviorNames.filter { behavior in
                            (counts[behavior] ?? 0) > 0 &&
                                (rootsByBehavior["\(cohortName):\(behavior)"]?.count ?? 0) < 2 &&
                                !(rootsByBehavior["\(cohortName):\(behavior)"] ?? [])
                                    .contains(rootSeed)
                        }
                        if !additions.isEmpty {
                            let caseID = String(
                                format: "AT39-%@-%03d-PHRASE-%03d-%@",
                                cohortTag,
                                ordinal,
                                plan.phraseIndex,
                                checkpoint.rawValue.uppercased().replacingOccurrences(
                                    of: "-", with: "_"
                                )
                            )
                            selectedCases.append(SelectedCase(
                                id: caseID,
                                ordinal: ordinal,
                                cohort: cohortName,
                                rootSeed: rootSeed,
                                checkpoint: checkpoint.rawValue,
                                targetPhraseIndex: plan.phraseIndex,
                                continuationClass: plan.phraseIndex == 0
                                    ? "initial"
                                    : plan.phraseIndex >= 16 ? "long" : "advanced",
                                expectedPlanFingerprint:
                                    AutonomousCandidateFingerprint.plan(plan),
                                resolvedBarCount: counts.values.reduce(0, +),
                                foundationBehaviorBarCounts: counts
                            ))
                            for behavior in additions {
                                rootsByBehavior["\(cohortName):\(behavior)", default: []]
                                    .insert(rootSeed)
                                behaviorCaseIDs["\(cohortName):\(behavior)", default: []]
                                    .append(caseID)
                            }
                        }
                    }

                    previousChapter = chapters.last ?? previousChapter
                    state.advancePlanning(using: plan)
                    let complete = behaviorNames.allSatisfy {
                        (rootsByBehavior["\(cohortName):\($0)"]?.count ?? 0) >= 2
                    }
                    if complete { break }
                }
                if behaviorNames.allSatisfy({
                    (rootsByBehavior["\(cohortName):\($0)"]?.count ?? 0) >= 2
                }) { break }
            }
        }
        return (selectedCases, behaviorCaseIDs, rootsByBehavior)
    }

    private func splitMix64Seed(_ ordinal: Int) -> UInt64 {
        AT0039FrozenCohortValidator.seed(ordinal)
    }

    private func caseIdentity(
        _ item: SelectedCase
    ) -> AT0039FrozenCohortCaseIdentity {
        AT0039FrozenCohortCaseIdentity(
            id: item.id,
            ordinal: item.ordinal,
            cohort: item.cohort,
            rootSeed: item.rootSeed,
            checkpoint: CanonicalJourneyCheckpoint(rawValue: item.checkpoint)!,
            targetPhraseIndex: item.targetPhraseIndex,
            continuationClass: item.continuationClass,
            expectedPlanFingerprint: item.expectedPlanFingerprint,
            resolvedBarCount: item.resolvedBarCount,
            behaviorCounts: item.foundationBehaviorBarCounts
        )
    }

    private func syntheticCoverageCases() -> [AT0039FrozenCohortCaseIdentity] {
        var result: [AT0039FrozenCohortCaseIdentity] = []
        for (cohort, ordinals) in [
            ("development", [7, 8]),
            ("held-out", [135, 136]),
        ] {
            let tag = cohort == "development" ? "DEV" : "HOLDOUT"
            for behavior in FoundationBehavior.allCases.map(\.rawValue).sorted() {
                for ordinal in ordinals {
                var counts = Dictionary(uniqueKeysWithValues:
                    FoundationBehavior.allCases.map { ($0.rawValue, 0) }
                )
                counts[behavior] = 4
                let id = String(
                    format: "AT39-%@-%03d-PHRASE-000-ESTABLISHMENT",
                    tag, ordinal
                )
                result.append(AT0039FrozenCohortCaseIdentity(
                    id: id,
                    ordinal: ordinal,
                    cohort: cohort,
                    rootSeed: splitMix64Seed(ordinal),
                    checkpoint: .establishment,
                    targetPhraseIndex: 0,
                    continuationClass: "initial",
                    expectedPlanFingerprint: String(repeating: "a", count: 16),
                    resolvedBarCount: 4,
                    behaviorCounts: counts
                ))
                }
            }
        }
        return result
    }

    private func encodeCase(_ item: SelectedCase) -> [String: Any] {
        [
            "id": item.id,
            "ordinal": item.ordinal,
            "cohort": item.cohort,
            "rootSeed": item.rootSeed,
            "checkpoint": item.checkpoint,
            "targetPhraseIndex": item.targetPhraseIndex,
            "continuationClass": item.continuationClass,
            "expectedPlanFingerprint": item.expectedPlanFingerprint,
            "resolvedBarCount": item.resolvedBarCount,
            "foundationBehaviorBarCounts": item.foundationBehaviorBarCounts,
        ]
    }

    private func sourceFingerprint(_ root: URL) throws -> String {
        let manager = FileManager.default
        let roots = [
            "Package.swift", "Sources", "docs/BASELINE_CORPUS.json",
            "docs/ROADMAP_EXECUTION_BASELINE.json",
        ]
        var paths: [String] = []
        for item in roots {
            let url = root.appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            if manager.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                paths += (manager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey]
                )?.allObjects as? [URL] ?? []).filter {
                    (try? $0.resourceValues(forKeys: [.isRegularFileKey])
                        .isRegularFile) == true
                }.map {
                    $0.path.replacingOccurrences(
                        of: root.path + "/", with: ""
                    )
                }
            } else {
                paths.append(item)
            }
        }
        var data = Data()
        for path in paths.sorted() {
            data.append(Data(path.utf8))
            data.append(0)
            data.append(try Data(contentsOf: root.appendingPathComponent(path)))
        }
        return digest(data)
    }

    private func gitHead(_ root: URL) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path, "rev-parse", "HEAD"]
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CohortError.git }
        return String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func acceptedInputsAreClean(_ root: URL) throws -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-C", root.path, "status", "--porcelain", "--untracked-files=all", "--",
            "Package.swift", "Sources", "docs/BASELINE_CORPUS.json",
            "docs/ROADMAP_EXECUTION_BASELINE.json",
        ]
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CohortError.git }
        return pipe.fileHandleForReading.readDataToEndOfFile().isEmpty
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

    private enum CohortError: Error {
        case destinationAlreadyExists
        case git
    }
}

#endif
