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

  private static func boundedRecoveryInput(_ path: String, maximumBytes: Int) throws -> Data {
    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    guard attributes[.type] as? FileAttributeType == .typeRegular,
      let size = attributes[.size] as? NSNumber, size.intValue > 0, size.intValue <= maximumBytes else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer { try? handle.close() }
    let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
    guard !data.isEmpty, data.count <= maximumBytes else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
    return data
  }

  @Test("Recovery requests refuse empty, oversized and symbolic-link input")
  func boundedRecoveryRequestInput() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("request.json")
    try Data("{}".utf8).write(to: path)
    #expect(try Self.boundedRecoveryInput(path.path, maximumBytes: 2) == Data("{}".utf8))
    for data in [Data(), Data("123".utf8)] {
      try data.write(to: path)
      #expect(throws: LongHorizonProfessionalPolicyError.invalidEvidence) {
        try Self.boundedRecoveryInput(path.path, maximumBytes: 2)
      }
    }
    let link = directory.appendingPathComponent("alias.json")
    try Data("{}".utf8).write(to: path)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: path)
    #expect(throws: LongHorizonProfessionalPolicyError.invalidEvidence) {
      try Self.boundedRecoveryInput(link.path, maximumBytes: 2)
    }
  }

  /// The explicitly approved interrupted-study exception renders a missing
  /// route from initial state. It never reads a saved journey or runtime state.
  private struct InterruptedRouteRequest: Codable, Sendable {
    let schema: String
    let rootSeed: UInt64
    let sampleRate: Int
    let originalSource: String
    let originalInputBinding: String
    let harnessSource: String
    let recoveryInputBinding: String
    let manifestSHA256: String
    let buildMetadataSHA256: String
    let primaryPolicyVersion: String
    let preservedCompleteHistoryCount: Int
    let freshCompleteRoute: Bool

    func validate() throws {
      func hex(_ value: String, count: Int) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy {
          (48...57).contains($0) || (97...102).contains($0)
        }
      }
      let missing = rootSeed == 141_421 && sampleRate == 48_000 ||
        [173_205, 246_813, 271_828, 314_159].contains(rootSeed) &&
          [44_100, 48_000].contains(sampleRate)
      guard schema == "autotechno-interrupted-long-route-request.v1", missing,
        originalSource == "5b81cefa3cf491b644dcee64a28cbefdd7bbc17d",
        originalInputBinding == "d1f562e91f703a86",
        hex(harnessSource, count: 40), harnessSource != originalSource,
        hex(recoveryInputBinding, count: 16), recoveryInputBinding != originalInputBinding,
        hex(manifestSHA256, count: 64), hex(buildMetadataSHA256, count: 64),
        primaryPolicyVersion == LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion,
        preservedCompleteHistoryCount == 9, freshCompleteRoute
      else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    }
  }

  @Test("Interrupted-study route selection refuses completed, foreign and retagged inputs")
  func interruptedRouteSelection() throws {
    let base: [String: Any] = [
      "schema": "autotechno-interrupted-long-route-request.v1",
      "rootSeed": 141_421, "sampleRate": 48_000,
      "originalSource": "5b81cefa3cf491b644dcee64a28cbefdd7bbc17d",
      "originalInputBinding": "d1f562e91f703a86",
      "harnessSource": String(repeating: "a", count: 40),
      "recoveryInputBinding": "1111111111111111",
      "manifestSHA256": String(repeating: "b", count: 64),
      "buildMetadataSHA256": String(repeating: "c", count: 64),
      "primaryPolicyVersion": LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion,
      "preservedCompleteHistoryCount": 9, "freshCompleteRoute": true]
    func check(_ object: [String: Any]) throws {
      try JSONDecoder().decode(InterruptedRouteRequest.self,
        from: JSONSerialization.data(withJSONObject: object)).validate()
    }
    for (root, rates) in [(141_421, [48_000]), (173_205, [44_100, 48_000]),
      (246_813, [44_100, 48_000]), (271_828, [44_100, 48_000]), (314_159, [44_100, 48_000])] {
      for rate in rates {
        var object = base; object["rootSeed"] = root; object["sampleRate"] = rate
        try check(object)
      }
    }
    let invalid: [(String, Any)] = [
      ("rootSeed", 48_291), ("sampleRate", 44_100), ("sampleRate", 8_000),
      ("originalSource", String(repeating: "0", count: 40)),
      ("originalInputBinding", "foreign"), ("harnessSource", "unresolved"),
      ("recoveryInputBinding", "d1f562e91f703a86"), ("manifestSHA256", ""),
      ("buildMetadataSHA256", ""), ("primaryPolicyVersion", "foreign"),
      ("preservedCompleteHistoryCount", 8), ("freshCompleteRoute", false)]
    for (key, value) in invalid {
      var object = base; object[key] = value
      #expect(throws: LongHorizonProfessionalPolicyError.invalidEvidence) { try check(object) }
    }
  }

  @Test("Render only one explicitly approved missing native Long-study route")
  func renderInterruptedStudyRoute() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["AUTOTECHNO_RUN_INTERRUPTED_LONG_ROUTE"] == "1" else { return }
    #if DEBUG
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    #endif
    guard environment["AUTOTECHNO_RUN_LONG_HORIZON_CALIBRATION"] != "1",
      let path = environment["AUTOTECHNO_INTERRUPTED_LONG_ROUTE_REQUEST"]
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let data = try Self.boundedRecoveryInput(path, maximumBytes: 16_384)
    let request = try JSONDecoder().decode(InterruptedRouteRequest.self, from: data)
    try request.validate()
    let primary = try loadPrimary()
    guard primary.evaluator.policyVersion == request.primaryPolicyVersion else {
      throw LongHorizonProfessionalPolicyError.profileMismatch
    }
    try prepareOutputNamespace()
    let journey = await Task.detached(priority: .userInitiated) {
      await Self.renderPreparedRoute(rootSeed: request.rootSeed,
        sampleRate: Double(request.sampleRate), primary: primary)
    }.value
    // The supervisor authenticates the frozen production objects/resources and
    // separately bound harness before and after this process. These labels do
    // not substitute the original study binding for the new executable inputs.
    guard try Self.boundedRecoveryInput(path, maximumBytes: 16_384) == data else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
    try writeJourney(journey, binding: request.recoveryInputBinding, recovery: [
      "schema": "autotechno-interrupted-long-route-provenance.v1",
      "originalSource": request.originalSource,
      "originalInputBinding": request.originalInputBinding,
      "harnessSource": request.harnessSource,
      "manifestSHA256": request.manifestSHA256,
      "buildMetadataSHA256": request.buildMetadataSHA256,
      "routeOrigin": "fresh-complete-execution-from-initial-state"])
    guard journey.completedRequestedScope, journey.endsAtClosedLeaf,
      journey.failureCode == nil else { throw LongHorizonProfessionalPolicyError.insufficientEvidence }
    Self.progress("recovered-missing root=\(request.rootSeed) rate=\(request.sampleRate) "
      + "binding=\(request.recoveryInputBinding) original=\(request.originalInputBinding)")
  }

  private struct InterruptedAssembly: Decodable {
    struct Route: Decodable {
      let rootSeed: UInt64
      let sampleRate: Int
      let path: String
      let origin: String
    }
    let schema: String
    let provenance: InterruptedRouteRequest
    let routes: [Route]
  }

  private struct RecordedJourney: Decodable {
    let schema: String
    let inputBindingFingerprint: String
    let primaryPolicyVersion: String
    let journey: PreparedRouteJourney
    let archiveImport: Bool
    let runtimeActivation: Bool
    let fullRuntimeQualification: Bool
    let longHorizonQualification: Bool
    let capacityOrOutputQualification: Bool
    let recoveryProvenance: [String: String]?
  }

  @Test("Assemble the explicitly declared interrupted study through canonical qualification")
  func assembleInterruptedStudy() throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["AUTOTECHNO_ASSEMBLE_INTERRUPTED_LONG_STUDY"] == "1" else { return }
    #if DEBUG
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    #endif
    guard let path = environment["AUTOTECHNO_INTERRUPTED_LONG_ASSEMBLY_REQUEST"],
      environment["AUTOTECHNO_RUN_INTERRUPTED_LONG_ROUTE"] != "1",
      environment["AUTOTECHNO_RUN_LONG_HORIZON_CALIBRATION"] != "1"
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let requestData = try Self.boundedRecoveryInput(path, maximumBytes: 65_536)
    let request = try JSONDecoder().decode(InterruptedAssembly.self, from: requestData)
    try request.provenance.validate()
    guard request.schema == "autotechno-interrupted-long-study-assembly-request.v1",
      request.routes.count == 18 else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let primary = try loadPrimary()
    guard primary.evaluator.policyVersion == request.provenance.primaryPolicyVersion else {
      throw LongHorizonProfessionalPolicyError.profileMismatch
    }
    var seen: Set<String> = [], inputs: [(URL, Data)] = [], observations: [UInt64: [LongHorizonRuntimePolicyObservation]] = [:]
    var totalBytes = 0, originals = 0, fresh = 0
    for row in request.routes {
      guard (developmentRoots + holdoutRoots).contains(row.rootSeed),
        [44_100, 48_000].contains(row.sampleRate),
        seen.insert("\(row.rootSeed)/\(row.sampleRate)").inserted else {
        throw LongHorizonProfessionalPolicyError.invalidEvidence
      }
      let url = URL(fileURLWithPath: row.path)
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      guard attributes[.type] as? FileAttributeType == .typeRegular,
        let size = attributes[.size] as? NSNumber, size.intValue > 0,
        size.intValue <= 64 * 1024 * 1024 - totalBytes else {
        throw LongHorizonProfessionalPolicyError.invalidEvidence
      }
      let data = try Data(contentsOf: url); totalBytes += data.count
      let recorded = try JSONDecoder().decode(RecordedJourney.self, from: data)
      let journey = recorded.journey
      guard recorded.schema == "autotechno-long-horizon-shared-journey.v2",
        recorded.primaryPolicyVersion == primary.evaluator.policyVersion,
        !recorded.archiveImport, !recorded.runtimeActivation, !recorded.fullRuntimeQualification,
        !recorded.longHorizonQualification, !recorded.capacityOrOutputQualification,
        journey.rootSeed == row.rootSeed, journey.sampleRate == Double(row.sampleRate),
        journey.completedRequestedScope, journey.endsAtClosedLeaf, journey.failureCode == nil,
        journey.requestedPrefixPhraseCount == nil, journey.requestedMinimumBars == 7_800 else {
        throw LongHorizonProfessionalPolicyError.invalidEvidence
      }
      let missing = row.rootSeed == 141_421 && row.sampleRate == 48_000 ||
        [173_205, 246_813, 271_828, 314_159].contains(row.rootSeed)
      if missing {
        fresh += 1
        let p = request.provenance
        guard row.origin == "fresh-recovery-execution",
          recorded.inputBindingFingerprint == p.recoveryInputBinding,
          recorded.recoveryProvenance == [
            "schema": "autotechno-interrupted-long-route-provenance.v1",
            "originalSource": p.originalSource, "originalInputBinding": p.originalInputBinding,
            "harnessSource": p.harnessSource, "manifestSHA256": p.manifestSHA256,
            "buildMetadataSHA256": p.buildMetadataSHA256,
            "routeOrigin": "fresh-complete-execution-from-initial-state"] else {
          throw LongHorizonProfessionalPolicyError.invalidEvidence
        }
      } else {
        originals += 1
        guard row.origin == "preserved-original", recorded.recoveryProvenance == nil,
          recorded.inputBindingFingerprint == request.provenance.originalInputBinding else {
          throw LongHorizonProfessionalPolicyError.invalidEvidence
        }
      }
      inputs.append((url, data))
      observations[row.rootSeed, default: []].append(try LongHorizonRuntimePolicyObservation(
        semanticReport: journey.semantic, signalReport: journey.signal,
        effectReport: journey.effects, primaryPolicyVersion: primary.evaluator.policyVersion))
    }
    guard originals == 9, fresh == 9 else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    func corpus(_ roots: [UInt64]) throws -> LongHorizonPolicyCalibrationCorpus {
      try LongHorizonPolicyCalibrationCorpus(observations: roots.map { root in
        let routes = (observations[root] ?? []).sorted { $0.sampleRate < $1.sampleRate }
        return try LongHorizonPolicyObservation(routeObservations: routes)
      })
    }
    try prepareOutputNamespace()
    let development = try corpus(developmentRoots), holdout = try corpus(holdoutRoots)
    try writeCorpora(development: development, holdout: holdout)
    try qualifyAndWriteArtifacts(development: development, holdoutCorpus: holdout) {
      guard try Self.boundedRecoveryInput(path, maximumBytes: 65_536) == requestData else { return false }
      return try inputs.allSatisfy { try Data(contentsOf: $0.0) == $0.1 }
    }
    let declaration: [String: Any] = ["schema": "autotechno-interrupted-long-study-assembly.v1",
      "originalSource": request.provenance.originalSource,
      "originalInputBinding": request.provenance.originalInputBinding,
      "harnessSource": request.provenance.harnessSource,
      "recoveryInputBinding": request.provenance.recoveryInputBinding,
      "manifestSHA256": request.provenance.manifestSHA256,
      "buildMetadataSHA256": request.provenance.buildMetadataSHA256,
      "preservedOriginalHistories": originals, "freshCompleteHistories": fresh,
      "declaredOriginalEvidenceAssembly": true, "originalHistoriesRetagged": false,
      "finalSourceApplicability": false, "runtimeQualification": false, "item39Complete": false]
    try JSONSerialization.data(withJSONObject: declaration, options: [.sortedKeys])
      .write(to: outputDirectory().appendingPathComponent("interrupted-study-assembly.json"), options: .withoutOverwriting)
  }

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
    try qualifyAndWriteArtifacts(development: development, holdoutCorpus: holdoutCorpus) {
      try executionBinding() == binding
    }
  }

  /// One canonical fit/qualification path for both an uninterrupted producer
  /// and the explicitly declared assembly of this interrupted study.
  private func qualifyAndWriteArtifacts(development: LongHorizonPolicyCalibrationCorpus,
    holdoutCorpus: LongHorizonPolicyCalibrationCorpus, validateInputs: () throws -> Bool
  ) throws {
    let profile = try LongHorizonProfessionalProfile(corpus: development)
    let profileEvaluator = try LongHorizonProfessionalProfileEvaluator(
      profile: profile)
    for observation in development.observations {
      let verdict = profileEvaluator.evaluate(observation)
      Self.progress(
        "development root=\(observation.rootSeed) accepted=\(verdict.accepted) "
          + "failures=\(verdict.failedDimensions.map(\.rawValue).joined(separator: ","))")
      for route in verdict.routeVerdicts {
        Self.progress("development-native root=\(observation.rootSeed) rate=\(Int(route.sampleRate)) accepted=\(route.verdict.accepted) source=\(route.sourceFingerprint)")
      }
      #expect(verdict.allNativeRoutesAccepted)
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
      for route in journey.verdict.routeVerdicts {
        Self.progress("holdout-native root=\(journey.rootSeed) rate=\(Int(route.sampleRate)) accepted=\(route.verdict.accepted) source=\(route.sourceFingerprint) failures=\(route.verdict.failedDimensions.map(\.rawValue).joined(separator: ","))")
      }
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
    let policy = try Self.qualifiedPolicy(
      profile: profile,
      adversarial: adversarial,
      holdout: holdout)

    #expect(adversarial.passed)
    #expect(holdout.qualified)
    #expect(holdout.journeys.allSatisfy { $0.verdict.accepted })
    #expect(!policy.policyVersion.isEmpty)
    guard adversarial.passed, holdout.qualified, try validateInputs()
    else { throw LongHorizonProfessionalPolicyError.insufficientEvidence }
    try writeArtifacts(
      profile: profile, adversarial: adversarial, holdout: holdout)
    Self.progress("profile=\(profile.fingerprint)")
    Self.progress("adversarial=\(adversarial.fingerprint)")
    Self.progress("holdout=\(holdout.fingerprint)")
  }

  /// Keep qualification failure distinct from mismatched artifact identity.
  /// The policy constructor and every original positive gate still apply.
  private static func qualifiedPolicy(
    profile: LongHorizonProfessionalProfile,
    adversarial: LongHorizonAdversarialSuiteReport,
    holdout: LongHorizonHoldoutQualification
  ) throws -> LongHorizonProfessionalPolicy {
    guard adversarial.passed else {
      throw LongHorizonProfessionalPolicyError.adversarialFailure
    }
    guard holdout.qualified else {
      throw LongHorizonProfessionalPolicyError.holdoutFailure
    }
    return try LongHorizonProfessionalPolicy(
      profile: profile, adversarial: adversarial, holdout: holdout)
  }

  @Test("A rejected native-rate holdout remains a holdout failure before policy construction")
  func rejectedNativeHoldoutKeepsItsCause() throws {
    let artifacts = try qualifiedArtifacts()
    let bound = try #require(artifacts.profile.semanticBound(.maximumCapabilityRunBars))
    for badRate in [44_100.0, 48_000.0] {
      let original = artifacts.holdoutCorpus.observations[0]
      let routes = original.routes.map { source in
        LongHorizonRuntimePolicyObservation(
          engineVersion: source.engineVersion,
          primaryPolicyVersion: source.primaryPolicyVersion,
          rootSeed: source.rootSeed,
          semanticFingerprint: source.semanticFingerprint,
          observedPhraseCount: source.observedPhraseCount,
          observedBarCount: source.observedBarCount,
          semanticValues: source.semanticValues.map { value in
            source.sampleRate == badRate && value.metric == .maximumCapabilityRunBars
              ? LongHorizonPolicyNamedValue(metric: value.metric, value: bound.upper + 1)
              : value
          },
          sampleRate: source.sampleRate,
          signalFingerprint: source.signalFingerprint,
          signalObservationCount: source.signalObservationCount,
          signalOmittedPhraseCount: source.signalOmittedPhraseCount,
          operatorDeltas: source.operatorDeltas,
          effects: source.effects)
      }
      let damaged = try LongHorizonPolicyObservation(routeObservations: routes)
      let corpus = try LongHorizonPolicyCalibrationCorpus(observations: [
        damaged, artifacts.holdoutCorpus.observations[1],
      ])
      let holdout = try LongHorizonHoldoutQualification(
        profile: artifacts.profile, adversarial: artifacts.adversarial,
        developmentCorpus: artifacts.development, holdoutCorpus: corpus)
      #expect(!holdout.qualified)
      let verdict = try #require(holdout.journeys.first {
        $0.rootSeed == original.rootSeed
      }).verdict
      #expect(verdict.failedDimensions == [.capabilityFatigue])
      #expect(verdict.failedSemanticMetrics == [.maximumCapabilityRunBars])
      #expect(verdict.routeVerdicts.first { $0.sampleRate == badRate }?.verdict.accepted == false)
      #expect(verdict.routeVerdicts.first { $0.sampleRate != badRate }?.verdict.accepted == true)
      #expect(throws: LongHorizonProfessionalPolicyError.holdoutFailure) {
        try Self.qualifiedPolicy(profile: artifacts.profile,
          adversarial: artifacts.adversarial, holdout: holdout)
      }
    }
    // A complete positive chain remains admitted by the same constructor.
    let policy = try Self.qualifiedPolicy(profile: artifacts.profile,
      adversarial: artifacts.adversarial, holdout: artifacts.holdout)
    #expect(policy.profile.fingerprint == artifacts.profile.fingerprint)
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
        "long-horizon-development-corpus-local-v8.json"))
    try holdout.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "long-horizon-holdout-corpus-local-v8.json"))
  }

  private func outputDirectory() throws -> URL {
    guard
      let outputDirectory = ProcessInfo.processInfo.environment[
        "AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY"
      ], !outputDirectory.isEmpty
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let directory = try Self.confinedEvidenceDirectory(
      URL(fileURLWithPath: outputDirectory, isDirectory: true), repositoryRoot: repositoryRoot)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Foundation standardizes an existing /private/tmp path to /tmp, but leaves
  /// a missing leaf unchanged. Resolve the existing ancestor first, then append
  /// missing components so the confinement decision survives directory creation.
  private static func canonicalEvidenceURL(_ url: URL) throws -> URL {
    var ancestor = url.standardizedFileURL
    var missing: [String] = []
    while !FileManager.default.fileExists(atPath: ancestor.path) {
      let attributes = try? FileManager.default.attributesOfItem(atPath: ancestor.path)
      guard attributes?[.type] as? FileAttributeType != .typeSymbolicLink else {
        throw LongHorizonProfessionalPolicyError.invalidEvidence
      }
      let parent = ancestor.deletingLastPathComponent()
      guard parent.path != ancestor.path else {
        throw LongHorizonProfessionalPolicyError.invalidEvidence
      }
      missing.append(ancestor.lastPathComponent); ancestor = parent
    }
    return missing.reversed().reduce(ancestor.resolvingSymlinksInPath().standardizedFileURL) {
      $0.appendingPathComponent($1, isDirectory: true)
    }
  }

  private static func confinedEvidenceDirectory(_ directory: URL, repositoryRoot: URL) throws -> URL {
    let reports = try canonicalEvidenceURL(repositoryRoot.appendingPathComponent("docs/local/reports"))
    let candidate = try canonicalEvidenceURL(directory)
    guard candidate.path.hasPrefix(reports.path + "/") else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
    return candidate
  }

  @Test("Evidence directory confinement is stable before and after creation and refuses escapes")
  func evidenceDirectoryConfinement() throws {
    let manager = FileManager.default
    let temporary = manager.temporaryDirectory.appendingPathComponent("at0039-evidence-" + UUID().uuidString)
    let repository = temporary.appendingPathComponent("repository")
    let reports = repository.appendingPathComponent("docs/local/reports")
    try manager.createDirectory(at: reports, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: temporary) }
    let alias = temporary.appendingPathComponent("alias")
    try manager.createSymbolicLink(at: alias, withDestinationURL: repository)
    let requested = alias.appendingPathComponent("docs/local/reports/fresh/nested")
    let before = try Self.confinedEvidenceDirectory(requested, repositoryRoot: repository)
    try manager.createDirectory(at: before, withIntermediateDirectories: true)
    let after = try Self.confinedEvidenceDirectory(requested, repositoryRoot: repository)
    #expect(before.path == after.path)
    let marker = Data("derived-evidence".utf8)
    try marker.write(to: after.appendingPathComponent("receipt.json"))
    #expect(try Data(contentsOf: before.appendingPathComponent("receipt.json")) == marker)
    for escape in [repository, reports, repository.appendingPathComponent("docs/local/reports-extra/leaf"),
      reports.appendingPathComponent("../outside")] {
      #expect(throws: LongHorizonProfessionalPolicyError.invalidEvidence) {
        try Self.confinedEvidenceDirectory(escape, repositoryRoot: repository)
      }
    }
    let outside = temporary.appendingPathComponent("outside")
    try manager.createDirectory(at: outside, withIntermediateDirectories: true)
    let link = reports.appendingPathComponent("escape")
    try manager.createSymbolicLink(at: link, withDestinationURL: outside)
    #expect(throws: LongHorizonProfessionalPolicyError.invalidEvidence) {
      try Self.confinedEvidenceDirectory(link.appendingPathComponent("fresh"), repositoryRoot: repository)
    }
    let dangling = reports.appendingPathComponent("dangling")
    try manager.createSymbolicLink(at: dangling, withDestinationURL: temporary.appendingPathComponent("absent"))
    #expect(throws: LongHorizonProfessionalPolicyError.invalidEvidence) {
      try Self.confinedEvidenceDirectory(dangling.appendingPathComponent("fresh"), repositoryRoot: repository)
    }
    #if os(macOS)
      // Reproduce Foundation's special /private/tmp normalization, independently
      // of the general repository-symlink case above.
      let macRoot = URL(fileURLWithPath: "/private/tmp/at0039-path-" + UUID().uuidString)
      let macReports = macRoot.appendingPathComponent("docs/local/reports")
      try manager.createDirectory(at: macReports, withIntermediateDirectories: true)
      defer { try? manager.removeItem(at: macRoot) }
      let macRequested = macReports.appendingPathComponent("fresh")
      let macBefore = try Self.confinedEvidenceDirectory(macRequested, repositoryRoot: macRoot)
      try manager.createDirectory(at: macBefore, withIntermediateDirectories: true)
      #expect(try Self.confinedEvidenceDirectory(macRequested, repositoryRoot: macRoot).path == macBefore.path)
    #endif
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
      "long-horizon-observation-local-\(rootSeed)-v8.json")
    try observation.deterministicJSON().write(to: url)
    Self.progress(
      "diagnostic root=\(rootSeed) source=\(observation.sourceFingerprint) "
        + "semantic=\(observation.routes.map(\.semanticFingerprint).joined(separator: ",")) "
        + "signals=\(observation.routes.map(\.signalFingerprint).joined(separator: ","))")
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
    let rejectedSuccessorPhraseIndex: Int?
    let rejectedSuccessorRequestFingerprint: String?
    let acceptedTraversalFingerprintBeforeRejection: String?
    let rejectedSuccessorDetails: [String]?
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
        var source: PreparedPerformancePhrase?
        var rejectedSuccessor: SuccessorCandidateRejection?
        var rejectedSuccessorDetails: [String]?
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
            case .failed(let refused):
              guard let rejection = refused.recoveryRejection(for: request) else { throw refused }
              rejectedSuccessor = rejection
              rejectedSuccessorDetails = Array(refused.details.prefix(24))
            }
          }
        } catch let refused as PhrasePreparationFailure {
          failure = refused.stage + ":" + refused.code; details = Array(refused.details.prefix(24)); break
        } catch { failure = "continuation-refused"; break }
        do {
          if let source, try Self.writeNativeRouteDivergenceWitness(request: request, prepared: source.prepared) {
            failure = "diagnostic-recovery-boundary-captured"; break
          }
        } catch {
          failure = "native-route-divergence-witness-write-failed"; break
        }
        if let budget = source?.preparationChainResourceBudget {
          peak = max(peak, budget.reservedPeakWorkingByteCount)
        }
        if rejectedSuccessor != nil || source?.prepared.commitEligible == false {
          guard !consumedOwnedChild,
            source.map({ $0.request.replayIdentity.matches($0.request) &&
              $0.request.replayIdentity.fingerprint == request.replayIdentity.fingerprint }) ??
                (rejectedSuccessor?.rootRequestFingerprint == request.replayIdentity.fingerprint)
          else { failure = "rejected-source-replay-mismatch"; break }
          if firstRefusalTraversal == nil {
            firstRefusalTraversal = fixedWidthFingerprintHex(sink.value)
          }
          guard let decision = source?.prepared.qualityDecision ?? rejectedSuccessor?.decision,
            let candidate = source?.prepared.selectedCandidateEvidence.fingerprint ?? rejectedSuccessor?.candidateFingerprint
          else { failure = "rejection-decision-unavailable"; break }
          rejections.append(RecoveryRejection(targetPhraseIndex: state.phraseIndex,
            requestFingerprint: request.replayIdentity.fingerprint,
            incomingCoreFingerprint: request.replayIdentity.sourceStateFingerprint,
            candidateFingerprint: candidate,
            reasonCodes: decision.reasonCodes.map(\.rawValue),
            ordinal: request.key.qualityRetryOrdinal,
            wave: request.key.qualityRecoveryContext.wave,
            overdueDebtCount: source?.prepared.plan.interest.overdueDebtCount ?? rejectedSuccessor?.overdueDebtCount ?? 0,
            rejectedSuccessorPhraseIndex: rejectedSuccessor?.rejectedPhraseIndex,
            rejectedSuccessorRequestFingerprint: rejectedSuccessor?.rejectedRequestFingerprint,
            acceptedTraversalFingerprintBeforeRejection: rejectedSuccessor == nil ? nil : fixedWidthFingerprintHex(sink.value),
            rejectedSuccessorDetails: rejectedSuccessorDetails))
          guard decision.isRetryableCandidateRejection else {
            guard let source else { failure = "successor-recovery-decision-invalid"; break }
            failure = "prepared-source-quality:" + decision.outcome.rawValue
            details = Array((source.prepared.commitFailureDiagnostics +
              source.prepared.qualityDiagnosticDetails +
              decision.reasonCodes.map { "quality=" + $0.rawValue } +
              Self.candidateCompletenessDiagnostics(source.prepared.selectedCandidateEvidence) +
              Self.writeRefusedInstrumentCandidate(source.prepared.selectedCandidateEvidence,
                rootSeed: rootSeed, sampleRate: sampleRate, phraseIndex: state.phraseIndex) +
              Self.refusalRecoveryDiagnostics(request: source.request,
                rejected: source.prepared, director: director)).prefix(24))
            break
          }
          recoveryOrigin = recoveryOrigin ?? request.replayIdentity
          let nextRetry = retry.recordingCalibratedRejection(decision: decision,
            targetPhraseIndex: state.phraseIndex)
          guard nextRetry != retry else { failure = "recovery-context-stalled"; break }
          retry = nextRetry
          sink.string(rejectedSuccessor == nil ? "actual-core-rejection.v1" : "actual-successor-chain-rejection.v1")
          sink.string(request.replayIdentity.fingerprint)
          sink.string(candidate)
          if let rejectedSuccessor {
            sink.int(rejectedSuccessor.rejectedPhraseIndex)
            sink.string(rejectedSuccessor.rejectedRequestFingerprint)
          }
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
        guard let source else { failure = "prepared-source-unavailable"; break }
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
          if source.prepared.longHorizonSignalTrajectoryEvidence == nil {
            details += Self.writeRefusedSignalInputs(source.prepared,
              rootSeed: rootSeed, sampleRate: sampleRate)
          }
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

  /// Existing typed completeness predicates identify the measured deficit;
  /// diagnostics cannot make a refused candidate eligible for another retry.
  private static func candidateCompletenessDiagnostics(
    _ candidate: AutonomousCandidateEvaluationVector
  ) -> [String] {
    let failures = candidate.completenessFailures
    guard !failures.isEmpty else { return [] }
    return ["candidate-completeness-count=" + String(failures.count)] +
      failures.prefix(8).map { "candidate-completeness=" + $0.rawValue }
  }

  /// Keep the exact selected, refused vector local for a binding diagnosis.
  /// No PCM or continuation is imported, and the existing refusal is preserved.
  private static func writeRefusedInstrumentCandidate(
    _ candidate: AutonomousCandidateEvaluationVector,
    rootSeed: UInt64, sampleRate: Double, phraseIndex: Int
  ) -> [String] {
    guard candidate.completenessFailures.contains(.instrumentEvidence) else { return [] }
    guard let directory = ProcessInfo.processInfo.environment[
      "AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY"
    ] else { return ["refused-instrument-witness-output-unavailable"] }
    let url = URL(fileURLWithPath: directory, isDirectory: true)
      .appendingPathComponent("refused-candidate-\(rootSeed)-\(Int(sampleRate))-\(phraseIndex).json")
    do {
      try candidate.deterministicJSON().write(to: url, options: .withoutOverwriting)
      return []
    } catch { return ["refused-instrument-witness-write-failed"] }
  }

  /// Derived inputs to every signal-construction guard, retained only after
  /// the actual source refuses. This witness cannot restore continuation or
  /// supply accepted evidence; no PCM is copied and the refusal is unchanged.
  private struct RefusedSignalInputs: Encodable {
    let schema = "autotechno-refused-long-signal-inputs.v1"
    let rootSeed: UInt64
    let phraseIndex: Int
    let startBar: Int
    let barCount: Int
    let phraseKind: String
    let coordination: LongHorizonEnergyCoordination
    let planFingerprint: String
    let candidateEvaluationFingerprint: String
    let preflightSampleHash: String
    let commitEligible: Bool
    let playbackHardGatesPassed: Bool
    let candidate: AutonomousCandidateEvaluationVector
    let effects: LongHorizonEffectDosePhraseEvidence?
    let musical: [String: Double]
  }

  private static func writeRefusedSignalInputs(_ prepared: PreparedAutonomousPhrase,
    rootSeed: UInt64, sampleRate: Double
  ) -> [String] {
    guard let directory = ProcessInfo.processInfo.environment[
      "AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY"
    ] else { return ["refused-signal-witness-output-unavailable"] }
    let musical = prepared.audioPreflight.quality.musical
    let witness = RefusedSignalInputs(rootSeed: rootSeed,
      phraseIndex: prepared.plan.phraseIndex, startBar: prepared.plan.startBar,
      barCount: prepared.plan.barCount, phraseKind: String(describing: prepared.plan.kind),
      coordination: prepared.plan.longHorizonEnergyCoordination,
      planFingerprint: AutonomousTypedFingerprint.plan(prepared.plan),
      candidateEvaluationFingerprint: prepared.candidateEvaluationFingerprint,
      preflightSampleHash: prepared.audioPreflight.quality.sampleHash,
      commitEligible: prepared.commitEligible,
      playbackHardGatesPassed: prepared.playbackHardGatesPassed,
      candidate: prepared.selectedCandidateEvidence,
      effects: prepared.longHorizonEffectDoseEvidence,
      musical: [
        "spectralCentroid": musical.spectralCentroid,
        "spectralCentroidSpreadHz": musical.perceptualEvidence.spectralCentroidSpreadHz,
        "positiveSpectralFluxMean": musical.perceptualEvidence.positiveSpectralFluxMean,
        "lowEnergy": musical.lowEnergy, "midEnergy": musical.midEnergy,
        "highEnergy": musical.highEnergy,
      ])
    let url = URL(fileURLWithPath: directory, isDirectory: true)
      .appendingPathComponent("refused-signal-\(rootSeed)-\(Int(sampleRate))-\(prepared.plan.phraseIndex).json")
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      encoder.nonConformingFloatEncodingStrategy = .convertToString(
        positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
      try encoder.encode(witness).write(to: url, options: .withoutOverwriting)
      return ["refused-signal-witness-written"]
    } catch { return ["refused-signal-witness-write-failed"] }
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

  private func writeJourney(_ journey: PreparedRouteJourney, binding: String,
    recovery: [String: String]? = nil
  ) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var object: [String: Any] = ["schema": "autotechno-long-horizon-shared-journey.v3",
      "inputBindingFingerprint": binding, "primaryPolicyVersion": LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion,
      "journey": try JSONSerialization.jsonObject(with: encoder.encode(journey)),
      "sourceScope": "current-shared-preparation-primary-only-bootstrap-with-core-recovery",
      "presentationScope": "offline-selected-retained-pcm-no-device-scheduling-proof",
      "memoryScope": "numeric-reservation-covers-preparation-chain-not-combined-held-playback",
      "archiveImport": false, "runtimeActivation": false, "fullRuntimeQualification": false,
      "longHorizonQualification": false, "capacityOrOutputQualification": false]
    if let recovery { object["recoveryProvenance"] = recovery }
    let directory = try outputDirectory()
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
      .write(to: directory.appendingPathComponent("actual-journey-\(journey.rootSeed)-\(Int(journey.sampleRate)).json"), options: .atomic)
  }

  /// Opt-in diagnostic at the first differing recorded rejection in the frozen
  /// Long20 pair. It observes the unmodified prepared decision before recovery;
  /// it cannot import a journey, admit a candidate, or produce calibration.
  private static func writeNativeRouteDivergenceWitness(
    request: PhrasePreparationRequest, prepared: PreparedAutonomousPhrase
  ) throws -> Bool {
    let environment = ProcessInfo.processInfo.environment
    guard environment["AUTOTECHNO_RUN_LONG_HORIZON_SHARED_PROBE"] == "1",
      environment["AUTOTECHNO_RUN_LONG_HORIZON_CALIBRATION"] != "1"
    else { return false }
    let recovery = environment["AUTOTECHNO_LONG_HORIZON_RECOVERY_BOUND_PROBE"] == "1"
    let interrupted = environment["AUTOTECHNO_LONG_HORIZON_INTERRUPTED_REFUSAL_PROBE"] == "1"
    let root: UInt64 = interrupted ? 173_205 : (recovery ? 141_421 : 112_358)
    let target = interrupted ? 15 : (recovery ? 13 : 279)
    if recovery, request.sourceState.rootSeed == root,
      environment["AUTOTECHNO_LONG_HORIZON_SPECTRAL_SUPPORT_PROBE"] == "1",
      prepared.plan.kind == .contrast {
      try writeSpectralWindowSupport(request: request, prepared: prepared)
    }
    guard interrupted || recovery || environment["AUTOTECHNO_LONG_HORIZON_DIVERGENCE_PROBE"] == "1",
      request.sourceState.rootSeed == root, request.key.phraseIndex == target
    else { return false }
    guard let directory = environment["AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY"]
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let decision = prepared.qualityDecision
    let candidate = try JSONSerialization.jsonObject(
      with: prepared.selectedCandidateEvidence.deterministicJSON())
    let witness: [String: Any] = [
      "schema": "autotechno-native-route-divergence-witness.v2",
      "rootSeed": request.sourceState.rootSeed,
      "sampleRate": request.key.sampleRate,
      "phraseIndex": request.key.phraseIndex,
      "retryOrdinal": request.key.qualityRetryOrdinal,
      "retryWave": request.key.qualityRecoveryContext.wave,
      "presentedRepeatBars": request.key.qualityRecoveryContext.presentedRepeatBars,
      "incomingRecoveryIntent": try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(request.key.qualityRecoveryContext.intent)),
      "proposedRecoveryIntent": try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(decision.recoveryIntent)),
      "sourceCoreFingerprint": request.replayIdentity.sourceStateFingerprint,
      "requestFingerprint": request.replayIdentity.fingerprint,
      "planFingerprint": AutonomousCandidateFingerprint.plan(prepared.plan),
      "candidateFingerprint": prepared.selectedCandidateEvidence.fingerprint,
      "energyCoordination": try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(prepared.plan.longHorizonEnergyCoordination)),
      "resolvedRoleBars": prepared.plan.resolvedBars.map { bar in
        ["bar": bar.performance.bar,
         "roles": bar.performance.roles.map(\.rawValue),
         "activeSupportingRoles": bar.narrative.activeSupportingRoles.map(\.rawValue),
         "arrangementGesture": bar.arrangementGesture.rawValue] as [String: Any]
      },
      "sampleHash": prepared.audioPreflight.quality.sampleHash,
      "commitEligible": prepared.commitEligible,
      "decision": decision.outcome.rawValue,
      "reasonCodes": decision.reasonCodes.map(\.rawValue),
      "qualityDiagnostics": prepared.qualityDiagnosticDetails,
      "commitDiagnostics": prepared.commitFailureDiagnostics,
      "candidate": candidate,
      "calibrationEvidence": false,
    ]
    let filename = "native-divergence-\(root)-\(Int(request.key.sampleRate))-\(target)-"
      + "\(request.key.qualityRecoveryContext.wave)-\(request.key.qualityRetryOrdinal).json"
    let data = try JSONSerialization.data(withJSONObject: witness, options: [.sortedKeys])
    try data.write(to: URL(fileURLWithPath: directory, isDirectory: true)
      .appendingPathComponent(filename), options: .withoutOverwriting)
    // One optional actual recovery wave exposes the measured effect of the
    // canonical retry intent. Acceptance or the next wave stops the diagnostic;
    // no full study budget, admission rule or production path is changed.
    return (interrupted || recovery) && (prepared.commitEligible ||
      environment["AUTOTECHNO_LONG_HORIZON_RECOVERY_WAVE_PROBE"] != "1" ||
      request.key.qualityRecoveryContext.wave >= 1)
  }

  /// Offline diagnostic only. Rewindow the exact immutable stereo samples so
  /// centroid extrema retain their measured level and position. No threshold,
  /// rendered sample, decision or calibration observation is changed.
  private static func writeSpectralWindowSupport(
    request: PhrasePreparationRequest, prepared: PreparedAutonomousPhrase
  ) throws {
    let rate = request.key.sampleRate
    let left = prepared.blocks.flatMap(\.left), right = prepared.blocks.flatMap(\.right)
    let full = try #require(StreamingPerceptualEvidenceAnalyzer.analyze(
      left: left, right: right, sampleRate: rate))
    let size = full.analysisFrameCount, hop = full.hopFrameCount
    var rows: [(start: Int, centroid: Double, rms: Double)] = []
    if left.count >= size {
      for start in stride(from: 0, through: left.count - size, by: hop) {
        let l = Array(left[start..<start + size]), r = Array(right[start..<start + size])
        let window = try #require(StreamingPerceptualEvidenceAnalyzer.analyze(
          left: l, right: r, sampleRate: rate))
        guard window.activeWindowCount == 1 else { continue }
        let squareSum = zip(l, r).reduce(0.0) { total, pair in
          let mono = (Double(pair.0) + Double(pair.1)) * 0.5
          return total + mono * mono
        }
        rows.append((start, window.spectralCentroidMeanHz, sqrt(squareSum / Double(size))))
      }
    }
    #expect(rows.count == full.activeWindowCount)
    let ordered = rows.sorted { $0.centroid < $1.centroid }
    let span = (ordered.last?.centroid ?? 0) - (ordered.first?.centroid ?? 0)
    #expect(abs(span - full.spectralCentroidSpreadHz) < 0.000_001)
    #expect(abs(full.spectralCentroidSpreadHz -
      prepared.selectedCandidateEvidence.fullMix.perceptual.spectralCentroidSpreadHz) < 0.000_001)
    func reduced(_ row: (start: Int, centroid: Double, rms: Double)) -> [String: Any] {
      ["startFrame": row.start, "centroidHz": row.centroid, "rms": row.rms,
       "rmsDBFS": row.rms > 0 ? 20 * log10(row.rms) : -Double.greatestFiniteMagnitude]
    }
    let witness: [String: Any] = [
      "schema": "autotechno-spectral-window-support-diagnostic.v1",
      "rootSeed": request.sourceState.rootSeed, "sampleRate": rate,
      "phraseIndex": request.key.phraseIndex, "retryWave": request.key.qualityRecoveryContext.wave,
      "retryOrdinal": request.key.qualityRetryOrdinal, "commitEligible": prepared.commitEligible,
      "requestFingerprint": request.replayIdentity.fingerprint,
      "sampleHash": prepared.audioPreflight.quality.sampleHash,
      "analysisFrameCount": size, "hopFrameCount": hop, "activeWindowCount": rows.count,
      "centroidSpreadHz": span, "lowestCentroidWindows": ordered.prefix(4).map(reduced),
      "highestCentroidWindows": ordered.suffix(4).map(reduced),
      "highestEnergyWindows": rows.sorted { $0.rms > $1.rms }.prefix(4).map(reduced),
      "qualityDiagnostics": prepared.qualityDiagnosticDetails, "calibrationEvidence": false,
      "resourceQualification": false,
    ]
    let directory = try #require(ProcessInfo.processInfo.environment["AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY"])
    let name = "spectral-support-\(request.sourceState.rootSeed)-\(Int(rate))-\(request.key.phraseIndex)-"
      + "\(request.key.qualityRecoveryContext.wave)-\(request.key.qualityRetryOrdinal).json"
    try JSONSerialization.data(withJSONObject: witness, options: [.sortedKeys])
      .write(to: URL(fileURLWithPath: directory).appendingPathComponent(name), options: .withoutOverwriting)
  }

  @Test("Reproduce the original native rejected-child prefix and recover through the shared owner",
    .enabled(if: ProcessInfo.processInfo.environment["AUTOTECHNO_RUN_LONG_HORIZON_SUCCESSOR_RECOVERY_PROBE"] == "1"))
  func probeRejectedSuccessorRecovery() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard ["AUTOTECHNO_RUN_LONG_HORIZON_CALIBRATION", "AUTOTECHNO_RUN_LONG_HORIZON_SHARED_PROBE",
      "AUTOTECHNO_RUN_INTERRUPTED_LONG_ROUTE", "AUTOTECHNO_ASSEMBLE_INTERRUPTED_LONG_STUDY"]
      .allSatisfy({ environment[$0] != "1" })
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let primary = try loadPrimary(), binding = try executionBinding()
    try prepareOutputNamespace()
    // This failed, incomplete original route is rebuilt from initial state.
    // No archived score, PCM, controller or partial continuation is imported.
    let journey = await Task.detached(priority: .userInitiated) {
      await Self.renderPreparedRoute(rootSeed: 173_205, sampleRate: 44_100,
        primary: primary, prefixPhraseCount: 405)
    }.value
    try writeJourney(journey, binding: binding)
    #expect(journey.completedRequestedScope && journey.failureCode == nil)
    #expect(journey.requestedPrefixPhraseCount == 405 && journey.consumedPhraseCount >= 405)
    #expect(journey.endsAtClosedLeaf)
    let rejection = try #require(journey.rejectedPreparations.first {
      $0.rejectedSuccessorPhraseIndex != nil
    })
    #expect(rejection.targetPhraseIndex == 402 && rejection.rejectedSuccessorPhraseIndex == 403)
    #expect(rejection.acceptedTraversalFingerprintBeforeRejection == "fd55b882a65750ee")
    #expect(rejection.rejectedSuccessorDetails?.contains {
      $0.contains("kick-grounded-bar-ratio=0.8125")
    } == true)
    #expect(journey.signal.observationCount == journey.consumedPhraseCount)
    #expect(journey.effects.phraseCount == journey.consumedPhraseCount)
    #expect(try executionBinding() == binding)
  }

  @Test("Probe the actual native bootstrap through the same full-journey owner",
    .enabled(if: ProcessInfo.processInfo.environment["AUTOTECHNO_RUN_LONG_HORIZON_SHARED_PROBE"] == "1"))
  func probeSharedPreparedBootstrap() async throws {
    let environment = ProcessInfo.processInfo.environment
    let divergence = environment["AUTOTECHNO_LONG_HORIZON_DIVERGENCE_PROBE"] == "1"
    let recovery = environment["AUTOTECHNO_LONG_HORIZON_RECOVERY_BOUND_PROBE"] == "1"
    let interrupted = environment["AUTOTECHNO_LONG_HORIZON_INTERRUPTED_REFUSAL_PROBE"] == "1"
    guard [divergence, recovery, interrupted].filter({ $0 }).count <= 1,
      environment["AUTOTECHNO_RUN_LONG_HORIZON_CALIBRATION"] != "1",
      environment["AUTOTECHNO_RUN_INTERRUPTED_LONG_ROUTE"] != "1",
      environment["AUTOTECHNO_ASSEMBLE_INTERRUPTED_LONG_STUDY"] != "1",
      !interrupted || environment["AUTOTECHNO_LONG_HORIZON_SPECTRAL_SUPPORT_PROBE"] != "1"
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let primary = try loadPrimary(), binding = try executionBinding()
    let root: UInt64 = interrupted ? 173_205 : (recovery ? 141_421 : (divergence ? 112_358 : 48_291))
    let prefix = interrupted ? 16 : (recovery ? 14 : (divergence ? 280 : 4))
    try prepareOutputNamespace()
    for rate in interrupted ? [44_100.0] : [44_100.0, 48_000.0] {
      let journey = await Task.detached(priority: .userInitiated) {
        await Self.renderPreparedRoute(rootSeed: root, sampleRate: rate, primary: primary, prefixPhraseCount: prefix)
      }.value
      try writeJourney(journey, binding: binding)
      let acceptedPrefix = interrupted ? 15 : (recovery ? 13 : prefix)
      if interrupted || recovery {
        #expect(!journey.completedRequestedScope)
        #expect(journey.failureCode == "diagnostic-recovery-boundary-captured")
        let target = interrupted ? 15 : 13
        let witness = try outputDirectory().appendingPathComponent(
          "native-divergence-\(root)-\(Int(rate))-\(target)-0-0.json")
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: witness)) as? [String: Any])
        #expect(object["calibrationEvidence"] as? Bool == false)
        if interrupted {
          // Independently reproduce the failed recovery's first refusal from
          // initial state. The incomplete witness has no study authority.
          #expect(object["requestFingerprint"] as? String == "57d0368468c1a30e")
          #expect(object["sourceCoreFingerprint"] as? String == "ad11c409230c8c4d")
          #expect(object["commitEligible"] as? Bool == false)
          #expect(journey.ownedChildConsumptionCount == 1)
          if environment["AUTOTECHNO_LONG_HORIZON_RECOVERY_WAVE_PROBE"] == "1" {
            #expect((15...25).contains(journey.newPreparationAttemptCount))
            #expect(journey.accountedRepeats.count <= 2)
          } else {
            #expect(journey.newPreparationAttemptCount == 15)
            #expect(journey.accountedRepeats.isEmpty)
          }
          #expect(object["candidateFingerprint"] as? String == "527d5bc3b2a984ad")
        } else if rate == 44_100 {
          // Bind this fresh diagnostic to the first rejection in the failed
          // immutable study; no archived state or candidate is imported.
          #expect(object["requestFingerprint"] as? String == "f007bcabd52c857c")
          #expect(object["sourceCoreFingerprint"] as? String == "bd1943e4e28778e0")
          #expect(object["commitEligible"] as? Bool == false)
        }
      } else {
        #expect(journey.completedRequestedScope && journey.failureCode == nil)
      }
      #expect(journey.consumedPhraseCount == acceptedPrefix)
      #expect(journey.signal.observationCount == acceptedPrefix && journey.signal.omittedPhraseCount == 0)
      #expect(journey.effects.phraseCount == acceptedPrefix && journey.effects.barCount == journey.semantic.observedBarCount)
      if divergence {
        let witness = try outputDirectory().appendingPathComponent(
          "native-divergence-112358-\(Int(rate))-279-0-0.json")
        #expect(FileManager.default.fileExists(atPath: witness.path))
      }
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
