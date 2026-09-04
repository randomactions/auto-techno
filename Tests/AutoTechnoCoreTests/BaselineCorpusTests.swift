import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Deterministic Phase-1 baseline corpus")
struct BaselineCorpusTests {
    private struct Manifest: Decodable {
        struct CheckpointPolicy: Decodable {
            let maximumPhrases: Int
        }

        struct Route: Decodable {
            let id: String
            let sampleRate: Int
            let channelCount: Int
            let routeGeneration: Int
            let routeRecovery: Bool
        }

        struct Case: Decodable {
            let id: String
            let ordinal: Int
            let rootSeed: UInt64
            let checkpoint: CanonicalJourneyCheckpoint
            let continuationClass: String
        }

        struct Coverage: Decodable {
            let checkpoints: [CanonicalJourneyCheckpoint]
            let phraseKinds: [AutonomousPhraseKind]
            let continuationClasses: [String]
            let sampleRates: [Int]
            let channelCounts: [Int]
        }

        let corpusVersion: Int
        let checkpointPolicy: CheckpointPolicy
        let routes: [Route]
        let cases: [Case]
        let requiredCoverage: Coverage
    }

    private struct ResolvedCase {
        let fixture: Manifest.Case
        let state: AutonomousSessionState
        let plan: AutonomousPhrasePlan
    }

    @Test("Derived cases reach every declared canonical checkpoint without winner selection")
    func canonicalCoverage() throws {
        let manifest = try loadManifest()
        let resolved = try manifest.cases.map {
            try resolve($0, maximumPhrases: manifest.checkpointPolicy.maximumPhrases)
        }

        #expect(manifest.corpusVersion == 1)
        #expect(Set(resolved.map(\.fixture.checkpoint)) ==
                Set(manifest.requiredCoverage.checkpoints))
        #expect(Set(resolved.map(\.plan.kind)) ==
                Set(manifest.requiredCoverage.phraseKinds))
        #expect(Set(resolved.map(\.fixture.continuationClass)) ==
                Set(manifest.requiredCoverage.continuationClasses))
        #expect(Set(manifest.routes.map(\.sampleRate)) ==
                Set(manifest.requiredCoverage.sampleRates))
        #expect(Set(manifest.routes.map(\.channelCount)) ==
                Set(manifest.requiredCoverage.channelCounts))
        #expect(manifest.routes.allSatisfy {
            $0.routeGeneration == 0 && !$0.routeRecovery
        })

        var stateFingerprints = Set<String>()
        var routeIdentities = Set<String>()
        for item in resolved {
            #expect(item.state.rootSeed == item.fixture.rootSeed)
            #expect(item.state.phraseIndex == item.plan.phraseIndex)
            #expect(item.state.memory.totalBars == item.plan.startBar)
            #expect(item.fixture.rootSeed == derivedSeed(ordinal: item.fixture.ordinal))
            #expect(item.fixture.id == stableID(
                ordinal: item.fixture.ordinal,
                checkpoint: item.fixture.checkpoint
            ))
            #expect(continuationClass(item) == item.fixture.continuationClass)

            let replay = try resolve(
                item.fixture,
                maximumPhrases: manifest.checkpointPolicy.maximumPhrases
            )
            let fingerprint = AutonomousCandidateFingerprint.sessionState(item.state)
            #expect(fingerprint ==
                    AutonomousCandidateFingerprint.sessionState(replay.state))
            #expect(stateFingerprints.insert(fingerprint).inserted)
            for route in manifest.routes {
                #expect(routeIdentities.insert(item.fixture.id + ":" + route.id).inserted)
            }
        }
        #expect(routeIdentities.count == manifest.cases.count * manifest.routes.count)
    }

    private func resolve(
        _ fixture: Manifest.Case,
        maximumPhrases: Int
    ) throws -> ResolvedCase {
        let director = AutonomousSessionDirector(rootSeed: fixture.rootSeed)
        var state = director.initialState()
        var previousChapter: InterlockChapter?
        for _ in 0..<maximumPhrases {
            let plan = director.plan(from: state)
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let changesInsidePhrase = zip(chapters, chapters.dropFirst()).contains {
                $0.0 != $0.1
            }
            let changesAtBoundary = previousChapter.map { previous in
                chapters.first.map { $0 != previous } ?? false
            } ?? false
            let applicable = CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind,
                chapterChanged: changesInsidePhrase || changesAtBoundary
            )
            if applicable.contains(fixture.checkpoint) {
                return ResolvedCase(fixture: fixture, state: state, plan: plan)
            }
            previousChapter = chapters.last ?? previousChapter
            state.advancePlanning(using: plan)
        }
        Issue.record(
            "\(fixture.id) did not reach \(fixture.checkpoint.rawValue) within \(maximumPhrases) canonical phrases"
        )
        throw CorpusError.missingCheckpoint
    }

    private func continuationClass(_ item: ResolvedCase) -> String {
        if item.plan.phraseIndex == 0 && item.state.memory.totalBars == 0 {
            return "initial"
        }
        if item.plan.phraseIndex >= 16 {
            return "long"
        }
        return "advanced"
    }

    private func derivedSeed(ordinal: Int) -> UInt64 {
        let domain: UInt64 = 0x6175_746f_7465_6368
        let increment: UInt64 = 0x9e37_79b9_7f4a_7c15
        var value = domain &+ (UInt64(ordinal) &+ 1) &* increment
        value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
        value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
        return value ^ (value >> 31)
    }

    private func stableID(
        ordinal: Int,
        checkpoint: CanonicalJourneyCheckpoint
    ) -> String {
        let ordinalText = String(format: "%03d", ordinal)
        return "ATBC-V1-\(ordinalText)-\(checkpoint.rawValue.uppercased())"
    }

    private func loadManifest() throws -> Manifest {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent(
            "docs/BASELINE_CORPUS.json"
        ))
        return try JSONDecoder().decode(Manifest.self, from: data)
    }

    private enum CorpusError: Error {
        case missingCheckpoint
    }
}
