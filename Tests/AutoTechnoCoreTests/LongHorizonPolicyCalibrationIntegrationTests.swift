import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP
@testable import AutoTechnoTransport

@Suite("Representative long-horizon policy calibration", .serialized)
struct LongHorizonPolicyCalibrationIntegrationTests {
  private let developmentRoots: [UInt64] = [
    48_291, 77_777, 90_909, 112_358, 141_421, 173_205, 246_813,
  ]
  private let holdoutRoots: [UInt64] = [271_828, 314_159]

  /// Deliberately expensive and opt-in. Each root supplies a complete
  /// full canonical journey through the shared detached preparation owner.
  /// Every accepted phrase supplies semantic, signal and effect-dose evidence
  /// at both native rates; owned measured children are consumed exactly once.
  /// PCM remains local and is discarded after reduction.
  @Test("Generate exact development, adversarial, and disjoint holdout artifacts")
  func generateArtifacts() async throws {
    guard
      ProcessInfo.processInfo.environment[
        "AUTOTECHNO_RUN_LONG_HORIZON_CALIBRATION"
      ] == "1"
    else { return }

    #if DEBUG
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    #endif
    let binding = try executionBinding()
    try prepareOutputNamespace()
    let corpora = try await calibrationCorpora()
    let development = corpora.development
    let holdoutCorpus = corpora.holdout
    let profile = try LongHorizonProfessionalProfile(corpus: development)
    let profileEvaluator = try LongHorizonProfessionalProfileEvaluator(
      profile: profile)
    for observation in development.observations {
      let verdict = profileEvaluator.evaluate(observation)
      Self.progress(
        "development root=\(observation.rootSeed) accepted=\(verdict.accepted) "
          + "failures=\(verdict.failedDimensions.map(\.rawValue).joined(separator: ","))")
      #expect(verdict.accepted)
    }
    let adversarial = try LongHorizonAdversarialSuiteReport(
      profile: profile,
      sourceObservation: development.observations[0])
    let holdout = try LongHorizonHoldoutQualification(
      profile: profile,
      adversarial: adversarial,
      developmentCorpus: development,
      holdoutCorpus: holdoutCorpus)
    for journey in holdout.journeys {
      Self.progress(
        "holdout root=\(journey.rootSeed) accepted=\(journey.verdict.accepted) "
          + "failures=\(journey.verdict.failedDimensions.map(\.rawValue).joined(separator: ",")) "
          + "semantic=\(journey.verdict.failedSemanticMetrics.map(\.rawValue).joined(separator: ",")) "
          + "operators=\(journey.verdict.failedOperatorDeltas.count) "
          + "effects=\(journey.verdict.failedEffectFamilies.map(\.rawValue).joined(separator: ","))"
      )
      for delta in journey.verdict.failedOperatorDeltas {
        let bound = profile.operatorDeltaBounds.first {
          $0.sampleRate == delta.sampleRate
            && $0.operatorKind == delta.operatorKind
            && $0.metric == delta.metric
        }
        Self.progress(
          "holdout-operator-detail root=\(journey.rootSeed) "
            + "rate=\(Int(delta.sampleRate)) "
            + "operator=\(delta.operatorKind.rawValue) "
            + "metric=\(delta.metric.rawValue) "
            + "transitions=\(delta.transitionCount) "
            + "value=\(delta.meanDelta) bounds="
            + "\(bound?.bounds.lower ?? .nan)..."
            + "\(bound?.bounds.upper ?? .nan)"
        )
      }
    }
    let policy = try LongHorizonProfessionalPolicy(
      profile: profile,
      adversarial: adversarial,
      holdout: holdout)

    #expect(adversarial.passed)
    #expect(holdout.qualified)
    #expect(holdout.journeys.allSatisfy { $0.verdict.accepted })
    #expect(!policy.policyVersion.isEmpty)
    guard adversarial.passed, holdout.qualified, try executionBinding() == binding
    else { throw LongHorizonProfessionalPolicyError.insufficientEvidence }
    try writeArtifacts(
      profile: profile, adversarial: adversarial, holdout: holdout)
    Self.progress("profile=\(profile.fingerprint)")
    Self.progress("adversarial=\(adversarial.fingerprint)")
    Self.progress("holdout=\(holdout.fingerprint)")
  }

