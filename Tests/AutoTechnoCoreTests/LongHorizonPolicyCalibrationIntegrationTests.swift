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

  private struct RecoveryRejection: Codable, Sendable {
    let targetPhraseIndex: Int
    let requestFingerprint: String
    let incomingCoreFingerprint: String
    let candidateFingerprint: String
    let reasonCodes: [String]
    let ordinal: Int
    let wave: UInt64
    let overdueDebtCount: Int
  }

  private struct RecoveryRepeat: Codable, Sendable {
    let targetPhraseIndex: Int
    let sourceRequestFingerprint: String
    let incomingCoreFingerprint: String
    let startSample: Int64
    let endSample: Int64
    let barCount: Int
    let frameCount: Int64
    let selection: String
    let pcmFingerprint: String
    let nextOrdinal: Int
    let nextWave: UInt64
    let presentedRepeatBars: UInt64
  }

  private struct RepeatSelection: Sendable {
    let selection: String
    let pcmFingerprint: String
    let frameCount: Int64
    let barCount: Int
  }

  private struct PreparedRouteJourney: Codable, Sendable {
    let rootSeed: UInt64
    let sampleRate: Double
    let consumedPhraseCount: Int
    let newPreparationAttemptCount: Int
    let rejectedPreparations: [RecoveryRejection]
    let accountedRepeats: [RecoveryRepeat]
    let firstRefusalAcceptedTraversalFingerprint: String?
    let acceptedFrameCount: Int64
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

  /// Check the executing synchronous preparation boundary, not an async actor.
  private static func prepareBootstrapSource(request: PhrasePreparationRequest,
    director: AutonomousSessionDirector, primary: ProfessionalQualityPrimaryArtifacts
  ) -> PerformancePreparationOutcome {
    guard !Thread.isMainThread else {
      return .failed(PhrasePreparationFailure(stage: "long-journey", code: "preparation-not-detached"))
    }
    return AutonomousPerformancePreparer.prepareDiagnosing(request: request,
      director: director, artifacts: primary, longHorizonArtifacts: nil)
  }

  private static func renderPreparedRoute(rootSeed: UInt64, sampleRate: Double,
    primary: ProfessionalQualityPrimaryArtifacts, prefixPhraseCount: Int? = nil
  ) async -> PreparedRouteJourney {
    let director = AutonomousSessionDirector(rootSeed: rootSeed)
    var state = director.initialState(), renderState = RenderState()
    var graphState = GeneratedDSPContinuationState()
    var graph: DSPGraphPlan?, predecessor: PreparedPerformancePhrase?
    var semantic = LongHorizonSemanticTrajectoryAccumulator(rootSeed: rootSeed,
      startingPhraseIndex: 0, startingBar: 0)
    var signal = LongHorizonSignalTrajectoryAccumulator(rootSeed: rootSeed, sampleRate: sampleRate)
    var effects = LongHorizonEffectDoseAccumulator(rootSeed: rootSeed)
    var samples: Int64 = 0, acceptedFrames: Int64 = 0
    var retry = AutonomousQualityRetryContinuation()
    var coherentRepeats = 0, repeatBars = 0
    var recoveryOrigin: PhrasePreparationReplayIdentity?
    var rejections: [RecoveryRejection] = [], repeats: [RecoveryRepeat] = []
    var firstRefusalTraversal: String?
    var consumed = 0, newPreparations = 0, ownedChildren = 0, peak = 0
    var closedLeaf = false, complete = false, failure: String?
    var details: [String] = []
    var sink = StreamingFNV1a(); sink.domain("long-horizon-actual-prepared-traversal.v1")
    do {
      // Bounds accepted steps plus fresh serial proposals, including startup waves.
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
          liveTargetStartSample: nil,
          qualityRecoveryContext: retry.context(for: state.phraseIndex)),
          sourceState: state, incomingLongHorizonState: nil,
          incomingRenderState: renderState, incomingGraphState: graphState,
          previousGraph: graph, pendingLiveMasterBinding: nil)
        if let origin = recoveryOrigin,
          (request.replayIdentity.sourceStateFingerprint != origin.sourceStateFingerprint ||
            request.replayIdentity.incomingRenderStateFingerprint != origin.incomingRenderStateFingerprint ||
            request.replayIdentity.incomingGraphStateFingerprint != origin.incomingGraphStateFingerprint ||
            request.replayIdentity.previousGraphFingerprint != origin.previousGraphFingerprint) {
          failure = "recovery-origin-changed"; break
        }
        let source: PreparedPerformancePhrase
        var consumedOwnedChild = false
        do {
          let owned = try predecessor?.continuationAtBoundary(sessionState: state,
            longHorizonState: nil, sampleRate: sampleRate, channelCount: 2,
            routeGeneration: 0, actualStartSample: samples).get()
          if let owned {
            guard retry.context(for: state.phraseIndex) == .neutral else {
              throw PhrasePreparationFailure(stage: "long-journey", code: "protected-child-recovery-context")
            }
            predecessor = nil
            source = owned; ownedChildren += 1; consumedOwnedChild = true
          }
          else {
            newPreparations += 1
            // Suspend the journey driver before entering the shared owner.
            // This matches the host's detached preparation boundary and keeps
            // route/controller temporaries out of its bounded worker stack.
            let preparation = Task.detached(priority: .userInitiated) {
              Self.prepareBootstrapSource(request: request, director: director, primary: primary)
            }
            let outcome = await withTaskCancellationHandler {
              await preparation.value
            } onCancel: {
              preparation.cancel()
            }
            switch outcome {
            case .prepared(let prepared): source = prepared
            case .failed(let refused): throw refused
            }
          }
        } catch let refused as PhrasePreparationFailure {
          failure = refused.stage + ":" + refused.code; details = Array(refused.details.prefix(24)); break
        } catch { failure = "continuation-refused"; break }
        if let budget = source.preparationChainResourceBudget {
          peak = max(peak, budget.reservedPeakWorkingByteCount)
        }
        if !source.prepared.commitEligible {
          guard !consumedOwnedChild,
            source.request.replayIdentity.matches(source.request),
            source.request.replayIdentity.fingerprint == request.replayIdentity.fingerprint
          else { failure = "rejected-source-replay-mismatch"; break }
          if firstRefusalTraversal == nil {
            firstRefusalTraversal = fixedWidthFingerprintHex(sink.value)
          }
          let decision = source.prepared.qualityDecision
          rejections.append(RecoveryRejection(targetPhraseIndex: state.phraseIndex,
            requestFingerprint: request.replayIdentity.fingerprint,
            incomingCoreFingerprint: request.replayIdentity.sourceStateFingerprint,
            candidateFingerprint: source.prepared.selectedCandidateEvidence.fingerprint,
            reasonCodes: decision.reasonCodes.map(\.rawValue),
            ordinal: request.key.qualityRetryOrdinal,
            wave: request.key.qualityRecoveryContext.wave,
            overdueDebtCount: source.prepared.plan.interest.overdueDebtCount))
          guard decision.isRetryableCandidateRejection else {
            failure = "prepared-source-quality:" + decision.outcome.rawValue
            details = Array((source.prepared.commitFailureDiagnostics +
              source.prepared.qualityDiagnosticDetails +
              decision.reasonCodes.map { "quality=" + $0.rawValue } +
              Self.refusalRecoveryDiagnostics(request: source.request,
                rejected: source.prepared, director: director)).prefix(24))
            break
          }
          recoveryOrigin = recoveryOrigin ?? request.replayIdentity
          let nextRetry = retry.recordingCalibratedRejection(decision: decision,
            targetPhraseIndex: state.phraseIndex)
          guard nextRetry != retry else { failure = "recovery-context-stalled"; break }
          retry = nextRetry
          sink.string("actual-core-rejection.v1")
          sink.string(request.replayIdentity.fingerprint)
          sink.string(source.prepared.selectedCandidateEvidence.fingerprint)
          if predecessor == nil {
            // The host's initial phase has no accepted PCM to repeat. Each
            // finite startup wave yields before opening the next one.
            guard consumed == 0 && state.phraseIndex == 0 else {
              failure = "recovery-accepted-source-missing"; break
            }
            if retry.isExhausted(for: state.phraseIndex) {
              await Task.yield()
              retry = retry.beginningNextWave(targetPhraseIndex: state.phraseIndex)
            }
          } else {
            let scheduling = AutonomousQualityRecoverySchedulingPolicy.decide(
              retryable: true, waveExhausted: retry.isExhausted(for: state.phraseIndex),
              coherentRepeatCount: coherentRepeats)
            if scheduling == .awaitFirstCoherentRepeat || scheduling == .yieldUntilNextBoundary {
              guard let accepted = predecessor,
                let selection = Self.selectRepeat(source: accepted, incomingRequest: request,
                  coherentRepeatCount: coherentRepeats + 1) else {
                failure = Task.isCancelled ? "cancelled" : "recovery-repeat-source-unavailable"; break
              }
              let nextBars = repeatBars.addingReportingOverflow(selection.barCount)
              let nextSample = samples.addingReportingOverflow(selection.frameCount)
              guard !nextBars.overflow, nextBars.partialValue <= 10_400,
                !nextSample.overflow else { failure = "recovery-presentation-bound"; break }
              retry = retry.recordingPresentedRepeat(targetPhraseIndex: state.phraseIndex,
                barCount: selection.barCount)
              if retry.isExhausted(for: state.phraseIndex) {
                retry = retry.beginningNextWave(targetPhraseIndex: state.phraseIndex)
              }
              repeats.append(RecoveryRepeat(targetPhraseIndex: state.phraseIndex,
                sourceRequestFingerprint: accepted.request.replayIdentity.fingerprint,
                incomingCoreFingerprint: request.replayIdentity.sourceStateFingerprint,
                startSample: samples, endSample: nextSample.partialValue,
                barCount: selection.barCount, frameCount: selection.frameCount,
                selection: selection.selection, pcmFingerprint: selection.pcmFingerprint,
                nextOrdinal: retry.ordinal(for: state.phraseIndex), nextWave: retry.wave,
                presentedRepeatBars: retry.presentedRepeatBars))
              sink.string("selected-accepted-repeat.v1"); sink.string(selection.pcmFingerprint)
              sink.int64(samples); sink.int64(nextSample.partialValue)
              samples = nextSample.partialValue; repeatBars = nextBars.partialValue; coherentRepeats += 1
              Self.progress("recovery root=\(rootSeed) rate=\(Int(sampleRate)) target=\(state.phraseIndex) wave=\(retry.wave) ordinal=\(retry.ordinal) repeat-bars=\(retry.presentedRepeatBars) selection=\(selection.selection)")
            } else if scheduling != .continueSerially {
              failure = "recovery-scheduling-refused"; break
            }
          }
          continue
        }
        var nextSemantic = semantic, nextSignal = signal, nextEffects = effects
        let semanticStatus = nextSemantic.observe(plan: source.prepared.plan, incomingState: state)
        let signalStatus = source.prepared.longHorizonSignalTrajectoryEvidence.map { nextSignal.observe($0) }
        let effectStatus = source.prepared.longHorizonEffectDoseEvidence.map { nextEffects.observe($0) }
        guard source.continuationOwnershipIsValid,
          source.request.replayIdentity.sourceStateFingerprint == AutonomousCandidateFingerprint.sessionState(state),
          let budget = source.preparationChainResourceBudget, budget.reservedPeakWorkingByteCount <= AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount,
          let actualSignal = source.prepared.longHorizonSignalTrajectoryEvidence,
          source.prepared.longHorizonEffectDoseEvidence != nil,
          semanticStatus == .accepted, signalStatus == .accepted, effectStatus == .accepted,
          let frames = Int64(exactly: source.prepared.audioPreflight.quality.analyzedFrameCount), frames > 0
        else {
          failure = "ineligible-or-inconsistent-prepared-source"
          details = [
            "ownership=" + String(source.continuationOwnershipIsValid),
            "replay-core-match=" + String(source.request.replayIdentity.sourceStateFingerprint == AutonomousCandidateFingerprint.sessionState(state)),
            "resource-budget-present=" + String(source.preparationChainResourceBudget != nil),
            "reserved-bytes=" + String(source.preparationChainResourceBudget?.reservedPeakWorkingByteCount ?? -1),
            "semantic=" + String(describing: semanticStatus),
            "signal=" + String(describing: signalStatus),
            "effects=" + String(describing: effectStatus),
          ]
          break
        }
        let end = samples.addingReportingOverflow(frames)
        let nextAcceptedFrames = acceptedFrames.addingReportingOverflow(frames)
        guard !end.overflow, !nextAcceptedFrames.overflow else { failure = "sample-boundary-overflow"; break }
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
        samples = end.partialValue; acceptedFrames = nextAcceptedFrames.partialValue; consumed += 1
        retry = AutonomousQualityRetryContinuation(); coherentRepeats = 0; recoveryOrigin = nil
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
    if !complete && failure == nil { failure = "accepted-or-recovery-step-bound" }
    return PreparedRouteJourney(rootSeed: rootSeed, sampleRate: sampleRate,
      consumedPhraseCount: consumed, newPreparationAttemptCount: newPreparations,
      rejectedPreparations: rejections, accountedRepeats: repeats,
      firstRefusalAcceptedTraversalFingerprint: firstRefusalTraversal,
      acceptedFrameCount: acceptedFrames,
      ownedChildConsumptionCount: ownedChildren, endSample: samples,
      traversalFingerprint: fixedWidthFingerprintHex(sink.value), endsAtClosedLeaf: closedLeaf,
      reservedNumericPeakBytes: peak, failureCode: failure, failureDetails: details,
      completedRequestedScope: complete, requestedPrefixPhraseCount: prefixPhraseCount,
      requestedMinimumBars: prefixPhraseCount == nil ? 7_800 : 0,
      semantic: semantic.report(), signal: signal.report,
      effects: effects.report)
  }

  /// Reduce the actual retained playback selection at an offline sample
  /// boundary. The accepted source, incoming state and DSP continuation must
  /// agree; a protected measured child never supplies repeat material.
  private static func selectRepeat(source: PreparedPerformancePhrase,
    incomingRequest: PhrasePreparationRequest, coherentRepeatCount: Int
  ) -> RepeatSelection? {
    guard coherentRepeatCount > 0, source.prepared.commitEligible,
      source.continuationOwnershipIsValid, !source.requiresQualifiedContinuation,
      source.outgoingLongHorizonState == nil,
      !source.request.key.routeRecovery, !incomingRequest.key.routeRecovery,
      incomingRequest.incomingLongHorizonState == nil,
      incomingRequest.pendingLiveMasterBinding == nil,
      incomingRequest.key.liveTargetStartSample == nil,
      source.request.key.sampleRate == incomingRequest.key.sampleRate,
      source.request.key.channelCount == incomingRequest.key.channelCount,
      source.request.key.routeGeneration == incomingRequest.key.routeGeneration,
      incomingRequest.replayIdentity.matches(incomingRequest),
      incomingRequest.replayIdentity.sourceStateFingerprint == AutonomousCandidateFingerprint.sessionState(
        source.request.sourceState.advance(using: source.prepared.plan,
          quality: source.prepared.qualityContinuationState,
          liveMasterHeadroom: source.prepared.liveMasterHeadroomContinuationState,
          longHorizonDecision: source.longHorizonDecision)),
      incomingRequest.replayIdentity.incomingRenderStateFingerprint ==
        AutonomousCandidateFingerprint.renderState(source.prepared.endingRenderState),
      incomingRequest.replayIdentity.incomingGraphStateFingerprint ==
        AutonomousCandidateFingerprint.generatedDSPState(source.prepared.endingGraphState),
      incomingRequest.replayIdentity.previousGraphFingerprint ==
        AutonomousCandidateFingerprint.graph(source.prepared.graph)
    else { return nil }
    let mode = RepeatHoldEvolutionBoundaryPolicy.decide(
      coherentRepeatCount: coherentRepeatCount, successorPrepared: false,
      qualifiedPatternFamilies: source.prepared.qualifiedRepeatHoldPatternFamilies)
    var sink = StreamingFNV1a(); sink.domain("offline-selected-accepted-repeat-pcm.v1")
    sink.string(source.request.replayIdentity.fingerprint)
    let selection = mode.patternFamily?.rawValue ?? "exact-accepted-pcm"
    sink.string(selection)
    var frameCount: Int64 = 0, bars = 0
    func observe(bar: Int, left: [Float], right: [Float]) -> Bool {
      guard !Task.isCancelled, !left.isEmpty, left.count == right.count,
        let count = Int64(exactly: left.count) else { return false }
      let next = frameCount.addingReportingOverflow(count)
      guard !next.overflow else { return false }
      sink.int(bar); sink.int(left.count)
      for (index, sample) in left.enumerated() {
        if index.isMultiple(of: 4096), Task.isCancelled { return false }
        sink.float(sample)
      }
      for (index, sample) in right.enumerated() {
        if index.isMultiple(of: 4096), Task.isCancelled { return false }
        sink.float(sample)
      }
      frameCount = next.partialValue; bars += 1; return true
    }
    if let family = mode.patternFamily {
      guard let variant = source.prepared.repeatHoldEvolution(for: family),
        variant.blocks.count == source.prepared.blocks.count else { return nil }
      for (index, block) in variant.blocks.enumerated() {
        let original = source.prepared.blocks[index]
        guard block.bar == original.bar, block.left.count == original.left.count,
          observe(bar: block.bar, left: block.left, right: block.right) else { return nil }
      }
    } else {
      for block in source.prepared.blocks {
        guard observe(bar: block.bar, left: block.left, right: block.right) else { return nil }
      }
    }
    guard bars == source.prepared.plan.barCount,
      frameCount == Int64(exactly: source.prepared.audioPreflight.quality.analyzedFrameCount)
    else { return nil }
    return RepeatSelection(selection: selection,
      pcmFingerprint: fixedWidthFingerprintHex(sink.value), frameCount: frameCount, barCount: bars)
  }

  /// Inspect the existing Core transition from this actual refusal only.
  /// The score-only next proposal has no rendered/accepted evidence. In
  /// particular, this inspection never presents a repeat, opens a wave, retries
  /// preparation, changes accepted continuation or bypasses the original gate.
  private static func refusalRecoveryDiagnostics(request: PhrasePreparationRequest,
    rejected: PreparedAutonomousPhrase, director: AutonomousSessionDirector
  ) -> [String] {
    let context = request.key.qualityRecoveryContext
    let decision = rejected.qualityDecision
    let retry = AutonomousQualityRetryContinuation(
      targetPhraseIndex: request.key.phraseIndex, ordinal: context.ordinal,
      wave: context.wave, presentedRepeatBars: context.presentedRepeatBars,
      recoveryIntent: context.intent)
      .recordingCalibratedRejection(decision: decision,
        targetPhraseIndex: request.key.phraseIndex)
    let nextContext = retry.context(for: request.key.phraseIndex)
    let scheduling = AutonomousQualityRecoverySchedulingPolicy.decide(
      retryable: decision.isRetryableCandidateRejection,
      waveExhausted: retry.isExhausted(for: request.key.phraseIndex),
      coherentRepeatCount: 0)
    let nextPlan = director.plan(from: request.sourceState,
      qualityRecoveryContext: nextContext)
    return [
      "recovery-inspection=core-score-only-not-rendered-not-authorized",
      "refused-request=" + request.replayIdentity.fingerprint,
      "refused-core=" + AutonomousCandidateFingerprint.sessionState(request.sourceState),
      "refused-plan-interest=\(rejected.plan.interest.score),valid=\(rejected.plan.interest.valid),space=\(rejected.plan.interest.intentionalSpace),overactivity=\(rejected.plan.interest.overactivityPenalty),overdue=\(rejected.plan.interest.overdueDebtCount)",
      "recovery-retryable=\(decision.isRetryableCandidateRejection),scheduling=\(scheduling)",
      "recovery-context=wave-\(nextContext.wave),ordinal-\(nextContext.ordinal),presented-bars-\(nextContext.presentedRepeatBars),density-\(nextContext.intent.symbolicDensity.rawValue),spectral-\(nextContext.intent.spectralMovement.rawValue),crest-\(nextContext.intent.kickCrestReduction.rawValue)",
      "next-score-only-interest=\(nextPlan.interest.score),valid=\(nextPlan.interest.valid),space=\(nextPlan.interest.intentionalSpace),overactivity=\(nextPlan.interest.overactivityPenalty),overdue=\(nextPlan.interest.overdueDebtCount)",
    ]
  }

  private func renderObservation(rootSeed: UInt64,
    primary: ProfessionalQualityPrimaryArtifacts
  ) async throws -> LongHorizonPolicyObservation {
    let binding = try executionBinding()
    var routes: [LongHorizonRuntimePolicyObservation] = []
    for rate in [44_100.0, 48_000.0] {
      let journey = await Task.detached(priority: .userInitiated) {
        await Self.renderPreparedRoute(rootSeed: rootSeed, sampleRate: rate, primary: primary)
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
    let object: [String: Any] = ["schema": "autotechno-long-horizon-shared-journey.v2",
      "inputBindingFingerprint": binding, "primaryPolicyVersion": LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion,
      "journey": try JSONSerialization.jsonObject(with: encoder.encode(journey)),
      "sourceScope": "current-shared-preparation-primary-only-bootstrap-with-core-recovery",
      "presentationScope": "offline-selected-retained-pcm-no-device-scheduling-proof",
      "memoryScope": "numeric-reservation-covers-preparation-chain-not-combined-held-playback",
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
        await Self.renderPreparedRoute(rootSeed: 48_291, sampleRate: rate, primary: primary, prefixPhraseCount: 4)
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

  @Test("Retained accepted repeat selection binds exact geometry and refuses foreign continuation")
  func retainedRepeatSelectionIsBound() async throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    let state = director.initialState()
    let key = PhrasePreparationKey(sessionSeed: state.rootSeed, phraseIndex: state.phraseIndex,
      sampleRate: 8_000, channelCount: 2, routeRecovery: false,
      qualityRevision: state.quality.revision, qualityPolicyVersion: state.quality.policyVersion,
      qualityControllerFingerprint: nil, routeGeneration: 0,
      incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
      incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint,
      pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil,
      liveTargetStartSample: nil)
    let request = PhrasePreparationRequest(key: key, sourceState: state,
      incomingLongHorizonState: nil, incomingRenderState: RenderState(),
      incomingGraphState: GeneratedDSPContinuationState(), previousGraph: nil,
      pendingLiveMasterBinding: nil)
    let result = await Task.detached {
      AutonomousPerformancePreparer.prepareChainDiagnosing(request: request, director: director,
        longHorizonPolicy: nil, makeEvaluator: { _ in AcceptingPrimaryTestEvaluator() },
        cancellationRequested: { false })
    }.value
    let source = try #require(result.preparedPhrase)
    #expect(source.prepared.commitEligible && !source.requiresQualifiedContinuation)
    let advanced = state.advance(using: source.prepared.plan,
      quality: source.prepared.qualityContinuationState,
      liveMasterHeadroom: source.prepared.liveMasterHeadroomContinuationState,
      longHorizonDecision: source.longHorizonDecision)
    let nextKey = PhrasePreparationKey(sessionSeed: advanced.rootSeed,
      phraseIndex: advanced.phraseIndex, sampleRate: 8_000, channelCount: 2,
      routeRecovery: false, qualityRevision: advanced.quality.revision,
      qualityPolicyVersion: advanced.quality.policyVersion,
      qualityControllerFingerprint: advanced.quality.observedControllerStateFingerprint ?? advanced.quality.acceptedControllerStateFingerprint,
      routeGeneration: 0, incomingLiveMasterRevision: advanced.liveMasterHeadroom.revision,
      incomingLiveMasterStateFingerprint: advanced.liveMasterHeadroom.fingerprint,
      pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil,
      liveTargetStartSample: nil)
    let next = PhrasePreparationRequest(key: nextKey, sourceState: advanced,
      incomingLongHorizonState: nil, incomingRenderState: source.prepared.endingRenderState,
      incomingGraphState: source.prepared.endingGraphState, previousGraph: source.prepared.graph,
      pendingLiveMasterBinding: nil)
    let first = try #require(Self.selectRepeat(source: source, incomingRequest: next,
      coherentRepeatCount: 1))
    #expect(first.selection == "exact-accepted-pcm")
    #expect(first.barCount == source.prepared.plan.barCount)
    #expect(first.frameCount == source.prepared.blocks.reduce(Int64(0)) { $0 + Int64($1.left.count) })
    #expect(Self.selectRepeat(source: source, incomingRequest: next,
      coherentRepeatCount: 1)?.pcmFingerprint == first.pcmFingerprint)
    let second = try #require(Self.selectRepeat(source: source, incomingRequest: next,
      coherentRepeatCount: 2))
    let expected = RepeatHoldEvolutionBoundaryPolicy.decide(coherentRepeatCount: 2,
      successorPrepared: false,
      qualifiedPatternFamilies: source.prepared.qualifiedRepeatHoldPatternFamilies)
    #expect(second.selection == (expected.patternFamily?.rawValue ?? "exact-accepted-pcm"))
    #expect(second.frameCount == first.frameCount && second.barCount == first.barCount)
    let foreignCore = PhrasePreparationRequest(key: nextKey, sourceState: state,
      incomingLongHorizonState: nil, incomingRenderState: source.prepared.endingRenderState,
      incomingGraphState: source.prepared.endingGraphState, previousGraph: source.prepared.graph,
      pendingLiveMasterBinding: nil)
    #expect(Self.selectRepeat(source: source, incomingRequest: foreignCore,
      coherentRepeatCount: 1) == nil)
    var foreignRender = source.prepared.endingRenderState
    foreignRender.barIndex += 1
    let foreignDSP = PhrasePreparationRequest(key: nextKey, sourceState: advanced,
      incomingLongHorizonState: nil, incomingRenderState: foreignRender,
      incomingGraphState: source.prepared.endingGraphState, previousGraph: source.prepared.graph,
      pendingLiveMasterBinding: nil)
    #expect(Self.selectRepeat(source: source, incomingRequest: foreignDSP,
      coherentRepeatCount: 1) == nil)
    #expect(Self.selectRepeat(source: source, incomingRequest: next,
      coherentRepeatCount: 0) == nil)
    #expect(source.request.replayIdentity.fingerprint == request.replayIdentity.fingerprint)
    #expect(AutonomousCandidateFingerprint.sessionState(state) == request.replayIdentity.sourceStateFingerprint)
  }

  @Test("Probe actual native recovery past the frozen structural-debt refusal",
    .enabled(if: ProcessInfo.processInfo.environment["AUTOTECHNO_RUN_LONG_HORIZON_RECOVERY_PROBE"] == "1"))
  func probeNativeCoreRecovery() async throws {
    let primary = try loadPrimary(), binding = try executionBinding()
    try prepareOutputNamespace()
    // This archive supplies a comparison digest only. All new state, PCM,
    // accepted evidence and decisions are generated through the shared owner.
    let referenceURL = repositoryRoot.appendingPathComponent(
      "docs/local/reports/rms-trajectory-floor/native-refusal-recovery-inspection-60892a6/actual-journey-48291-44100.json")
    let reference = try #require(try JSONSerialization.jsonObject(with:
      Data(contentsOf: referenceURL)) as? [String: Any])
    let referenceJourney = try #require(reference["journey"] as? [String: Any])
    let prefixFingerprint = try #require(referenceJourney["traversalFingerprint"] as? String)
    for rate in [44_100.0, 48_000.0] {
      let journey = await Task.detached(priority: .userInitiated) {
        await Self.renderPreparedRoute(rootSeed: 48_291, sampleRate: rate, primary: primary,
          prefixPhraseCount: 36)
      }.value
      try writeJourney(journey, binding: binding)
      #expect(journey.completedRequestedScope && journey.failureCode == nil)
      #expect(journey.consumedPhraseCount == 36)
      #expect(journey.signal.observationCount == 36 && journey.signal.omittedPhraseCount == 0)
      #expect(journey.effects.phraseCount == 36 && journey.effects.barCount == journey.semantic.observedBarCount)
      let firstRejected = try #require(journey.rejectedPreparations.first)
      #expect(firstRejected.targetPhraseIndex == 33 && firstRejected.ordinal == 0)
      #expect(firstRejected.overdueDebtCount == 1)
      let firstRepeat = try #require(journey.accountedRepeats.first)
      #expect(firstRepeat.targetPhraseIndex == 33 && firstRepeat.selection == "exact-accepted-pcm")
      #expect(firstRepeat.incomingCoreFingerprint == firstRejected.incomingCoreFingerprint)
      #expect(firstRepeat.nextOrdinal == 1 && firstRepeat.nextWave == 0)
      #expect(firstRepeat.presentedRepeatBars == UInt64(firstRepeat.barCount))
      #expect(journey.endSample == journey.acceptedFrameCount +
        journey.accountedRepeats.reduce(Int64(0)) { $0 + $1.frameCount })
      if rate == 44_100 { #expect(journey.firstRefusalAcceptedTraversalFingerprint == prefixFingerprint) }
      #expect(try executionBinding() == binding)
    }
  }

  private static func progress(_ message: String) {
    guard
      let data = "AUTOTECHNO_LONG_HORIZON_CALIBRATION \(message)\n"
        .data(using: .utf8)
    else { return }
    FileHandle.standardError.write(data)
  }
}