  private func calibrationCorpora() async throws -> (
    development: LongHorizonPolicyCalibrationCorpus,
    holdout: LongHorizonPolicyCalibrationCorpus
  ) {
    let primary = try loadPrimary()
    var developmentObservations: [LongHorizonPolicyObservation] = []
    var holdoutObservations: [LongHorizonPolicyObservation] = []
    for seed in developmentRoots {
      developmentObservations.append(try await renderObservation(rootSeed: seed, primary: primary))
    }
    for seed in holdoutRoots {
      holdoutObservations.append(try await renderObservation(rootSeed: seed, primary: primary))
    }
    let development = try LongHorizonPolicyCalibrationCorpus(observations: developmentObservations)
    let holdout = try LongHorizonPolicyCalibrationCorpus(observations: holdoutObservations)
    try writeCorpora(development: development, holdout: holdout)
    return (development, holdout)
  }

  private func writeCorpora(
    development: LongHorizonPolicyCalibrationCorpus,
    holdout: LongHorizonPolicyCalibrationCorpus
  ) throws {
    let directory = try outputDirectory()
    try development.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "long-horizon-development-corpus-local-v3.json"))
    try holdout.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "long-horizon-holdout-corpus-local-v3.json"))
  }

  private func outputDirectory() throws -> URL {
    guard
      let outputDirectory = ProcessInfo.processInfo.environment[
        "AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY"
      ], !outputDirectory.isEmpty
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true).standardizedFileURL
    guard directory.path.hasPrefix(repositoryRoot.appendingPathComponent("docs/local/reports").path + "/")
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    return directory
  }

  @Test("Render one exact diagnostic root")
  func renderDiagnosticRoot() async throws {
    guard
      let rawRoot = ProcessInfo.processInfo.environment[
        "AUTOTECHNO_LONG_HORIZON_DIAGNOSTIC_ROOT"
      ], let rootSeed = UInt64(rawRoot)
    else { return }
    let primary = try loadPrimary()
    _ = try executionBinding()
    try prepareOutputNamespace()
    let observation = try await renderObservation(
      rootSeed: rootSeed, primary: primary)
    let url = try outputDirectory().appendingPathComponent(
      "long-horizon-observation-local-\(rootSeed)-v3.json")
    try observation.deterministicJSON().write(to: url)
    Self.progress(
      "diagnostic root=\(rootSeed) source=\(observation.sourceFingerprint) "
        + "semantic=\(observation.semanticFingerprint) "
        + "signals=\(observation.signalFingerprints.joined(separator: ","))")
  }

  private func prepareOutputNamespace() throws {
    let directory = try outputDirectory()
    guard try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
  }

  private func loadPrimary() throws -> ProfessionalQualityPrimaryArtifacts {
    let environment = ProcessInfo.processInfo.environment
    guard environment["AUTOTECHNO_REUSE_LONG_HORIZON_CORPORA"] != "1",
      environment["AUTOTECHNO_REUSE_LONG_HORIZON_OBSERVATIONS"] != "1"
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    guard let path = environment["AUTOTECHNO_LONG_HORIZON_PRIMARY_ARTIFACT_DIRECTORY"]
    else { return try ProfessionalQualityPrimaryArtifacts.load() }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    let primary = try ProfessionalQualityPrimaryArtifacts(
      profileData: Data(contentsOf: directory.appendingPathComponent("offline-profile.json")),
      adversarialSuiteData: Data(contentsOf: directory.appendingPathComponent("continuous-adversarial-suite.json")),
      holdoutQualificationData: Data(contentsOf: directory.appendingPathComponent("continuous-holdout-qualification.json")))
    guard primary.profile.fingerprint == ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint,
      primary.adversarialSuite.fingerprint == ProfessionalQualityPrimaryArtifacts.expectedAdversarialSuiteFingerprint,
      primary.holdoutQualification.fingerprint == ProfessionalQualityPrimaryArtifacts.expectedHoldoutQualificationFingerprint,
      primary.evaluator.policyVersion == LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion
    else { throw LongHorizonProfessionalPolicyError.profileMismatch }
    return primary
  }

  private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
  }

  private func git(_ arguments: [String]) throws -> String {
    let process = Process(), output = Pipe(), errors = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.currentDirectoryURL = repositoryRoot
    process.arguments = ["git", "-c", "core.fsmonitor=false"] + arguments
    process.standardOutput = output; process.standardError = errors
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0,
      let value = String(data: data, encoding: .utf8)
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Exact source bytes and the immutable qualified model are checked before
  /// and after each route. FNV is an identity digest, not a security signature.
  private func executionBinding() throws -> String {
    guard let accepted = ProcessInfo.processInfo.environment["AUTOTECHNO_LONG_HORIZON_ACCEPTED_HEAD"],
      try git(["rev-parse", "HEAD"]) == accepted,
      try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let primary = try loadPrimary()
    var sink = StreamingFNV1a()
    sink.domain("long-horizon-shared-preparation-inputs.v1"); sink.string(accepted)
    let paths = try git(["ls-files", "--cached", "--others", "--exclude-standard", "--",
      "Package.swift", "Sources", "Tests", "scripts", "docs/BASELINE_CORPUS.json",
      "docs/ROADMAP_EXECUTION_BASELINE.json"]).split(separator: "\n").map(String.init).sorted()
    for path in paths {
      sink.string(path)
      sink.string(try Data(contentsOf: repositoryRoot.appendingPathComponent(path)).base64EncodedString())
    }
    sink.string(primary.profile.fingerprint); sink.string(primary.adversarialSuite.fingerprint)
    sink.string(primary.holdoutQualification.fingerprint)
    return fixedWidthFingerprintHex(sink.value)
  }

  private struct PreparedRouteJourney: Codable, Sendable {
    let rootSeed: UInt64
    let sampleRate: Double
    let consumedPhraseCount: Int
    let newPreparationAttemptCount: Int
    let ownedChildConsumptionCount: Int
    let endSample: Int64
    let traversalFingerprint: String
    let endsAtClosedLeaf: Bool
    let reservedNumericPeakBytes: Int
    let failureCode: String?
    let failureDetails: [String]
    let completedRequestedScope: Bool
    let requestedPrefixPhraseCount: Int?
    let requestedMinimumBars: Int
    let semantic: LongHorizonSemanticTrajectoryReport
    let signal: LongHorizonSignalTrajectoryReport
    let effects: LongHorizonEffectDoseReport
  }

  private static func operatorCoverageComplete(_ report: LongHorizonSignalTrajectoryReport) -> Bool {
    report.availability == .available &&
      report.observationCount >= LongHorizonProfessionalPolicySchema.minimumSignalObservationCount &&
      report.operatorCounts.allSatisfy { $0.observationCount > 0 } &&
      report.operatorTransitions.allSatisfy {
        $0.transitionCount >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount &&
        $0.metricDeltas.count == LongHorizonSignalMetric.allCases.count &&
        $0.metricDeltas.allSatisfy {
          $0.observationCount >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
        }
      }
  }

  private static func renderPreparedRoute(rootSeed: UInt64, sampleRate: Double,
    primary: ProfessionalQualityPrimaryArtifacts, prefixPhraseCount: Int? = nil
  ) -> PreparedRouteJourney {
    let director = AutonomousSessionDirector(rootSeed: rootSeed)
    var state = director.initialState(), renderState = RenderState()
    var graphState = GeneratedDSPContinuationState()
    var graph: DSPGraphPlan?, predecessor: PreparedPerformancePhrase?
    var semantic = LongHorizonSemanticTrajectoryAccumulator(rootSeed: rootSeed,
      startingPhraseIndex: 0, startingBar: 0)
    var signal = LongHorizonSignalTrajectoryAccumulator(rootSeed: rootSeed, sampleRate: sampleRate)
    var effects = LongHorizonEffectDoseAccumulator(rootSeed: rootSeed)
    var samples: Int64 = 0
    var consumed = 0, newPreparations = 0, ownedChildren = 0, peak = 0
    var closedLeaf = false, complete = false, failure: String?
    var details: [String] = []
    var sink = StreamingFNV1a(); sink.domain("long-horizon-actual-prepared-traversal.v1")
    if Thread.isMainThread { failure = "preparation-not-detached" }
    else {
      // Fixed upper bound even if coverage or a naturally closed leaf is unavailable.
      for _ in 0..<10_416 {
        if Task.isCancelled { failure = "cancelled"; break }
        let request = PhrasePreparationRequest(key: PhrasePreparationKey(
          sessionSeed: rootSeed, phraseIndex: state.phraseIndex, sampleRate: sampleRate,
          channelCount: 2, routeRecovery: false, qualityRevision: state.quality.revision,
          qualityPolicyVersion: state.quality.policyVersion,
          qualityControllerFingerprint: state.quality.observedControllerStateFingerprint ?? state.quality.acceptedControllerStateFingerprint,
          routeGeneration: 0, incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
          incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint,
          pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil,
          liveTargetStartSample: nil), sourceState: state, incomingLongHorizonState: nil,
          incomingRenderState: renderState, incomingGraphState: graphState,
          previousGraph: graph, pendingLiveMasterBinding: nil)
        let source: PreparedPerformancePhrase
        do {
          let owned = try predecessor?.continuationAtBoundary(sessionState: state,
            longHorizonState: nil, sampleRate: sampleRate, channelCount: 2,
            routeGeneration: 0, actualStartSample: samples).get()
          predecessor = nil
          if let owned { source = owned; ownedChildren += 1 }
          else {
            newPreparations += 1
            switch AutonomousPerformancePreparer.prepareDiagnosing(request: request,
              director: director, artifacts: primary, longHorizonArtifacts: nil) {
            case .prepared(let prepared): source = prepared
            case .failed(let refused): throw refused
            }
          }
        } catch let refused as PhrasePreparationFailure {
          failure = refused.stage + ":" + refused.code; details = Array(refused.details.prefix(24)); break
        } catch { failure = "continuation-refused"; break }
        var nextSemantic = semantic, nextSignal = signal, nextEffects = effects
        guard source.prepared.commitEligible, source.continuationOwnershipIsValid,
          source.request.replayIdentity.sourceStateFingerprint == AutonomousCandidateFingerprint.sessionState(state),
          let budget = source.preparationChainResourceBudget, budget.reservedPeakWorkingByteCount <= AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount,
          let actualSignal = source.prepared.longHorizonSignalTrajectoryEvidence,
          let actualEffects = source.prepared.longHorizonEffectDoseEvidence,
          nextSemantic.observe(plan: source.prepared.plan, incomingState: state) == .accepted,
          nextSignal.observe(actualSignal) == .accepted, nextEffects.observe(actualEffects) == .accepted,
          let frames = Int64(exactly: source.prepared.audioPreflight.quality.analyzedFrameCount), frames > 0
        else { failure = "ineligible-or-inconsistent-prepared-source"; break }
        let end = samples.addingReportingOverflow(frames)
        guard !end.overflow else { failure = "sample-boundary-overflow"; break }
        semantic = nextSemantic; signal = nextSignal; effects = nextEffects
        peak = max(peak, budget.reservedPeakWorkingByteCount)
        sink.string(source.request.replayIdentity.fingerprint)
        sink.string(actualSignal.planFingerprint); sink.string(actualSignal.candidateEvidenceFingerprint)
        sink.string(actualSignal.pcmFingerprint)
        state = state.advance(using: source.prepared.plan,
          quality: source.prepared.qualityContinuationState,
          liveMasterHeadroom: source.prepared.liveMasterHeadroomContinuationState,
          longHorizonDecision: source.longHorizonDecision)
        renderState = source.prepared.endingRenderState
        graphState = source.prepared.endingGraphState; graph = source.prepared.graph
        sink.string(AutonomousCandidateFingerprint.sessionState(state))
        samples = end.partialValue; consumed += 1
        closedLeaf = !source.requiresQualifiedContinuation
        predecessor = source
        if consumed % 16 == 0 {
          Self.progress("actual root=\(rootSeed) rate=\(Int(sampleRate)) phrases=\(consumed) bars=\(state.memory.totalBars) children=\(ownedChildren)")
        }
        if let prefixPhraseCount, consumed >= prefixPhraseCount { complete = true; break }
        if prefixPhraseCount == nil, state.memory.totalBars >= 7_800,
          operatorCoverageComplete(signal.report), closedLeaf { complete = true; break }
        if state.memory.totalBars >= 10_400 { failure = "bounded-journey-coverage-unavailable"; break }
      }
    }
    if !complete && failure == nil { failure = "phrase-count-bound" }
    return PreparedRouteJourney(rootSeed: rootSeed, sampleRate: sampleRate,
      consumedPhraseCount: consumed, newPreparationAttemptCount: newPreparations,
      ownedChildConsumptionCount: ownedChildren, endSample: samples,
      traversalFingerprint: fixedWidthFingerprintHex(sink.value), endsAtClosedLeaf: closedLeaf,
      reservedNumericPeakBytes: peak, failureCode: failure, failureDetails: details,
      completedRequestedScope: complete, requestedPrefixPhraseCount: prefixPhraseCount,
      requestedMinimumBars: prefixPhraseCount == nil ? 7_800 : 0,
      semantic: semantic.report(), signal: signal.report,
      effects: effects.report)
  }

  private func renderObservation(rootSeed: UInt64,
    primary: ProfessionalQualityPrimaryArtifacts
  ) async throws -> LongHorizonPolicyObservation {
    let binding = try executionBinding()
    var routes: [LongHorizonRuntimePolicyObservation] = []
    for rate in [44_100.0, 48_000.0] {
      let journey = await Task.detached(priority: .userInitiated) {
        Self.renderPreparedRoute(rootSeed: rootSeed, sampleRate: rate, primary: primary)
      }.value
      try writeJourney(journey, binding: binding)
      guard try executionBinding() == binding, journey.completedRequestedScope,
        journey.endsAtClosedLeaf, journey.failureCode == nil
      else { throw LongHorizonProfessionalPolicyError.insufficientEvidence }
      routes.append(try LongHorizonRuntimePolicyObservation(semanticReport: journey.semantic,
        signalReport: journey.signal, effectReport: journey.effects,
        primaryPolicyVersion: primary.evaluator.policyVersion))
    }
    return try LongHorizonPolicyObservation(routeObservations: routes)
  }

  private func writeJourney(_ journey: PreparedRouteJourney, binding: String) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let object: [String: Any] = ["schema": "autotechno-long-horizon-shared-journey.v1",
      "inputBindingFingerprint": binding, "primaryPolicyVersion": LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion,
      "journey": try JSONSerialization.jsonObject(with: encoder.encode(journey)),
      "sourceScope": "current-shared-preparation-primary-only-bootstrap",
      "archiveImport": false, "runtimeActivation": false, "fullRuntimeQualification": false,
      "longHorizonQualification": false, "capacityOrOutputQualification": false]
    let directory = try outputDirectory()
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
      .write(to: directory.appendingPathComponent("actual-journey-\(journey.rootSeed)-\(Int(journey.sampleRate)).json"), options: .atomic)
  }

  @Test("Probe the actual native bootstrap through the same full-journey owner",
    .enabled(if: ProcessInfo.processInfo.environment["AUTOTECHNO_RUN_LONG_HORIZON_SHARED_PROBE"] == "1"))
  func probeSharedPreparedBootstrap() async throws {
    let primary = try loadPrimary(), binding = try executionBinding()
    try prepareOutputNamespace()
    for rate in [44_100.0, 48_000.0] {
      let journey = await Task.detached(priority: .userInitiated) {
        Self.renderPreparedRoute(rootSeed: 48_291, sampleRate: rate, primary: primary, prefixPhraseCount: 4)
      }.value
      try writeJourney(journey, binding: binding)
      #expect(journey.completedRequestedScope && journey.failureCode == nil)
      #expect(journey.consumedPhraseCount == 4)
      #expect(journey.signal.observationCount == 4 && journey.signal.omittedPhraseCount == 0)
      #expect(journey.effects.phraseCount == 4 && journey.effects.barCount == journey.semantic.observedBarCount)
      #expect(try executionBinding() == binding)
    }
  }

  private func writeArtifacts(
    profile: LongHorizonProfessionalProfile,
    adversarial: LongHorizonAdversarialSuiteReport,
    holdout: LongHorizonHoldoutQualification
  ) throws {
    let directory = try outputDirectory()
    try profile.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.profileResource).json"))
    try adversarial.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.adversarialResource).json"))
    try holdout.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.holdoutResource).json"))
  }

  private static func progress(_ message: String) {
    guard
      let data = "AUTOTECHNO_LONG_HORIZON_CALIBRATION \(message)\n"
        .data(using: .utf8)
    else { return }
    FileHandle.standardError.write(data)
  }
}
