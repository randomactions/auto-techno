import AutoTechnoCore
import Foundation

/// Canonical FNV/bit-pattern rendering without Foundation's variadic formatter.
/// Keeping this out of line prevents deep validation on a cooperative-task
/// stack from inheriting the formatter's comparatively large stack frame.
@inline(never)
func fixedWidthFingerprintHex(_ value: UInt64) -> String {
    var remaining = value
    var bytes = [UInt8](repeating: 48, count: 16)
    for index in stride(from: 15, through: 0, by: -1) {
        let nibble = UInt8(remaining & 0x0f)
        bytes[index] = nibble < 10 ? 48 + nibble : 87 + nibble
        remaining >>= 4
    }
    return String(decoding: bytes, as: UTF8.self)
}

/// Bit-exact, streaming fingerprints for the canonical candidate inputs and
/// continuation owners. Every stored value is encoded through a typed path;
/// no reflection, textual object descriptions, or whole-state byte buffers
/// participate in the digest.
package enum AutonomousTypedFingerprint {
    package static func sessionState(
        _ state: AutonomousSessionState
    ) -> String {
        digest(domain: "session-state.typed.v1") { sink in
            encode(state, into: &sink)
        }
    }

    package static func plan(_ plan: AutonomousPhrasePlan) -> String {
        digest(domain: "candidate-plan.typed.v21") { sink in
            encode(plan, into: &sink)
        }
    }

    package static func graph(_ graph: DSPGraphPlan) -> String {
        digest(domain: "generated-graph.typed.v1") { sink in
            encode(graph, into: &sink)
        }
    }

    package static func renderState(_ state: RenderState) -> String {
        digest(domain: "render-state.typed.v4") { sink in
            encode(state, into: &sink)
        }
    }

    package static func renderState(
        _ state: RenderState,
        cancellationRequested: @Sendable () -> Bool
    ) -> String? {
        cancellableDigest(
            domain: "render-state.typed.v4",
            cancellationRequested: cancellationRequested
        ) { sink in
            encode(
                state,
                into: &sink,
                cancellationRequested: cancellationRequested
            )
        }
    }

    package static func generatedDSPState(
        _ state: GeneratedDSPContinuationState
    ) -> String {
        digest(domain: "generated-dsp-state.typed.v1") { sink in
            encode(state, into: &sink)
        }
    }

    package static func generatedDSPState(
        _ state: GeneratedDSPContinuationState,
        cancellationRequested: @Sendable () -> Bool
    ) -> String? {
        cancellableDigest(
            domain: "generated-dsp-state.typed.v1",
            cancellationRequested: cancellationRequested
        ) { sink in
            encode(
                state,
                into: &sink,
                cancellationRequested: cancellationRequested
            )
        }
    }

    package static func qualityState(_ state: QualityContinuationState) -> String {
        digest(domain: "quality-state.typed.v1") { sink in
            encode(state, into: &sink)
        }
    }

    package static func route(
        sampleRate: Double,
        channelCount: Int,
        generation: Int
    ) -> String {
        digest(domain: "route-state.typed.v1") { sink in
            sink.field("sampleRate"); sink.double(sampleRate)
            sink.field("channelCount"); sink.int(channelCount)
            sink.field("generation"); sink.int(generation)
        }
    }

    package static func liveOutputPCM<Left, Right>(
        left: Left,
        right: Right,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> String? where
        Left: RandomAccessCollection,
        Right: RandomAccessCollection,
        Left.Element == Float,
        Right.Element == Float,
        Left.Index == Int,
        Right.Index == Int {
        guard left.count == right.count else { return nil }
        return cancellableDigest(
            domain: "live-output-pcm.typed.v1",
            cancellationRequested: cancellationRequested
        ) { sink in
            sink.aggregate("LiveOutputPCM")
            sink.field("channelCount"); sink.int(2)
            sink.field("frameCount"); sink.int(left.count)
            sink.field("left"); sink.collection(left.count)
            for (index, sample) in left.enumerated() {
                if index.isMultiple(of: 4_096), cancellationRequested() {
                    return false
                }
                sink.float(sample)
            }
            sink.field("right"); sink.collection(right.count)
            for (index, sample) in right.enumerated() {
                if index.isMultiple(of: 4_096), cancellationRequested() {
                    return false
                }
                sink.float(sample)
            }
            return true
        }
    }

    package static func liveOutputWindowEvidence(
        _ evidence: LiveOutputWindowEvidence
    ) -> String {
        digest(domain: "live-output-window-evidence.typed.v1") { sink in
            sink.aggregate("LiveOutputWindowEvidence")
            sink.field("schemaVersion"); sink.int(evidence.schemaVersion)
            sink.field("analyzerVersion"); sink.string(evidence.analyzerVersion)
            sink.field("engineVersion"); sink.string(evidence.engineVersion)
            sink.field("evidenceVersion"); sink.string(evidence.evidenceVersion)
            sink.field("qualityPolicyVersion")
            sink.string(evidence.qualityPolicyVersion)
            sink.field("evaluatorVersion"); sink.string(evidence.evaluatorVersion)
            sink.field("controllerPolicyVersion")
            sink.string(evidence.controllerPolicyVersion)
            sink.field("phraseIndex"); sink.int(evidence.phraseIndex)
            sink.field("planFingerprint"); sink.string(evidence.planFingerprint)
            sink.field("phraseKind"); sink.raw(evidence.phraseKind.rawValue)
            sink.field("chapterChanged"); sink.bool(evidence.chapterChanged)
            sink.field("routeGeneration"); sink.int(evidence.routeGeneration)
            sink.field("controllerRevision"); sink.int(evidence.controllerRevision)
            sink.field("playerSampleRange.lowerBound")
            sink.int64(evidence.playerSampleRange.lowerBound)
            sink.field("playerSampleRange.upperBound")
            sink.int64(evidence.playerSampleRange.upperBound)
            sink.field("sampleRate"); sink.double(evidence.sampleRate)
            sink.field("frameCount"); sink.int(evidence.frameCount)
            sink.field("applicableCheckpoints")
            sink.collection(evidence.applicableCheckpoints.count)
            for checkpoint in evidence.applicableCheckpoints {
                sink.raw(checkpoint.rawValue)
            }
            let capture = evidence.captureProvenance
            sink.field("capture.schemaVersion")
            sink.int(LiveOutputCaptureProvenance.schemaVersion)
            sink.field("capture.packetCount"); sink.int(capture.packetCount)
            sink.field("capture.firstPacketSequence")
            sink.uint64(capture.firstPacketSequence)
            sink.field("capture.lastPacketSequence")
            sink.uint64(capture.lastPacketSequence)
            sink.field("capture.droppedPacketDelta")
            sink.uint64(capture.droppedPacketDelta)
            sink.field("capture.rejectedPacketDelta")
            sink.uint64(capture.rejectedPacketDelta)
            sink.field("capture.queueCapacity"); sink.int(capture.queueCapacity)
            sink.field("capture.maximumPacketFrameCount")
            sink.int(capture.maximumPacketFrameCount)
            sink.field("capture.queueStorageByteCount")
            sink.int(capture.queueStorageByteCount)
            sink.field("capture.consumerScratchByteCount")
            sink.int(capture.consumerScratchByteCount)
            sink.field("capture.activeWindowByteCount")
            sink.int(capture.activeWindowByteCount)
            sink.field("capture.workingMemoryByteCount")
            sink.int(capture.workingMemoryByteCount)
            sink.field("capture.coveredFrameCount")
            sink.int(capture.coveredFrameCount)
            sink.field("capture.sampleDiscontinuityCount")
            sink.int(capture.sampleDiscontinuityCount)
            sink.field("capture.gapFrameCount")
            sink.int(capture.gapFrameCount)
            sink.field("capture.overlapFrameCount")
            sink.int(capture.overlapFrameCount)
            sink.field("captureBounded"); sink.bool(evidence.captureBounded)
            sink.field("pcmFingerprint"); sink.string(evidence.pcmFingerprint)
            sink.field("integratedLoudnessLUFS")
            sink.double(evidence.integratedLoudnessLUFS)
            sink.field("maximumMomentaryLoudnessLUFS")
            sink.double(evidence.maximumMomentaryLoudnessLUFS)
            sink.field("maximumShortTermLoudnessLUFS")
            sink.double(evidence.maximumShortTermLoudnessLUFS)
            sink.field("loudnessRangeLU"); sink.double(evidence.loudnessRangeLU)
            sink.field("momentaryBlockCount"); sink.int(evidence.momentaryBlockCount)
            sink.field("absoluteGatedBlockCount")
            sink.int(evidence.absoluteGatedBlockCount)
            sink.field("relativeGatedBlockCount")
            sink.int(evidence.relativeGatedBlockCount)
            sink.field("shortTermBlockCount"); sink.int(evidence.shortTermBlockCount)
            sink.field("loudnessMaximumBufferedFrameCount")
            sink.int(evidence.loudnessMaximumBufferedFrameCount)
            sink.field("loudnessPeakWorkingByteCount")
            sink.int(evidence.loudnessPeakWorkingByteCount)
            sink.field("leftTruePeakLinear")
            sink.double(evidence.leftTruePeakLinear)
            sink.field("rightTruePeakLinear")
            sink.double(evidence.rightTruePeakLinear)
            sink.field("maximumTruePeakLinear")
            sink.double(evidence.maximumTruePeakLinear)
            sink.field("leftTruePeakDBTP")
            sink.double(evidence.leftTruePeakDBTP)
            sink.field("rightTruePeakDBTP")
            sink.double(evidence.rightTruePeakDBTP)
            sink.field("truePeakDBTP"); sink.double(evidence.truePeakDBTP)
            sink.field("isActiveProgram"); sink.bool(evidence.isActiveProgram)
            sink.field("complete"); sink.bool(evidence.complete)
        }
    }

    package static func liveMasterHeadroomTarget(
        _ target: LiveMasterHeadroomTarget
    ) -> String {
        digest(domain: "live-master-headroom-target.typed.v1") { sink in
            sink.aggregate("LiveMasterHeadroomTarget")
            sink.field("schemaVersion"); sink.int(target.schemaVersion)
            sink.field("sourceObservationFingerprint")
            sink.string(target.sourceObservationFingerprint)
            sink.field("phraseIndex"); sink.int(target.phraseIndex)
            sink.field("planFingerprint"); sink.string(target.planFingerprint)
            sink.field("routeGeneration"); sink.int(target.routeGeneration)
            sink.field("controllerRevision"); sink.int(target.controllerRevision)
            sink.field("playerSampleRange.lowerBound")
            sink.int64(target.playerSampleRange.lowerBound)
            sink.field("playerSampleRange.upperBound")
            sink.int64(target.playerSampleRange.upperBound)
            sink.field("sampleRate"); sink.double(target.sampleRate)
            sink.field("applicableCheckpoints")
            sink.collection(target.applicableCheckpoints.count)
            for checkpoint in target.applicableCheckpoints {
                sink.raw(checkpoint.rawValue)
            }
            sink.field("selectedLoudnessCheckpoint")
            sink.raw(target.selectedLoudnessCheckpoint.rawValue)
            sink.field("selectedTruePeakCheckpoint")
            sink.raw(target.selectedTruePeakCheckpoint.rawValue)
            sink.field("analyzerVersion"); sink.string(target.analyzerVersion)
            sink.field("engineVersion"); sink.string(target.engineVersion)
            sink.field("evidenceVersion"); sink.string(target.evidenceVersion)
            sink.field("qualityPolicyVersion")
            sink.string(target.qualityPolicyVersion)
            sink.field("evaluatorVersion"); sink.string(target.evaluatorVersion)
            sink.field("controllerPolicyVersion")
            sink.string(target.controllerPolicyVersion)
            sink.field("profileVersion"); sink.string(target.profileVersion)
            sink.field("profileFingerprint")
            sink.string(target.profileFingerprint)
            sink.field("loudnessLowerLUFS")
            sink.double(target.loudnessLowerLUFS)
            sink.field("loudnessUpperLUFS")
            sink.double(target.loudnessUpperLUFS)
            sink.field("loudnessMidpointLUFS")
            sink.double(target.loudnessMidpointLUFS)
            sink.field("truePeakLowerDBTP")
            sink.double(target.truePeakLowerDBTP)
            sink.field("truePeakUpperDBTP")
            sink.double(target.truePeakUpperDBTP)
            sink.field("truePeakMidpointDBTP")
            sink.double(target.truePeakMidpointDBTP)
        }
    }

    /// Typed candidate-provenance identity for the Core-owned reduced
    /// proposal. The proposal retains its own Core fingerprint so later DSP
    /// candidate evidence can bind both the semantic payload and its canonical
    /// Core wire identity without reflecting over the value.
    package static func liveMasterHeadroomProposal(
        _ proposal: LiveMasterHeadroomProposal
    ) -> String {
        digest(domain: "live-master-headroom-proposal.typed.v1") { sink in
            sink.aggregate("LiveMasterHeadroomProposal")
            sink.field("schemaVersion")
            sink.int(LiveMasterHeadroomProposal.schemaVersion)
            sink.field("controllerPolicyVersion")
            sink.string(proposal.controllerPolicyVersion)
            sink.field("targetFingerprint")
            sink.string(proposal.targetFingerprint)
            sink.field("sourcePhraseIndex")
            sink.int(proposal.sourcePhraseIndex)
            sink.field("sourcePlanFingerprint")
            sink.string(proposal.sourcePlanFingerprint)
            sink.field("routeGeneration")
            sink.int(proposal.routeGeneration)
            sink.field("playerSampleRange.lowerBound")
            sink.int64(proposal.playerSampleRange.lowerBound)
            sink.field("playerSampleRange.upperBound")
            sink.int64(proposal.playerSampleRange.upperBound)
            sink.field("observationFingerprint")
            sink.presence(proposal.observationFingerprint != nil)
            if let observationFingerprint = proposal.observationFingerprint {
                sink.string(observationFingerprint)
            }
            sink.field("incomingRevision")
            sink.int(proposal.incomingRevision)
            sink.field("incomingStateFingerprint")
            sink.string(proposal.incomingStateFingerprint)
            sink.field("outcome")
            sink.raw(proposal.outcome.rawValue)
            sink.field("reasonCodes")
            sink.collection(proposal.reasonCodes.count)
            for reason in proposal.reasonCodes {
                sink.raw(reason.rawValue)
            }
            sink.field("proposedTrimDB")
            sink.double(proposal.proposedTrimDB)
            sink.field("proposedCleanWindows")
            sink.int(proposal.proposedCleanWindows)
            sink.field("earliestEligibleFutureSample")
            sink.int64(proposal.earliestEligibleFutureSample)
            sink.field("coreFingerprint")
            sink.string(proposal.fingerprint)
        }
    }

    /// One controller identity binds both independent bounded responsibilities:
    /// the existing kick/foundation fader and the terminal attenuation-only
    /// live master. The live state already binds its accepted proposal. A
    /// pending proposal can additionally participate in diagnostic identities;
    /// candidate evidence binds it separately before acceptance so it cannot
    /// alter the committed controller identity on a truthful hold.
    package static func combinedController(
        kickCorrectionDB: Double,
        liveMasterHeadroom: LiveMasterHeadroomContinuationState,
        proposalFingerprint: String?
    ) -> String {
        combinedController(
            kickCorrectionDB: kickCorrectionDB,
            liveMasterStateFingerprint: liveMasterHeadroom.fingerprint,
            proposalFingerprint: proposalFingerprint
        )
    }

    package static func combinedController(
        kickCorrectionDB: Double,
        liveMasterStateFingerprint: String,
        proposalFingerprint: String?
    ) -> String {
        digest(domain: "combined-controller.typed.v1") { sink in
            sink.aggregate("CombinedController")
            sink.field("kickCorrectionDB")
            sink.double(kickCorrectionDB)
            sink.field("liveMasterStateFingerprint")
            sink.string(liveMasterStateFingerprint)
            sink.field("proposalFingerprint")
            sink.presence(proposalFingerprint != nil)
            if let proposalFingerprint {
                sink.string(proposalFingerprint)
            }
        }
    }

    package static func renderDSPContinuation(
        renderState: RenderState,
        generatedDSPState: GeneratedDSPContinuationState
    ) -> String {
        digest(domain: "render-dsp-continuation.typed.v4") { sink in
            sink.field("renderState"); encode(renderState, into: &sink)
            sink.field("generatedDSPState"); encode(generatedDSPState, into: &sink)
        }
    }

    package static func renderDSPContinuation(
        renderState: RenderState,
        generatedDSPState: GeneratedDSPContinuationState,
        cancellationRequested: @Sendable () -> Bool
    ) -> String? {
        cancellableDigest(
            domain: "render-dsp-continuation.typed.v4",
            cancellationRequested: cancellationRequested
        ) { sink in
            sink.field("renderState")
            guard encode(
                renderState,
                into: &sink,
                cancellationRequested: cancellationRequested
            ) else {
                return false
            }
            sink.field("generatedDSPState")
            return encode(
                generatedDSPState,
                into: &sink,
                cancellationRequested: cancellationRequested
            )
        }
    }
}

private extension AutonomousTypedFingerprint {
    static func digest(
        domain: String,
        body: (inout StreamingFNV1a) -> Void
    ) -> String {
        var sink = StreamingFNV1a()
        sink.domain(domain)
        body(&sink)
        return fixedWidthFingerprintHex(sink.value)
    }

    static func cancellableDigest(
        domain: String,
        cancellationRequested: @Sendable () -> Bool,
        body: (inout StreamingFNV1a) -> Bool
    ) -> String? {
        guard !cancellationRequested() else { return nil }
        var sink = StreamingFNV1a()
        sink.domain(domain)
        guard body(&sink), !cancellationRequested() else { return nil }
        return fixedWidthFingerprintHex(sink.value)
    }

    // MARK: Autonomous phrase plan

    static func encode(_ value: AutonomousPhrasePlan, into sink: inout StreamingFNV1a) {
        sink.aggregate("AutonomousPhrasePlan")
        sink.field("phraseIndex"); sink.int(value.phraseIndex)
        sink.field("startBar"); sink.int(value.startBar)
        sink.field("presentationStartBar"); sink.int(value.presentationStartBar)
        sink.field("barCount"); sink.int(value.barCount)
        sink.field("kind"); sink.raw(value.kind.rawValue)
        sink.field("scene"); encode(value.scene, into: &sink)
        sink.field("dna"); encode(value.dna, into: &sink)
        sink.field("resolvedBars"); sink.collection(value.resolvedBars.count)
        for bar in value.resolvedBars { encode(bar, into: &sink) }
        sink.field("openedDebt"); sink.presence(value.openedDebt != nil)
        if let debt = value.openedDebt { encode(debt, into: &sink) }
        sink.field("paidDebtIDs"); sink.collection(value.paidDebtIDs.count)
        for id in value.paidDebtIDs { sink.int(id) }
        sink.field("requestsTopologyMutation"); sink.bool(value.requestsTopologyMutation)
        sink.field("interest"); encode(value.interest, into: &sink)
        sink.field("performanceCharacterEvidence")
        encode(value.performanceCharacterEvidence, into: &sink)
        sink.field("incomingHarmonicContinuation")
        sink.collection(value.incomingHarmonicContinuation.voices.count)
        for voice in value.incomingHarmonicContinuation.voices {
            sink.aggregate("PadVoice")
            sink.field("modalDegree"); sink.int(voice.modalDegree)
            sink.field("semitone"); sink.int(voice.semitone)
            sink.field("frequencyRatio"); sink.double(voice.frequencyRatio)
        }
        sink.field("incomingResampledMemory")
        encode(value.incomingResampledMemory, into: &sink)
        sink.field("endingResampledMemory")
        encode(value.endingResampledMemory, into: &sink)
        sink.field("endingInterlockState"); encode(value.endingInterlockState, into: &sink)
        sink.field("endingSpatialContrastState")
        encode(value.endingSpatialContrastState, into: &sink)
        sink.field("endingNarrativeState"); encode(value.endingNarrativeState, into: &sink)
        sink.field("longHorizonSelection")
        encode(value.longHorizonSelection, into: &sink)
        sink.field("longHorizonEnergyCoordination")
        encode(value.longHorizonEnergyCoordination, into: &sink)
        sink.field("materialWorld")
        encode(value.materialWorld, into: &sink)
        sink.field("effectCarrier")
        sink.aggregate("LongHorizonEffectCarrierArticulation")
        sink.field("stateSchema")
        sink.string(value.effectCarrier.state.schemaIdentifier)
        sink.field("worldID"); sink.uint64(value.effectCarrier.state.worldID)
        sink.field("status"); sink.raw(value.effectCarrier.state.status.rawValue)
        sink.field("role")
        sink.presence(value.effectCarrier.state.role != nil)
        if let role = value.effectCarrier.state.role { sink.raw(role.rawValue) }
        sink.field("selectedAtPhraseIndex")
        sink.presence(value.effectCarrier.state.selectedAtPhraseIndex != nil)
        if let index = value.effectCarrier.state.selectedAtPhraseIndex {
            sink.int(index)
        }
        sink.field("active"); sink.bool(value.effectCarrier.active)
        sink.field("carrierDose"); sink.double(value.effectCarrier.carrierDose)
        sink.field("nonCarrierDose")
        sink.double(value.effectCarrier.nonCarrierDose)
        sink.field("qualityRecoveryContext")
        sink.aggregate("AutonomousQualityRecoveryContext")
        sink.field("wave"); sink.uint64(value.qualityRecoveryContext.wave)
        sink.field("ordinal"); sink.int(value.qualityRecoveryContext.ordinal)
        sink.field("presentedRepeatBars")
        sink.uint64(value.qualityRecoveryContext.presentedRepeatBars)
        sink.field("intentSchema")
        sink.int(value.qualityRecoveryContext.intent.schemaVersion)
        sink.field("symbolicDensity")
        sink.raw(value.qualityRecoveryContext.intent.symbolicDensity.rawValue)
        sink.field("spectralMovement")
        sink.raw(value.qualityRecoveryContext.intent.spectralMovement.rawValue)
        sink.field("kickCrestReduction")
        sink.raw(value.qualityRecoveryContext.intent.kickCrestReduction.rawValue)
        sink.field("longHorizonEffectSentence")
        sink.presence(value.longHorizonEffectSentence != nil)
        if let sentence = value.longHorizonEffectSentence {
            encode(sentence, into: &sink)
        }
        let synthPerformance = SynthPerformancePlan(
            scene: value.scene,
            dna: value.dna,
            kind: value.kind,
            resolvedBars: value.resolvedBars,
            materialWorld: value.materialWorld,
            compositionBars: value.phraseComposition
        )
        sink.field("resolvedUpperNotes")
        sink.collection(synthPerformance.bars.count)
        for bar in synthPerformance.bars {
            sink.aggregate("SynthPerformanceBarUpperNotes")
            sink.field("bar"); sink.int(bar.bar)
            sink.field("tonalEnvelopeExpansionEligible")
            sink.bool(bar.tonalEnvelopeExpansionEligible)
            sink.field("spectralRevealEligible")
            sink.bool(bar.spectralRevealEligible)
            sink.field("upperTimingRelation")
            sink.raw(bar.upperTimingRelation.rawValue)
            sink.field("composition")
            encode(bar.composition, into: &sink)
            sink.field("notes"); sink.collection(bar.upperNotes.count)
            for note in bar.upperNotes { encode(note, into: &sink) }
            sink.field("polymetricEvidence")
            sink.collection(bar.polymetricEvidence.count)
            for evidence in bar.polymetricEvidence {
                encode(evidence, into: &sink)
            }
        }
    }

    static func encode(
        _ value: LongHorizonMaterialWorldPlan,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonMaterialWorldPlan")
        sink.field("worldID"); sink.uint64(value.worldID)
        sink.field("worldFingerprint"); sink.raw(value.worldFingerprint)
        sink.field("parentFingerprint")
        sink.presence(value.parentFingerprint != nil)
        if let parent = value.parentFingerprint { sink.raw(parent) }
        sink.field("generation"); sink.int(value.generation)
        sink.field("handoff"); sink.raw(value.handoff.rawValue)
        sink.field("sourceRhythm"); sink.raw(value.sourceAxes.rhythm.rawValue)
        sink.field("sourceMotif"); sink.raw(value.sourceAxes.motif.rawValue)
        sink.field("sourceRoles"); sink.raw(value.sourceAxes.roles.rawValue)
        sink.field("sourceHarmony"); sink.raw(value.sourceAxes.harmony.rawValue)
        sink.field("sourceArchitecture")
        sink.raw(value.sourceAxes.architecture.rawValue)
        sink.field("sourceEffectSpectralFocus")
        sink.double(value.sourceAxes.effect.spectralFocus)
        sink.field("sourceEffectNonlinearPressure")
        sink.double(value.sourceAxes.effect.nonlinearPressure)
        sink.field("sourceEffectModulationMotion")
        sink.double(value.sourceAxes.effect.modulationMotion)
        sink.field("sourceEffectEchoMemory")
        sink.double(value.sourceAxes.effect.echoMemory)
        sink.field("sourceEffectSpatialDepth")
        sink.double(value.sourceAxes.effect.spatialDepth)
        sink.field("rhythm"); sink.raw(value.axes.rhythm.rawValue)
        sink.field("motif"); sink.raw(value.axes.motif.rawValue)
        sink.field("roles"); sink.raw(value.axes.roles.rawValue)
        sink.field("harmony"); sink.raw(value.axes.harmony.rawValue)
        sink.field("architecture"); sink.raw(value.axes.architecture.rawValue)
        sink.field("effectSpectralFocus"); sink.double(value.axes.effect.spectralFocus)
        sink.field("effectNonlinearPressure")
        sink.double(value.axes.effect.nonlinearPressure)
        sink.field("effectModulationMotion")
        sink.double(value.axes.effect.modulationMotion)
        sink.field("effectEchoMemory"); sink.double(value.axes.effect.echoMemory)
        sink.field("effectSpatialDepth"); sink.double(value.axes.effect.spatialDepth)
        sink.field("polymetricGrammar")
        sink.aggregate("LongHorizonPolymetricGrammar")
        sink.field("schemaVersion"); sink.int(value.polymetricGrammar.schemaVersion)
        sink.field("schemaIdentifier")
        sink.string(value.polymetricGrammar.schemaIdentifier)
        sink.field("isEnabled"); sink.bool(value.polymetricGrammar.isEnabled)
        sink.field("activationBar"); sink.int(value.polymetricGrammar.activationBar)
        sink.field("combinedPeriodInSteps")
        sink.int(value.polymetricGrammar.combinedPeriodInSteps)
        sink.field("fingerprint"); sink.raw(value.polymetricGrammar.fingerprint)
        sink.field("laneGeometries")
        sink.collection(value.polymetricGrammar.laneGeometries.count)
        for geometry in value.polymetricGrammar.laneGeometries {
            sink.aggregate("LongHorizonPolymetricLaneGeometry")
            sink.field("lane"); sink.raw(geometry.lane.rawValue)
            sink.field("stepLength"); sink.int(geometry.stepLength)
            sink.field("pulseCount"); sink.int(geometry.pulseCount)
            sink.field("rotation"); sink.int(geometry.rotation)
        }
        sink.field("progress"); sink.double(value.progress)
    }

    static func encode(_ value: PhraseCompositionBar, into sink: inout StreamingFNV1a) {
        sink.aggregate("PhraseCompositionBar")
        sink.field("bar"); sink.int(value.bar)
        sink.field("audioSlice"); sink.presence(value.audioSlice != nil)
        if let slice = value.audioSlice {
            sink.aggregate("AudioSlicePlan")
            sink.field("sourceStartStep"); sink.int(slice.sourceStartStep)
            sink.field("sourceLengthInSteps"); sink.double(slice.sourceLengthInSteps)
            sink.field("sourceKind"); sink.raw(slice.sourceKind.rawValue)
            sink.field("texture"); sink.raw(slice.texture.rawValue)
            sink.field("textureSeed"); sink.uint64(slice.textureSeed)
            sink.field("resampledMemorySource")
            sink.presence(slice.resampledMemorySource != nil)
            if let source = slice.resampledMemorySource {
                encode(source, into: &sink)
            }
            sink.field("triggers"); sink.collection(slice.triggers.count)
            for trigger in slice.triggers {
                sink.aggregate("AudioSliceTrigger")
                sink.field("onsetStep"); sink.int(trigger.onsetStep)
                sink.field("playbackRate"); sink.double(trigger.playbackRate)
                sink.field("direction"); sink.raw(trigger.direction.rawValue)
                sink.field("gain"); sink.double(trigger.gain)
            }
        }
        sink.field("arpeggiator"); sink.presence(value.arpeggiator != nil)
        if let arpeggiator = value.arpeggiator {
            sink.aggregate("ArpeggiatorPlan")
            sink.field("direction"); sink.raw(arpeggiator.direction.rawValue)
            sink.field("rateInSteps"); sink.int(arpeggiator.rateInSteps)
            sink.field("octaveSpan"); sink.int(arpeggiator.octaveSpan)
            sink.field("rotation"); sink.int(arpeggiator.rotation)
            sink.field("steps"); sink.collection(arpeggiator.steps.count)
            for step in arpeggiator.steps {
                sink.aggregate("ArpeggiatorStep")
                sink.field("onsetStep"); sink.int(step.onsetStep)
                sink.field("durationInSteps"); sink.double(step.durationInSteps)
                sink.field("frequencyRatio"); sink.double(step.frequencyRatio)
                sink.field("velocity"); sink.double(step.velocity)
                sink.field("octave"); sink.int(step.octave)
            }
        }
        sink.field("padVoicing"); sink.presence(value.padVoicing != nil)
        if let pad = value.padVoicing {
            sink.aggregate("PadVoicing")
            sink.field("function"); sink.raw(pad.function.rawValue)
            sink.field("harmonicDisclosureStage")
            sink.raw(pad.harmonicDisclosureStage.rawValue)
            sink.field("onsetStep"); sink.int(pad.onsetStep)
            sink.field("durationInSteps"); sink.double(pad.durationInSteps)
            sink.field("voices"); sink.collection(pad.voices.count)
            for voice in pad.voices {
                sink.aggregate("PadVoice")
                sink.field("modalDegree"); sink.int(voice.modalDegree)
                sink.field("semitone"); sink.int(voice.semitone)
                sink.field("frequencyRatio"); sink.double(voice.frequencyRatio)
            }
            sink.field("commonToneCount"); sink.int(pad.commonToneCount)
            sink.field("totalMovementInSemitones")
            sink.int(pad.totalMovementInSemitones)
            sink.field("maximumLeapInSemitones")
            sink.int(pad.maximumLeapInSemitones)
            sink.field("contraryOuterMotion"); sink.bool(pad.contraryOuterMotion)
            sink.field("instrument"); encode(Optional(pad.instrument), into: &sink)
            sink.field("rhythmicModulationRelation")
            sink.raw(pad.rhythmicModulation.relation.rawValue)
            sink.field("rhythmicModulationPhaseOffset")
            sink.int(pad.rhythmicModulation.phaseOffset)
        }
    }

    static func encode(
        _ value: ResampledMemoryContinuationState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("ResampledMemoryContinuationState")
        sink.collection(value.sources.count)
        for source in value.sources { encode(source, into: &sink) }
    }

    static func encode(
        _ value: ResampledMemorySource,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("ResampledMemorySource")
        sink.field("absoluteBar"); sink.int(value.absoluteBar)
        sink.field("sourceStep"); sink.int(value.sourceStep)
        sink.field("synthesisSeed"); sink.uint64(value.synthesisSeed)
        sink.field("bpm"); sink.double(value.bpm)
        sink.field("section"); sink.raw(value.section.rawValue)
        sink.field("combinedAccent"); sink.double(value.combinedAccent)
        sink.field("kickMorphology"); encode(value.kickMorphology, into: &sink)
    }

    static func encode(_ value: ResolvedUpperNote, into sink: inout StreamingFNV1a) {
        sink.aggregate("ResolvedUpperNote")
        sink.field("role"); sink.raw(value.role.rawValue)
        sink.field("onsetStep"); sink.int(value.onsetStep)
        sink.field("durationInSteps"); sink.double(value.durationInSteps)
        sink.field("startFrequencyRatio"); sink.double(value.startFrequencyRatio)
        sink.field("endFrequencyRatio"); sink.double(value.endFrequencyRatio)
        sink.field("velocity"); sink.double(value.velocity)
        sink.field("gate"); sink.raw(value.gate.rawValue)
        sink.field("timbreIntent"); encode(value.timbreIntent, into: &sink)
        sink.field("envelopeRelation"); sink.raw(value.envelopeRelation.rawValue)
        sink.field("spectralRevealRelation")
        sink.raw(value.spectralReveal.relation.rawValue)
        sink.field("spectralRevealAperture")
        sink.double(value.spectralReveal.aperture)
        sink.field("timingOffsetInSteps"); sink.double(value.timingOffsetInSteps)
        sink.field("instrument"); encode(Optional(value.instrument), into: &sink)
    }

    static func encode(_ value: TechnoScene, into sink: inout StreamingFNV1a) {
        sink.aggregate("TechnoScene")
        sink.field("seed"); sink.uint64(value.seed)
        sink.field("bpm"); sink.double(value.bpm)
        sink.field("drive"); sink.double(value.drive)
        sink.field("darkness"); sink.double(value.darkness)
        sink.field("hypnosis"); sink.double(value.hypnosis)
        sink.field("beatShape"); sink.double(value.beatShape)
        sink.field("musicalIntent"); encode(value.musicalIntent, into: &sink)
        sink.field("aggression"); sink.double(value.aggression)
        sink.field("machineTexture"); sink.double(value.machineTexture)
        sink.field("drone"); sink.double(value.drone)
        sink.field("atmosphere"); sink.double(value.atmosphere)
        sink.field("atmosphericDarkness"); sink.double(value.atmosphericDarkness)
        sink.field("drumChaos"); sink.double(value.drumChaos)
        sink.field("synthChaos"); sink.double(value.synthChaos)
        sink.field("textureChaos"); sink.double(value.textureChaos)
        sink.field("melodicity"); sink.double(value.melodicity)
        sink.field("synthPresence"); sink.double(value.synthPresence)
        sink.field("noteActivity"); sink.double(value.noteActivity)
        sink.field("syncopation"); sink.double(value.syncopation)
        sink.field("polyrhythm"); sink.double(value.polyrhythm)
        sink.field("steps"); sink.collection(value.steps.count)
        for step in value.steps { encode(step, into: &sink) }
        sink.field("character"); encode(value.character, into: &sink)
        sink.field("groove"); encode(value.groove, into: &sink)
        sink.field("motif"); sink.collection(value.motif.count)
        for event in value.motif { encode(event, into: &sink) }
        sink.field("sequencer"); sink.collection(value.sequencer.count)
        for event in value.sequencer { encode(event, into: &sink) }
    }

    static func encode(_ value: MusicalIntent, into sink: inout StreamingFNV1a) {
        sink.aggregate("MusicalIntent")
        let controls = MusicalControl.allCases.sorted { $0.rawValue < $1.rawValue }
        sink.dictionary(controls.count)
        for control in controls {
            sink.raw(control.rawValue)
            sink.double(value[control])
        }
    }

    static func encode(_ value: Step, into sink: inout StreamingFNV1a) {
        sink.aggregate("Step")
        sink.field("kick"); sink.bool(value.kick)
        sink.field("hat"); sink.bool(value.hat)
        sink.field("clap"); sink.bool(value.clap)
        sink.field("bass"); sink.bool(value.bass)
    }

    static func encode(_ value: RenderCharacter, into sink: inout StreamingFNV1a) {
        sink.aggregate("RenderCharacter")
        sink.field("kickWeight"); sink.double(value.kickWeight)
        sink.field("percussionBrightness"); sink.double(value.percussionBrightness)
        sink.field("bassDecay"); sink.double(value.bassDecay)
        sink.field("bassLevel"); sink.double(value.bassLevel)
    }

    static func encode(_ value: GrooveProfile, into sink: inout StreamingFNV1a) {
        sink.aggregate("GrooveProfile")
        sink.field("swingPercent"); sink.double(value.swingPercent)
        sink.field("events"); sink.collection(value.events.count)
        for event in value.events { encode(event, into: &sink) }
    }

    static func encode(_ value: TimedEvent, into sink: inout StreamingFNV1a) {
        sink.aggregate("TimedEvent")
        sink.field("stepIndex"); sink.int(value.stepIndex)
        sink.field("kind"); sink.raw(value.kind.rawValue)
        sink.field("offsetInStep"); sink.double(value.offsetInStep)
        sink.field("bar"); sink.int(value.bar)
    }

    static func encode(_ value: SynthEvent, into sink: inout StreamingFNV1a) {
        sink.aggregate("SynthEvent")
        sink.field("stepIndex"); sink.int(value.stepIndex)
        sink.field("offsetInStep"); sink.double(value.offsetInStep)
        sink.field("scaleDegree"); sink.int(value.scaleDegree)
        sink.field("frequency"); sink.double(value.frequency)
        sink.field("durationInSteps"); sink.double(value.durationInSteps)
        sink.field("bar"); sink.int(value.bar)
        sink.field("sourceIntent"); sink.raw(value.sourceIntent.rawValue)
    }

    static func encode(_ value: SequencerEvent, into sink: inout StreamingFNV1a) {
        sink.aggregate("SequencerEvent")
        sink.field("stepIndex"); sink.int(value.stepIndex)
        sink.field("scaleDegree"); sink.int(value.scaleDegree)
        sink.field("frequency"); sink.double(value.frequency)
        sink.field("durationInSteps"); sink.double(value.durationInSteps)
        sink.field("bar"); sink.int(value.bar)
        sink.field("kind"); sink.raw(value.kind.rawValue)
    }

    static func encode(_ value: SceneDNA, into sink: inout StreamingFNV1a) {
        sink.aggregate("SceneDNA")
        sink.field("sceneSeed"); sink.uint64(value.sceneSeed)
        sink.field("tonalCenter"); sink.int(value.tonalCenter)
        sink.field("modalIdentity"); sink.raw(value.modalIdentity.rawValue)
        sink.field("modalDegrees"); sink.collection(value.modalDegrees.count)
        for degree in value.modalDegrees { sink.int(degree) }
        sink.field("rhythm"); encode(value.rhythm, into: &sink)
        sink.field("motif"); encode(value.motif, into: &sink)
        sink.field("characteristicSyncopations")
        sink.collection(value.characteristicSyncopations.count)
        for step in value.characteristicSyncopations { sink.int(step) }
        sink.field("foregroundPriority"); sink.collection(value.foregroundPriority.count)
        for role in value.foregroundPriority { sink.raw(role.rawValue) }
        sink.field("timbralFamily"); sink.int(value.timbralFamily)
        sink.field("foundationCompanion"); sink.raw(value.foundationCompanion.rawValue)
    }

    static func encode(_ value: RhythmCell, into sink: inout StreamingFNV1a) {
        sink.aggregate("RhythmCell")
        sink.field("kickSteps"); sink.collection(value.kickSteps.count)
        for step in value.kickSteps { sink.int(step) }
        sink.field("bassSteps"); sink.collection(value.bassSteps.count)
        for step in value.bassSteps { sink.int(step) }
        sink.field("hatSteps"); sink.collection(value.hatSteps.count)
        for step in value.hatSteps { sink.int(step) }
        sink.field("accentSteps"); sink.collection(value.accentSteps.count)
        for step in value.accentSteps { sink.int(step) }
        sink.field("swingPercent"); sink.double(value.swingPercent)
    }

    static func encode(_ value: MotifCell, into sink: inout StreamingFNV1a) {
        sink.aggregate("MotifCell")
        sink.field("degrees"); sink.collection(value.degrees.count)
        for degree in value.degrees { sink.int(degree) }
        sink.field("steps"); sink.collection(value.steps.count)
        for step in value.steps { sink.int(step) }
    }

    static func encode(_ value: ResolvedPerformanceBar, into sink: inout StreamingFNV1a) {
        sink.aggregate("ResolvedPerformanceBar")
        sink.field("performance"); encode(value.performance, into: &sink)
        sink.field("ensemble"); encode(value.ensemble, into: &sink)
        sink.field("kickSyntaxRole"); sink.raw(value.kickSyntaxRole.rawValue)
        sink.field("climaxHang")
        sink.presence(value.climaxHang != nil)
        if let hang = value.climaxHang {
            sink.aggregate("ClimaxHangArticulation")
            sink.field("relation"); sink.raw(hang.relation.rawValue)
            sink.field("startStep"); sink.int(hang.startStep)
            sink.field("endStep"); sink.int(hang.endStep)
        }
        sink.field("arrangementGesture"); sink.raw(value.arrangementGesture.rawValue)
        sink.field("percussionGear"); sink.raw(value.percussionGear.rawValue)
        sink.field("performanceCharacter"); sink.raw(value.performanceCharacter.rawValue)
        sink.field("foundationBehavior"); sink.raw(value.foundationBehavior.rawValue)
        sink.field("foundationRhythmicRelation")
        sink.raw(value.foundationRhythmicRelation.rawValue)
        sink.field("foundationCompanion"); sink.raw(value.foundationCompanion.rawValue)
        sink.field("pulseEchoEnabled"); sink.bool(value.pulseEchoEnabled)
        sink.field("interlockChapter"); sink.raw(value.interlockChapter.rawValue)
        sink.field("groovePulses"); sink.collection(value.groovePulses.count)
        for pulse in value.groovePulses { encode(pulse, into: &sink) }
        sink.field("closedHatDecayArticulations")
        sink.collection(value.closedHatDecayArticulations.count)
        for articulation in value.closedHatDecayArticulations {
            encode(articulation, into: &sink)
        }
        sink.field("upperPercussionTailArticulations")
        sink.collection(value.upperPercussionTailArticulations.count)
        for articulation in value.upperPercussionTailArticulations {
            sink.aggregate("UpperPercussionTailArticulation")
            sink.field("scoreEventIndex")
            sink.int(articulation.scoreEventIndex)
            sink.field("voice")
            sink.raw(articulation.voice.rawValue)
            sink.field("step")
            sink.int(articulation.step)
            sink.field("role")
            sink.raw(articulation.role.rawValue)
            sink.field("body")
            sink.raw(articulation.body.rawValue)
        }
        sink.field("modalPercussionArticulations")
        sink.collection(value.modalPercussionArticulations.count)
        for articulation in value.modalPercussionArticulations {
            encode(articulation, into: &sink)
        }
        sink.field("percussionEchoTexture")
        sink.presence(value.percussionEchoTexture != nil)
        if let texture = value.percussionEchoTexture {
            sink.aggregate("PercussionEchoTextureArticulation")
            sink.field("relation"); sink.raw(texture.relation.rawValue)
            sink.field("inputStep"); sink.int(texture.inputStep)
            sink.field("outputStartStep"); sink.int(texture.outputStartStep)
            sink.field("outputEndStep"); sink.int(texture.outputEndStep)
            sink.field("worldID"); sink.uint64(texture.worldID)
            sink.field("cadencePhase"); sink.int(texture.cadencePhase)
            sink.field("gapPhase"); sink.int(texture.gapPhase)
            sink.field("dominantSide")
            sink.presence(texture.dominantSide != nil)
            if let side = texture.dominantSide {
                sink.raw(side.rawValue)
            }
        }
        sink.field("percussionPolymetricEvidence")
        sink.presence(value.percussionPolymetricEvidence != nil)
        if let evidence = value.percussionPolymetricEvidence {
            encode(evidence, into: &sink)
        }
        sink.field("upperMusicalPump")
        sink.aggregate("UpperMusicalPumpArticulation")
        sink.field("schemaIdentifier")
        sink.string(value.upperMusicalPump.schemaIdentifier)
        sink.field("active"); sink.bool(value.upperMusicalPump.active)
        sink.field("kickAnchorSteps")
        sink.collection(value.upperMusicalPump.kickAnchorSteps.count)
        for step in value.upperMusicalPump.kickAnchorSteps { sink.int(step) }
        sink.field("attenuation")
        sink.double(value.upperMusicalPump.attenuation)
        sink.field("attackInBeats")
        sink.double(value.upperMusicalPump.attackInBeats)
        sink.field("releaseInBeats")
        sink.double(value.upperMusicalPump.releaseInBeats)
        sink.field("spatialContrast"); encode(value.spatialContrast, into: &sink)
        sink.field("narrative"); encode(value.narrative, into: &sink)
        sink.field("harmonicDisclosureRelationship")
        sink.raw(value.harmonicDisclosureRelationship.rawValue)
        sink.field("kickMorphology")
        encode(value.kickMorphology, into: &sink)
    }

    static func encode(
        _ value: LongHorizonPolymetricBarEvidence,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonPolymetricBarEvidence")
        sink.field("absoluteBar"); sink.int(value.absoluteBar)
        sink.field("lane"); sink.raw(value.lane.rawValue)
        sink.field("lanePhase"); sink.int(value.lanePhase)
        sink.field("sourceMask"); sink.uint64(UInt64(value.sourceMask))
        sink.field("appliedMask"); sink.uint64(UInt64(value.appliedMask))
        sink.field("eventCount"); sink.int(value.eventCount)
        sink.field("relocatedEventCount"); sink.int(value.relocatedEventCount)
        sink.field("collisionFallbackCount")
        sink.int(value.collisionFallbackCount)
        sink.field("combinedPeriodInSteps")
        sink.int(value.combinedPeriodInSteps)
        sink.field("protectedEventFingerprintBefore")
        sink.uint64(value.protectedEventFingerprintBefore)
        sink.field("protectedEventFingerprintAfter")
        sink.uint64(value.protectedEventFingerprintAfter)
    }

    static func encode(
        _ value: KickMorphologyArticulation,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("KickMorphologyArticulation")
        sink.field("version"); sink.string(value.version)
        sink.field("absoluteBar"); sink.int(value.absoluteBar)
        sink.field("presentationBar"); sink.int(value.presentationBar)
        sink.field("segmentIndex"); sink.int(value.segmentIndex)
        sink.field("episodeID"); sink.uint64(value.episodeID)
        sink.field("operatorKind"); sink.raw(value.operatorKind.rawValue)
        sink.field("episodeRelativeBar"); sink.int(value.episodeRelativeBar)
        sink.field("fromHome"); sink.raw(value.fromHome.rawValue)
        sink.field("toHome"); sink.raw(value.toHome.rawValue)
        sink.field("startProgress"); sink.double(value.startProgress)
        sink.field("endProgress"); sink.double(value.endProgress)
        sink.field("start"); encode(value.start, into: &sink)
        sink.field("end"); encode(value.end, into: &sink)
    }

    static func encode(
        _ value: KickMorphologyParameters,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("KickMorphologyParameters")
        sink.field("fundamentalHz"); sink.double(value.fundamentalHz)
        sink.field("pitchDepthHz"); sink.double(value.pitchDepthHz)
        sink.field("fastPitchDepthHz"); sink.double(value.fastPitchDepthHz)
        sink.field("pitchDecayPerSecond")
        sink.double(value.pitchDecayPerSecond)
        sink.field("fastPitchDecayPerSecond")
        sink.double(value.fastPitchDecayPerSecond)
        sink.field("bodyDecayPerSecond")
        sink.double(value.bodyDecayPerSecond)
        sink.field("subDecayPerSecond"); sink.double(value.subDecayPerSecond)
        sink.field("secondHarmonicLevel")
        sink.double(value.secondHarmonicLevel)
        sink.field("bodyDrive"); sink.double(value.bodyDrive)
        sink.field("subLevel"); sink.double(value.subLevel)
        sink.field("noiseClickLevel"); sink.double(value.noiseClickLevel)
        sink.field("tonalClickLevel"); sink.double(value.tonalClickLevel)
        sink.field("clickFrequencyHz"); sink.double(value.clickFrequencyHz)
        sink.field("presenceScale"); sink.double(value.presenceScale)
    }

    static func encode(
        _ value: LongHorizonPhraseSelection,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonPhraseSelection")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("schemaIdentifier"); sink.string(value.schemaIdentifier)
        sink.field("episodeID"); sink.presence(value.episodeID != nil)
        if let episodeID = value.episodeID { sink.uint64(episodeID) }
        sink.field("operatorKind"); sink.presence(value.operatorKind != nil)
        if let operatorKind = value.operatorKind { sink.raw(operatorKind.rawValue) }
        sink.field("phraseKind"); sink.raw(value.phraseKind.rawValue)
        sink.field("reason"); sink.raw(value.reason.rawValue)
    }

    static func encode(
        _ value: LongHorizonEnergyCoordination,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonEnergyCoordination")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("schemaIdentifier"); sink.string(value.schemaIdentifier)
        sink.field("phraseIndex"); sink.int(value.phraseIndex)
        sink.field("startBar"); sink.int(value.startBar)
        sink.field("phraseKind"); sink.raw(value.phraseKind.rawValue)
        sink.field("episodeID"); sink.presence(value.episodeID != nil)
        if let episodeID = value.episodeID { sink.uint64(episodeID) }
        sink.field("operatorKind"); sink.presence(value.operatorKind != nil)
        if let operatorKind = value.operatorKind { sink.raw(operatorKind.rawValue) }
        sink.field("selectionReason"); sink.raw(value.selectionReason.rawValue)
        sink.field("reason"); sink.raw(value.reason.rawValue)
        sink.field("target")
        sink.aggregate("LongHorizonEnergyTarget")
        sink.field("foundationAuthority")
        sink.raw(value.target.foundationAuthority.rawValue)
        sink.field("roleDensity"); sink.raw(value.target.roleDensity.rawValue)
        sink.field("percussionActivity")
        sink.raw(value.target.percussionActivity.rawValue)
        sink.field("protagonistPresence")
        sink.raw(value.target.protagonistPresence.rawValue)
        sink.field("harmonicDisclosure")
        sink.raw(value.target.harmonicDisclosure.rawValue)
        sink.field("timbralMotionIntent")
        sink.raw(value.target.timbralMotionIntent.rawValue)
        sink.field("spatialDistance")
        sink.raw(value.target.spatialDistance.rawValue)
        sink.field("transitionExpectation")
        sink.raw(value.target.transitionExpectation.rawValue)
    }

    static func encode(
        _ value: LongHorizonEffectSentence,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonEffectSentence")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("schemaIdentifier"); sink.string(value.schemaIdentifier)
        sink.field("phraseIndex"); sink.int(value.phraseIndex)
        sink.field("phraseKind"); sink.raw(value.phraseKind.rawValue)
        sink.field("sourceBar"); sink.int(value.sourceBar)
        sink.field("sourceVoice"); sink.raw(value.sourceVoice)
        sink.field("sourceStep"); sink.int(value.sourceStep)
        sink.field("answerStartStep"); sink.int(value.answerStartStep)
        sink.field("answerEndStep"); sink.int(value.answerEndStep)
        sink.field("arrangementGesture"); sink.raw(value.arrangementGesture)
        sink.field("capability"); sink.raw(value.capability.rawValue)
        sink.field("function"); sink.raw(value.function.rawValue)
        sink.field("attentionPriority")
        sink.raw(value.attentionPriority.rawValue)
    }

    static func encode(_ value: PerformanceBar, into sink: inout StreamingFNV1a) {
        sink.aggregate("PerformanceBar")
        sink.field("bar"); sink.int(value.bar)
        sink.field("phrase"); sink.int(value.phrase)
        sink.field("localBar"); sink.int(value.localBar)
        sink.field("phraseLength"); sink.int(value.phraseLength)
        sink.field("section"); sink.raw(value.section.rawValue)
        sink.field("tension"); sink.double(value.tension)
        sink.field("roles"); sink.collection(value.roles.count)
        for role in value.roles { sink.raw(role.rawValue) }
        sink.field("transformations"); sink.collection(value.transformations.count)
        for transformation in value.transformations { sink.raw(transformation.rawValue) }
        sink.field("signatureEvent"); sink.presence(value.signatureEvent != nil)
        if let event = value.signatureEvent { sink.raw(event.rawValue) }
        sink.field("eventSeed"); sink.uint64(value.eventSeed)
        sink.field("accentContour"); sink.collection(value.accentContour.count)
        for accent in value.accentContour { sink.double(accent) }
    }

    static func encode(_ value: EnsembleContext, into sink: inout StreamingFNV1a) {
        sink.aggregate("EnsembleContext")
        sink.field("focusRole"); sink.raw(value.focusRole.rawValue)
        sink.field("events"); sink.collection(value.events.count)
        for event in value.events { encode(event, into: &sink) }
        sink.field("kickAnchors"); sink.collection(value.kickAnchors.count)
        for anchor in value.kickAnchors { sink.int(anchor) }
        sink.field("intentionalPileup"); sink.bool(value.intentionalPileup)
    }

    static func encode(_ value: EnsembleResolvedEvent, into sink: inout StreamingFNV1a) {
        sink.aggregate("EnsembleResolvedEvent")
        sink.field("voice"); sink.raw(value.voice.rawValue)
        sink.field("step"); sink.int(value.step)
        sink.field("intensity"); sink.double(value.intensity)
        sink.field("relocated"); sink.bool(value.relocated)
    }

    static func encode(_ value: GroovePulseArticulation, into sink: inout StreamingFNV1a) {
        sink.aggregate("GroovePulseArticulation")
        sink.field("step"); sink.int(value.step)
        sink.field("pulseClass"); sink.raw(value.pulseClass.rawValue)
        sink.field("stage"); sink.raw(value.stage.rawValue)
        sink.field("intensity"); sink.double(value.intensity)
        sink.field("timingOffsetInSteps"); sink.double(value.timingOffsetInSteps)
        sink.field("strikeZone"); sink.raw(value.strikeZone.rawValue)
        sink.field("damping"); sink.double(value.damping)
        sink.field("timbreMicrovariation"); sink.double(value.timbreMicrovariation)
    }

    static func encode(_ value: ClosedHatDecayArticulation,
                       into sink: inout StreamingFNV1a) {
        sink.aggregate("ClosedHatDecayArticulation")
        sink.field("scoreEventIndex"); sink.int(value.scoreEventIndex)
        sink.field("step"); sink.int(value.step)
        sink.field("role"); sink.raw(value.role.rawValue)
    }

    static func encode(
        _ value: ModalPercussionArticulation,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("ModalPercussionArticulation")
        sink.field("scoreEventIndex"); sink.int(value.scoreEventIndex)
        sink.field("step"); sink.int(value.step)
        sink.field("use"); sink.raw(value.use.rawValue)
        sink.field("modalIdentity"); sink.raw(value.modalIdentity.rawValue)
        sink.field("modalDegree"); sink.int(value.modalDegree)
        sink.field("octave"); sink.int(value.octave)
        sink.field("fundamentalHz"); sink.double(value.fundamentalHz)
        sink.field("excitation"); sink.double(value.excitation)
        sink.field("damping"); sink.double(value.damping)
        sink.field("brightness"); sink.double(value.brightness)
        sink.field("inharmonicity"); sink.double(value.inharmonicity)
        sink.field("eventIntensity"); sink.double(value.eventIntensity)
        sink.field("seed"); sink.uint64(value.seed)
        sink.field("material"); sink.raw(value.material.rawValue)
        sink.field("coupling"); sink.double(value.coupling)
    }

    static func encode(_ value: SpatialContrastArticulation, into sink: inout StreamingFNV1a) {
        sink.aggregate("SpatialContrastArticulation")
        sink.field("depthPosition"); sink.raw(value.depthPosition.rawValue)
        sink.field("carrierVoice"); sink.presence(value.carrierVoice != nil)
        if let voice = value.carrierVoice { sink.raw(voice.rawValue) }
        sink.field("carrierStep"); sink.presence(value.carrierStep != nil)
        if let step = value.carrierStep { sink.int(step) }
        sink.field("dryScale"); sink.double(value.dryScale)
        sink.field("reverbSend"); sink.double(value.reverbSend)
        sink.field("highPassHz"); sink.double(value.highPassHz)
        sink.field("lowPassHz"); sink.double(value.lowPassHz)
    }

    static func encode(_ value: NarrativeArticulation, into sink: inout StreamingFNV1a) {
        sink.aggregate("NarrativeArticulation")
        sink.field("direction"); sink.raw(value.direction.rawValue)
        sink.field("presenceStart"); sink.double(value.presenceStart)
        sink.field("presenceEnd"); sink.double(value.presenceEnd)
        sink.field("activeSupportingRoles")
        sink.collection(value.activeSupportingRoles.count)
        for role in value.activeSupportingRoles { sink.raw(role.rawValue) }
    }

    static func encode(_ value: SessionDramaticDebt, into sink: inout StreamingFNV1a) {
        sink.aggregate("SessionDramaticDebt")
        sink.field("id"); sink.int(value.id)
        sink.field("openedAtBar"); sink.int(value.openedAtBar)
        sink.field("dueByBar"); sink.int(value.dueByBar)
        sink.field("source"); sink.raw(value.source.rawValue)
    }

    static func encode(_ value: PhraseInterestReport, into sink: inout StreamingFNV1a) {
        sink.aggregate("PhraseInterestReport")
        sink.field("pulseClarity"); sink.double(value.pulseClarity)
        sink.field("intentionalSpace"); sink.double(value.intentionalSpace)
        sink.field("responseClosure"); sink.double(value.responseClosure)
        sink.field("structuralTimeliness"); sink.double(value.structuralTimeliness)
        sink.field("identityContinuity"); sink.double(value.identityContinuity)
        sink.field("weakPositionCoverage"); sink.double(value.weakPositionCoverage)
        sink.field("trailingSideRelationship"); sink.double(value.trailingSideRelationship)
        sink.field("overactivityPenalty"); sink.double(value.overactivityPenalty)
        sink.field("overdueDebtCount"); sink.int(value.overdueDebtCount)
        sink.field("score"); sink.double(value.score)
        sink.field("valid"); sink.bool(value.valid)
    }

    static func encode(_ value: PerformanceCharacterEvidence,
                       into sink: inout StreamingFNV1a) {
        sink.aggregate("PerformanceCharacterEvidence")
        sink.field("character"); sink.raw(value.character.rawValue)
        sink.field("totalBars"); sink.int(value.totalBars)
        sink.field("compatibleFoundationBars"); sink.int(value.compatibleFoundationBars)
        sink.field("compatibleRoleBars"); sink.int(value.compatibleRoleBars)
        sink.field("characteristicRhythmBars"); sink.int(value.characteristicRhythmBars)
        sink.field("valid"); sink.bool(value.valid)
    }

    static func encode(_ value: InterlockEvolutionState, into sink: inout StreamingFNV1a) {
        sink.aggregate("InterlockEvolutionState")
        sink.field("currentChapter"); sink.raw(value.currentChapter.rawValue)
        sink.field("previousChapters"); sink.collection(value.previousChapters.count)
        for chapter in value.previousChapters { sink.raw(chapter.rawValue) }
        sink.field("macroIndex"); sink.int(value.macroIndex)
        sink.field("macrosSinceHome"); sink.int(value.macrosSinceHome)
    }

    static func encode(_ value: SpatialContrastState, into sink: inout StreamingFNV1a) {
        sink.aggregate("SpatialContrastState")
        sink.field("previousCarrierVoice"); sink.presence(value.previousCarrierVoice != nil)
        if let voice = value.previousCarrierVoice { sink.raw(voice.rawValue) }
        sink.field("lastCarrierMacroIndex"); sink.presence(value.lastCarrierMacroIndex != nil)
        if let index = value.lastCarrierMacroIndex { sink.int(index) }
    }

    static func encode(_ value: NarrativeEvolutionState, into sink: inout StreamingFNV1a) {
        sink.aggregate("NarrativeEvolutionState")
        sink.field("protagonistPresence"); sink.double(value.protagonistPresence)
        sink.field("activeSupportingRoles")
        sink.collection(value.activeSupportingRoles.count)
        for role in value.activeSupportingRoles { sink.raw(role.rawValue) }
        sink.field("releaseSettlementPending"); sink.bool(value.releaseSettlementPending)
    }

    // MARK: Canonical session continuation

    static func encode(
        _ value: AutonomousSessionState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("AutonomousSessionState")
        sink.field("rootSeed"); sink.uint64(value.rootSeed)
        sink.field("identitySeed"); sink.uint64(value.identitySeed)
        sink.field("identityDNA"); encode(value.identityDNA, into: &sink)
        sink.field("phraseIndex"); sink.int(value.phraseIndex)
        sink.field("intent"); encode(value.intent, into: &sink)
        sink.field("memory")
        encode(value.memory, into: &sink)
        sink.field("quality"); encode(value.quality, into: &sink)
        sink.field("liveMasterHeadroomFingerprint")
        sink.string(value.liveMasterHeadroom.fingerprint)
    }

    static func encode(
        _ value: TemporalMusicalMemory,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("TemporalMusicalMemory")
        sink.field("recentBars"); encode(value.recentBars, into: &sink)
        sink.field("currentPhrase"); encode(value.currentPhrase, into: &sink)
        sink.field("previousPhrase"); encode(value.previousPhrase, into: &sink)
        sink.field("dramaticArc"); encode(value.dramaticArc, into: &sink)
        sink.field("sessionBars"); encode(value.sessionBars, into: &sink)
        sink.field("totalBars"); sink.int(value.totalBars)
        sink.field("lastContrastBar"); encode(value.lastContrastBar, into: &sink)
        sink.field("lastBreakBar"); encode(value.lastBreakBar, into: &sink)
        sink.field("lastReleaseBar"); encode(value.lastReleaseBar, into: &sink)
        sink.field("lastIdentityReturnBar")
        encode(value.lastIdentityReturnBar, into: &sink)
        sink.field("topologyRevision"); sink.int(value.topologyRevision)
        sink.field("openDebts"); sink.collection(value.openDebts.count)
        for debt in value.openDebts { encode(debt, into: &sink) }
        sink.field("interlockEvolution")
        encode(value.interlockEvolution, into: &sink)
        sink.field("spatialContrast"); encode(value.spatialContrast, into: &sink)
        sink.field("narrativeEvolution")
        encode(value.narrativeEvolution, into: &sink)
        sink.field("recentPerformanceCharacters")
        sink.collection(value.recentPerformanceCharacters.count)
        for character in value.recentPerformanceCharacters {
            sink.raw(character.rawValue)
        }
        sink.field("harmonicContinuation")
        encode(value.harmonicContinuation, into: &sink)
        sink.field("resampledMemory")
        encode(value.resampledMemory, into: &sink)
        sink.field("longHorizon")
        encode(value.longHorizon, into: &sink)
    }

    static func encode(
        _ value: LongHorizonContinuationState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonContinuationState")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("schemaIdentifier"); sink.string(value.schemaIdentifier)
        sink.field("isBound"); sink.bool(value.isBound)
        sink.field("rootSeed"); sink.uint64(value.rootSeed)
        sink.field("nextExpectedPhraseIndex")
        sink.int(value.nextExpectedPhraseIndex)
        sink.field("nextExpectedBar"); sink.int(value.nextExpectedBar)
        sink.field("nextExpectedPresentationBar")
        sink.int(value.nextExpectedPresentationBar)
        sink.field("arcIndex"); sink.int(value.arcIndex)
        sink.field("arcEpisodeCount"); sink.int(value.arcEpisodeCount)
        sink.field("currentEpisode"); encode(value.currentEpisode, into: &sink)
        sink.field("effectCarrierState")
        encode(value.effectCarrierState, into: &sink)
        sink.field("lastSemanticEnergy")
        encode(value.lastSemanticEnergy, into: &sink)
        sink.field("recentEpisodes")
        sink.collection(value.recentEpisodes.count)
        for episode in value.recentEpisodes { encode(episode, into: &sink) }
        sink.field("recentOperators")
        sink.collection(value.recentOperators.count)
        for operatorKind in value.recentOperators {
            sink.raw(operatorKind.rawValue)
        }
        sink.field("capabilityRecency")
        encodeLongHorizonRecency(value.capabilityRecency, into: &sink)
        sink.field("characterRecency")
        encodeLongHorizonRecency(value.characterRecency, into: &sink)
        sink.field("harmonicRecency")
        encodeLongHorizonRecency(value.harmonicRecency, into: &sink)
        sink.field("transformationRecency")
        encodeLongHorizonRecency(value.transformationRecency, into: &sink)
        sink.field("identityLandmarks")
        sink.collection(value.identityLandmarks.count)
        for landmark in value.identityLandmarks { encode(landmark, into: &sink) }
        sink.field("obligations")
        sink.collection(value.obligations.count)
        for obligation in value.obligations { encode(obligation, into: &sink) }
        sink.field("reserve"); encode(value.reserve, into: &sink)
        sink.field("lastTrajectoryEvidenceSchema")
        encode(value.lastTrajectoryEvidenceSchema, into: &sink)
        sink.field("lastTrajectoryDecisionReason")
        sink.string(value.lastTrajectoryDecisionReason)
        sink.field("lastTrajectoryDecision")
        sink.presence(value.lastTrajectoryDecision != nil)
        if let decision = value.lastTrajectoryDecision {
            encode(decision, into: &sink)
        }
        sink.field("trajectoryCorrectionCount")
        sink.int(value.trajectoryCorrectionCount)
    }

    static func encode(
        _ value: LongHorizonEpisodeIntent,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonEpisodeIntent")
        sink.field("id"); sink.uint64(value.id)
        sink.field("arcIndex"); sink.int(value.arcIndex)
        sink.field("episodeIndex"); sink.int(value.episodeIndex)
        sink.field("operatorKind"); sink.raw(value.operatorKind.rawValue)
        sink.field("startedAtBar"); sink.int(value.startedAtBar)
        sink.field("minimumHoldUntilBar")
        sink.int(value.minimumHoldUntilBar)
        sink.field("dueByBar"); sink.int(value.dueByBar)
        sink.field("startEnergy"); encode(value.startEnergy, into: &sink)
        sink.field("target"); encode(value.target, into: &sink)
        sink.field("materialWorld"); encode(value.materialWorld, into: &sink)
    }

    static func encode(
        _ value: LongHorizonCompletedEpisode,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonCompletedEpisode")
        sink.field("id"); sink.uint64(value.id)
        sink.field("arcIndex"); sink.int(value.arcIndex)
        sink.field("episodeIndex"); sink.int(value.episodeIndex)
        sink.field("operatorKind"); sink.raw(value.operatorKind.rawValue)
        sink.field("startedAtBar"); sink.int(value.startedAtBar)
        sink.field("completedAtBar"); sink.int(value.completedAtBar)
        sink.field("minimumHoldUntilBar")
        sink.int(value.minimumHoldUntilBar)
        sink.field("dueByBar"); sink.int(value.dueByBar)
        sink.field("completionReason")
        sink.raw(value.completionReason.rawValue)
        sink.field("materialWorld"); encode(value.materialWorld, into: &sink)
    }

    static func encode(
        _ value: LongHorizonSemanticEnergyVector,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonSemanticEnergyVector")
        sink.field("foundationAuthority")
        sink.double(value.foundationAuthority)
        sink.field("roleDensity"); sink.double(value.roleDensity)
        sink.field("percussionActivity")
        sink.double(value.percussionActivity)
        sink.field("protagonistPresence")
        sink.double(value.protagonistPresence)
        sink.field("harmonicDisclosure")
        sink.double(value.harmonicDisclosure)
        sink.field("timbralMotionIntent")
        sink.double(value.timbralMotionIntent)
        sink.field("spatialDistance"); sink.double(value.spatialDistance)
        sink.field("transitionExpectation")
        sink.double(value.transitionExpectation)
    }

    static func encode(
        _ value: LongHorizonEnergyTarget,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonEnergyTarget")
        sink.field("foundationAuthority")
        sink.raw(value.foundationAuthority.rawValue)
        sink.field("roleDensity"); sink.raw(value.roleDensity.rawValue)
        sink.field("percussionActivity")
        sink.raw(value.percussionActivity.rawValue)
        sink.field("protagonistPresence")
        sink.raw(value.protagonistPresence.rawValue)
        sink.field("harmonicDisclosure")
        sink.raw(value.harmonicDisclosure.rawValue)
        sink.field("timbralMotionIntent")
        sink.raw(value.timbralMotionIntent.rawValue)
        sink.field("spatialDistance")
        sink.raw(value.spatialDistance.rawValue)
        sink.field("transitionExpectation")
        sink.raw(value.transitionExpectation.rawValue)
    }

    static func encode(
        _ value: LongHorizonMaterialWorldIntent,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonMaterialWorldIntent")
        sink.field("id"); sink.uint64(value.id)
        sink.field("parentID"); sink.presence(value.parentID != nil)
        if let parentID = value.parentID { sink.uint64(parentID) }
        sink.field("parentFingerprint")
        encode(value.parentFingerprint, into: &sink)
        sink.field("parentAxes"); sink.presence(value.parentAxes != nil)
        if let parentAxes = value.parentAxes { encode(parentAxes, into: &sink) }
        sink.field("generation"); sink.int(value.generation)
        sink.field("retryOrdinal"); sink.int(value.retryOrdinal)
        sink.field("handoff"); sink.raw(value.handoff.rawValue)
        sink.field("axes"); encode(value.axes, into: &sink)
        sink.field("polymetricGrammar")
        encode(value.polymetricGrammar, into: &sink)
        sink.field("fingerprint"); sink.string(value.fingerprint)
    }

    static func encode(
        _ value: LongHorizonMaterialAxes,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonMaterialAxes")
        sink.field("rhythm"); sink.raw(value.rhythm.rawValue)
        sink.field("motif"); sink.raw(value.motif.rawValue)
        sink.field("roles"); sink.raw(value.roles.rawValue)
        sink.field("harmony"); sink.raw(value.harmony.rawValue)
        sink.field("architecture"); sink.raw(value.architecture.rawValue)
        sink.field("effect"); encode(value.effect, into: &sink)
    }

    static func encode(
        _ value: LongHorizonPolymetricGrammar,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonPolymetricGrammar")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("schemaIdentifier"); sink.string(value.schemaIdentifier)
        sink.field("isEnabled"); sink.bool(value.isEnabled)
        sink.field("activationBar"); sink.int(value.activationBar)
        sink.field("laneGeometries")
        sink.collection(value.laneGeometries.count)
        for geometry in value.laneGeometries {
            sink.aggregate("LongHorizonPolymetricLaneGeometry")
            sink.field("lane"); sink.raw(geometry.lane.rawValue)
            sink.field("stepLength"); sink.int(geometry.stepLength)
            sink.field("pulseCount"); sink.int(geometry.pulseCount)
            sink.field("rotation"); sink.int(geometry.rotation)
        }
        sink.field("combinedPeriodInSteps")
        sink.int(value.combinedPeriodInSteps)
        sink.field("fingerprint"); sink.string(value.fingerprint)
    }

    static func encode(
        _ value: LongHorizonEffectCarrierState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonEffectCarrierState")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("schemaIdentifier"); sink.string(value.schemaIdentifier)
        sink.field("worldID"); sink.uint64(value.worldID)
        sink.field("status"); sink.raw(value.status.rawValue)
        sink.field("role"); sink.presence(value.role != nil)
        if let role = value.role { sink.raw(role.rawValue) }
        sink.field("selectedAtPhraseIndex")
        encode(value.selectedAtPhraseIndex, into: &sink)
    }

    static func encodeLongHorizonRecency(
        _ values: [LongHorizonNamedUseRecency],
        into sink: inout StreamingFNV1a
    ) {
        sink.collection(values.count)
        for value in values {
            sink.aggregate("LongHorizonNamedUseRecency")
            sink.field("name"); sink.string(value.name)
            sink.field("useCount"); sink.int(value.useCount)
            sink.field("lastUsedBar"); encode(value.lastUsedBar, into: &sink)
        }
    }

    static func encode(
        _ value: LongHorizonIdentityLandmarkSummary,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonIdentityLandmarkSummary")
        sink.field("scoreFingerprint")
        sink.uint64(value.scoreFingerprint)
        sink.field("establishedAtBar"); sink.int(value.establishedAtBar)
        sink.field("lastRecalledAtBar")
        encode(value.lastRecalledAtBar, into: &sink)
    }

    static func encode(
        _ value: LongHorizonObligation,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonObligation")
        sink.field("id"); sink.uint64(value.id)
        sink.field("kind"); sink.raw(value.kind.rawValue)
        sink.field("openedAtBar"); sink.int(value.openedAtBar)
        sink.field("dueByBar"); sink.int(value.dueByBar)
        sink.field("sourceEpisodeID"); sink.uint64(value.sourceEpisodeID)
        sink.field("sourceScoreFingerprint")
        sink.uint64(value.sourceScoreFingerprint)
    }

    static func encode(
        _ value: LongHorizonReserveState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonReserveState")
        sink.field("payoffAvailable"); sink.bool(value.payoffAvailable)
        sink.field("reframeAvailable"); sink.bool(value.reframeAvailable)
        sink.field("recallAvailable"); sink.bool(value.recallAvailable)
    }

    static func encode(
        _ value: LongHorizonTrajectoryDecision,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LongHorizonTrajectoryDecision")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("schemaIdentifier"); sink.string(value.schemaIdentifier)
        sink.field("rootSeed"); sink.uint64(value.rootSeed)
        sink.field("policyVersion"); sink.string(value.policyVersion)
        sink.field("evidenceSchema"); sink.string(value.evidenceSchema)
        sink.field("evidenceFingerprint")
        sink.string(value.evidenceFingerprint)
        sink.field("observedThroughPhraseIndex")
        sink.int(value.observedThroughPhraseIndex)
        sink.field("observedThroughBar")
        sink.int(value.observedThroughBar)
        sink.field("targetPhraseIndex"); sink.int(value.targetPhraseIndex)
        sink.field("targetBar"); sink.int(value.targetBar)
        sink.field("action"); sink.raw(value.action.rawValue)
        sink.field("reasons"); sink.collection(value.reasons.count)
        for reason in value.reasons { sink.raw(reason.rawValue) }
        sink.field("fingerprint"); sink.string(value.fingerprint)
    }

    static func encode(
        _ values: [MusicalMemoryBar],
        into sink: inout StreamingFNV1a
    ) {
        sink.collection(values.count)
        for value in values { encode(value, into: &sink) }
    }

    static func encode(
        _ value: MusicalMemoryBar,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("MusicalMemoryBar")
        sink.field("absoluteBar"); sink.int(value.absoluteBar)
        sink.field("phraseIndex"); sink.int(value.phraseIndex)
        sink.field("section"); sink.raw(value.section.rawValue)
        sink.field("tension"); sink.double(value.tension)
        sink.field("roles"); sink.collection(value.roles.count)
        for role in value.roles { sink.raw(role.rawValue) }
        sink.field("transformations")
        sink.collection(value.transformations.count)
        for transformation in value.transformations {
            sink.raw(transformation.rawValue)
        }
        sink.field("eventSignature"); sink.uint64(value.eventSignature)
        sink.field("activity"); sink.double(value.activity)
        sink.field("repetition"); sink.double(value.repetition)
        sink.field("density"); sink.double(value.density)
    }

    static func encode(
        _ value: HarmonicContinuationState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("HarmonicContinuationState")
        sink.field("voices"); sink.collection(value.voices.count)
        for voice in value.voices {
            sink.aggregate("PadVoice")
            sink.field("modalDegree"); sink.int(voice.modalDegree)
            sink.field("semitone"); sink.int(voice.semitone)
            sink.field("frequencyRatio"); sink.double(voice.frequencyRatio)
        }
    }

    static func encode(_ value: Int?, into sink: inout StreamingFNV1a) {
        sink.presence(value != nil)
        if let value { sink.int(value) }
    }

    // MARK: Generated graph

    static func encode(_ value: DSPGraphPlan, into sink: inout StreamingFNV1a) {
        sink.aggregate("DSPGraphPlan")
        sink.field("sessionSeed"); sink.uint64(value.sessionSeed)
        sink.field("revision"); sink.int(value.revision)
        sink.field("nodes"); sink.collection(value.nodes.count)
        for node in value.nodes { encode(node, into: &sink) }
        sink.field("mutation"); sink.presence(value.mutation != nil)
        if let mutation = value.mutation { encode(mutation, into: &sink) }
        sink.field("lowEndProtected"); sink.bool(value.lowEndProtected)
        sink.field("protectedRouting"); encode(value.protectedRouting, into: &sink)
        sink.field("materialWorldFingerprint")
        sink.raw(value.materialWorldFingerprint)
        sink.field("effectWorldTarget")
        encode(value.effectWorldTarget, into: &sink)
    }

    static func encode(_ value: EffectWorldTarget, into sink: inout StreamingFNV1a) {
        sink.aggregate("EffectWorldTarget")
        sink.field("spectralFocus"); sink.double(value.spectralFocus)
        sink.field("nonlinearPressure"); sink.double(value.nonlinearPressure)
        sink.field("modulationMotion"); sink.double(value.modulationMotion)
        sink.field("echoMemory"); sink.double(value.echoMemory)
        sink.field("spatialDepth"); sink.double(value.spatialDepth)
    }

    static func encode(_ value: DSPGraphNode, into sink: inout StreamingFNV1a) {
        sink.aggregate("DSPGraphNode")
        sink.field("id"); sink.int(value.id)
        sink.field("kind"); sink.raw(value.kind.rawValue)
        sink.field("branch"); sink.int(value.branch)
        sink.field("order"); sink.int(value.order)
        sink.field("amount"); sink.double(value.amount)
        sink.field("mix"); sink.double(value.mix)
        sink.field("feedback"); sink.double(value.feedback)
        sink.field("delaySeconds"); sink.double(value.delaySeconds)
    }

    static func encode(_ value: DSPGraphMutation, into sink: inout StreamingFNV1a) {
        sink.aggregate("DSPGraphMutation")
        sink.field("kind"); sink.raw(value.kind.rawValue)
        sink.field("phraseIndex"); sink.int(value.phraseIndex)
        sink.field("affectedNodeIDs"); sink.collection(value.affectedNodeIDs.count)
        for id in value.affectedNodeIDs { sink.int(id) }
    }

    static func encode(_ value: DSPProtectedRouting, into sink: inout StreamingFNV1a) {
        sink.aggregate("DSPProtectedRouting")
        sink.field("kick"); sink.bool(value.kick)
        sink.field("subAndBass"); sink.bool(value.subAndBass)
        sink.field("maskingProtection"); sink.bool(value.maskingProtection)
        sink.field("glue"); sink.bool(value.glue)
        sink.field("limiter"); sink.bool(value.limiter)
        sink.field("output"); sink.bool(value.output)
    }

    // MARK: Render continuation

    static func encode(_ value: RenderState, into sink: inout StreamingFNV1a) {
        sink.aggregate("RenderState")
        sink.field("barIndex"); sink.int(value.barIndex)
        sink.field("delayBuffer"); encode(value.delayBuffer, into: &sink)
        sink.field("delayWriteIndex"); sink.int(value.delayWriteIndex)
        sink.field("pulseEchoBuffer"); encode(value.pulseEchoBuffer, into: &sink)
        sink.field("pulseEchoWriteIndex"); sink.int(value.pulseEchoWriteIndex)
        sink.field("pulseEchoHighPassState"); sink.double(value.pulseEchoHighPassState)
        sink.field("pulseEchoLowPassState"); sink.double(value.pulseEchoLowPassState)
        sink.field("earlyReflectionBuffer"); encode(value.earlyReflectionBuffer, into: &sink)
        sink.field("earlyReflectionWriteIndex"); sink.int(value.earlyReflectionWriteIndex)
        sink.field("stereoPanPhase"); sink.double(value.stereoPanPhase)
        sink.field("chorusDelay"); encode(value.chorusDelay, into: &sink)
        sink.field("chorusWriteIndex"); sink.int(value.chorusWriteIndex)
        sink.field("chorusPhase"); sink.double(value.chorusPhase)
        sink.field("masterEnvelope"); sink.double(value.masterEnvelope)
        sink.field("lowBandEnvelope"); sink.double(value.lowBandEnvelope)
        sink.field("highBandEnvelope"); sink.double(value.highBandEnvelope)
        sink.field("automaticMixState"); encode(value.automaticMixState, into: &sink)
        // The all-zero home state is the pre-feature semantic identity. Only a
        // committed live transition appends new provenance to that identity.
        if value.liveMasterHeadroomState != LiveMasterHeadroomContinuationState() {
            sink.field("liveMasterHeadroomState")
            encode(value.liveMasterHeadroomState, into: &sink)
        }
        sink.field("spatialFDNState")
        encode(value.spatialFDNState, into: &sink)
        sink.field("spatialSendHighPassState")
        sink.double(value.spatialSendHighPassState)
        sink.field("spatialSendLowPassState")
        sink.double(value.spatialSendLowPassState)
        sink.field("modalPercussionState")
        encode(value.modalPercussionState, into: &sink)
        sink.field("resonantFoundationState")
        encode(value.resonantFoundationState, into: &sink)
        sink.field("resonantAnchorState"); encode(value.resonantAnchorState, into: &sink)
        sink.field("resonantShadowState"); encode(value.resonantShadowState, into: &sink)
        sink.field("resonantResponseState"); encode(value.resonantResponseState, into: &sink)
        sink.field("alienAnchorState"); encode(value.alienAnchorState, into: &sink)
        sink.field("alienShadowState"); encode(value.alienShadowState, into: &sink)
        sink.field("alienAtmosphereState"); encode(value.alienAtmosphereState, into: &sink)
        sink.field("alienResponseState"); encode(value.alienResponseState, into: &sink)
        sink.field("alienTransitionState"); encode(value.alienTransitionState, into: &sink)
        sink.field("spectralResponseState"); encode(value.spectralResponseState, into: &sink)
        sink.field("spectralAtmosphereState")
        encode(value.spectralAtmosphereState, into: &sink)
        sink.field("spectralTransitionState")
        encode(value.spectralTransitionState, into: &sink)
        sink.field("polyphonicPadState")
        encode(value.polyphonicPadState, into: &sink)
        sink.field("previousResonantAnchorEvidenceFrame")
        encode(value.previousResonantAnchorEvidenceFrame, into: &sink)
        sink.field("previousDetunedCompanionEvidenceFrame")
        encode(value.previousDetunedCompanionEvidenceFrame, into: &sink)
        sink.field("previousGraphInputRemainderEvidenceFrame")
        encode(value.previousGraphInputRemainderEvidenceFrame, into: &sink)
        sink.field("previousPostGraphRemainderEvidenceFrame")
        encode(value.previousPostGraphRemainderEvidenceFrame, into: &sink)
        sink.field("outputTransitionState")
        encode(value.outputTransitionState, into: &sink)
    }

    static func encode(
        _ value: FeedbackDelayNetworkState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("FeedbackDelayNetworkState")
        sink.field("storage"); encode(value.storage, into: &sink)
        sink.field("lineOffsets"); sink.collection(value.lineOffsets.count)
        for offset in value.lineOffsets { sink.int(offset) }
        sink.field("lineLengths"); sink.collection(value.lineLengths.count)
        for length in value.lineLengths { sink.int(length) }
        sink.field("writeIndices"); sink.collection(value.writeIndices.count)
        for index in value.writeIndices { sink.int(index) }
        sink.field("dampingStates")
        sink.collection(value.dampingStates.count)
        for state in value.dampingStates { sink.double(state) }
        sink.field("routeSampleRate"); sink.double(value.routeSampleRate)
        sink.field("geometryRoomScale"); sink.double(value.geometryRoomScale)
        sink.field("appliedFeedbackGains")
        sink.collection(value.appliedFeedbackGains.count)
        for gain in value.appliedFeedbackGains { sink.double(gain) }
        sink.field("targetFeedbackGains")
        sink.collection(value.targetFeedbackGains.count)
        for gain in value.targetFeedbackGains { sink.double(gain) }
        sink.field("feedbackGainSteps")
        sink.collection(value.feedbackGainSteps.count)
        for step in value.feedbackGainSteps { sink.double(step) }
        sink.field("appliedDampingCoefficient")
        sink.double(value.appliedDampingCoefficient)
        sink.field("targetDampingCoefficient")
        sink.double(value.targetDampingCoefficient)
        sink.field("dampingCoefficientStep")
        sink.double(value.dampingCoefficientStep)
        sink.field("appliedSynthSendGain")
        sink.double(value.appliedSynthSendGain)
        sink.field("targetSynthSendGain")
        sink.double(value.targetSynthSendGain)
        sink.field("synthSendGainStep"); sink.double(value.synthSendGainStep)
        sink.field("appliedPercussionSendGain")
        sink.double(value.appliedPercussionSendGain)
        sink.field("targetPercussionSendGain")
        sink.double(value.targetPercussionSendGain)
        sink.field("percussionSendGainStep")
        sink.double(value.percussionSendGainStep)
        sink.field("appliedWetGain"); sink.double(value.appliedWetGain)
        sink.field("targetWetGain"); sink.double(value.targetWetGain)
        sink.field("wetGainStep"); sink.double(value.wetGainStep)
        sink.field("parameterTransitionRemainingFrames")
        sink.int(value.parameterTransitionRemainingFrames)
    }

    static func encode(
        _ value: RenderState,
        into sink: inout StreamingFNV1a,
        cancellationRequested: @Sendable () -> Bool
    ) -> Bool {
        guard !cancellationRequested() else { return false }
        sink.aggregate("RenderState")
        sink.field("barIndex"); sink.int(value.barIndex)
        sink.field("delayBuffer")
        guard encode(
            value.delayBuffer,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("delayWriteIndex"); sink.int(value.delayWriteIndex)
        sink.field("pulseEchoBuffer")
        guard encode(
            value.pulseEchoBuffer,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("pulseEchoWriteIndex"); sink.int(value.pulseEchoWriteIndex)
        sink.field("pulseEchoHighPassState"); sink.double(value.pulseEchoHighPassState)
        sink.field("pulseEchoLowPassState"); sink.double(value.pulseEchoLowPassState)
        sink.field("earlyReflectionBuffer")
        guard encode(
            value.earlyReflectionBuffer,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("earlyReflectionWriteIndex"); sink.int(value.earlyReflectionWriteIndex)
        sink.field("stereoPanPhase"); sink.double(value.stereoPanPhase)
        sink.field("chorusDelay")
        guard encode(
            value.chorusDelay,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("chorusWriteIndex"); sink.int(value.chorusWriteIndex)
        sink.field("chorusPhase"); sink.double(value.chorusPhase)
        sink.field("masterEnvelope"); sink.double(value.masterEnvelope)
        sink.field("lowBandEnvelope"); sink.double(value.lowBandEnvelope)
        sink.field("highBandEnvelope"); sink.double(value.highBandEnvelope)
        sink.field("automaticMixState"); encode(value.automaticMixState, into: &sink)
        // Match the normal path's canonical home-state omission exactly.
        if value.liveMasterHeadroomState != LiveMasterHeadroomContinuationState() {
            sink.field("liveMasterHeadroomState")
            encode(value.liveMasterHeadroomState, into: &sink)
        }
        sink.field("spatialFDNState")
        guard encode(
            value.spatialFDNState.storage,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("spatialFDNLineOffsets")
        sink.collection(value.spatialFDNState.lineOffsets.count)
        for offset in value.spatialFDNState.lineOffsets { sink.int(offset) }
        sink.field("spatialFDNLineLengths")
        sink.collection(value.spatialFDNState.lineLengths.count)
        for length in value.spatialFDNState.lineLengths { sink.int(length) }
        sink.field("spatialFDNWriteIndices")
        sink.collection(value.spatialFDNState.writeIndices.count)
        for index in value.spatialFDNState.writeIndices { sink.int(index) }
        sink.field("spatialFDNDampingStates")
        sink.collection(value.spatialFDNState.dampingStates.count)
        for state in value.spatialFDNState.dampingStates { sink.double(state) }
        sink.field("spatialFDNRouteSampleRate")
        sink.double(value.spatialFDNState.routeSampleRate)
        sink.field("spatialFDNGeometryRoomScale")
        sink.double(value.spatialFDNState.geometryRoomScale)
        sink.field("spatialFDNAppliedFeedbackGains")
        sink.collection(value.spatialFDNState.appliedFeedbackGains.count)
        for gain in value.spatialFDNState.appliedFeedbackGains {
            sink.double(gain)
        }
        sink.field("spatialFDNTargetFeedbackGains")
        sink.collection(value.spatialFDNState.targetFeedbackGains.count)
        for gain in value.spatialFDNState.targetFeedbackGains {
            sink.double(gain)
        }
        sink.field("spatialFDNFeedbackGainSteps")
        sink.collection(value.spatialFDNState.feedbackGainSteps.count)
        for step in value.spatialFDNState.feedbackGainSteps {
            sink.double(step)
        }
        sink.field("spatialFDNAppliedDampingCoefficient")
        sink.double(value.spatialFDNState.appliedDampingCoefficient)
        sink.field("spatialFDNTargetDampingCoefficient")
        sink.double(value.spatialFDNState.targetDampingCoefficient)
        sink.field("spatialFDNDampingCoefficientStep")
        sink.double(value.spatialFDNState.dampingCoefficientStep)
        sink.field("spatialFDNAppliedSynthSendGain")
        sink.double(value.spatialFDNState.appliedSynthSendGain)
        sink.field("spatialFDNTargetSynthSendGain")
        sink.double(value.spatialFDNState.targetSynthSendGain)
        sink.field("spatialFDNSynthSendGainStep")
        sink.double(value.spatialFDNState.synthSendGainStep)
        sink.field("spatialFDNAppliedPercussionSendGain")
        sink.double(value.spatialFDNState.appliedPercussionSendGain)
        sink.field("spatialFDNTargetPercussionSendGain")
        sink.double(value.spatialFDNState.targetPercussionSendGain)
        sink.field("spatialFDNPercussionSendGainStep")
        sink.double(value.spatialFDNState.percussionSendGainStep)
        sink.field("spatialFDNAppliedWetGain")
        sink.double(value.spatialFDNState.appliedWetGain)
        sink.field("spatialFDNTargetWetGain")
        sink.double(value.spatialFDNState.targetWetGain)
        sink.field("spatialFDNWetGainStep")
        sink.double(value.spatialFDNState.wetGainStep)
        sink.field("spatialFDNParameterTransitionRemainingFrames")
        sink.int(value.spatialFDNState.parameterTransitionRemainingFrames)
        sink.field("spatialSendHighPassState")
        sink.double(value.spatialSendHighPassState)
        sink.field("spatialSendLowPassState")
        sink.double(value.spatialSendLowPassState)
        sink.field("modalPercussionState")
        encode(value.modalPercussionState, into: &sink)
        sink.field("resonantFoundationState")
        encode(value.resonantFoundationState, into: &sink)
        sink.field("resonantAnchorState"); encode(value.resonantAnchorState, into: &sink)
        sink.field("resonantShadowState"); encode(value.resonantShadowState, into: &sink)
        sink.field("resonantResponseState"); encode(value.resonantResponseState, into: &sink)
        sink.field("alienAnchorState")
        guard encode(
            value.alienAnchorState,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("alienShadowState")
        guard encode(
            value.alienShadowState,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("alienAtmosphereState")
        guard encode(
            value.alienAtmosphereState,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("alienResponseState")
        guard encode(
            value.alienResponseState,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("alienTransitionState")
        guard encode(
            value.alienTransitionState,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("spectralResponseState"); encode(value.spectralResponseState, into: &sink)
        sink.field("spectralAtmosphereState")
        encode(value.spectralAtmosphereState, into: &sink)
        sink.field("spectralTransitionState")
        encode(value.spectralTransitionState, into: &sink)
        sink.field("polyphonicPadState")
        encode(value.polyphonicPadState, into: &sink)
        sink.field("previousResonantAnchorEvidenceFrame")
        encode(value.previousResonantAnchorEvidenceFrame, into: &sink)
        sink.field("previousDetunedCompanionEvidenceFrame")
        encode(value.previousDetunedCompanionEvidenceFrame, into: &sink)
        sink.field("previousGraphInputRemainderEvidenceFrame")
        encode(value.previousGraphInputRemainderEvidenceFrame, into: &sink)
        sink.field("previousPostGraphRemainderEvidenceFrame")
        encode(value.previousPostGraphRemainderEvidenceFrame, into: &sink)
        sink.field("outputTransitionState")
        encode(value.outputTransitionState, into: &sink)
        return true
    }

    static func encode(
        _ value: OutputTransitionContinuationState?,
        into sink: inout StreamingFNV1a
    ) {
        sink.presence(value != nil)
        guard let value else { return }
        sink.aggregate("OutputTransitionContinuationState")
        sink.field("sampleRate"); sink.double(value.sampleRate)
        sink.field("terminalLeft"); sink.float(value.terminalLeft)
        sink.field("terminalRight"); sink.float(value.terminalRight)
        sink.field("terminalOutputRMS"); sink.double(value.terminalOutputRMS)
        sink.field("terminalSpatialWetRMS")
        sink.double(value.terminalSpatialWetRMS)
        sink.field("authoredTerminalSilence")
        sink.bool(value.authoredTerminalSilence)
    }

    static func encode(
        _ value: LiveMasterHeadroomContinuationState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("LiveMasterHeadroomContinuationState")
        sink.field("schemaVersion")
        sink.int(LiveMasterHeadroomContinuationState.schemaVersion)
        sink.field("revision"); sink.int(value.revision)
        sink.field("committedTrimDB"); sink.double(value.committedTrimDB)
        sink.field("consecutiveCleanWindows")
        sink.int(value.consecutiveCleanWindows)
        sink.field("lastProposalFingerprint")
        sink.presence(value.lastProposalFingerprint != nil)
        if let lastProposalFingerprint = value.lastProposalFingerprint {
            sink.string(lastProposalFingerprint)
        }
        sink.field("lastObservationFingerprint")
        sink.presence(value.lastObservationFingerprint != nil)
        if let lastObservationFingerprint = value.lastObservationFingerprint {
            sink.string(lastObservationFingerprint)
        }
        sink.field("lastAcceptedSourcePhraseIndex")
        sink.presence(value.lastAcceptedSourcePhraseIndex != nil)
        if let lastAcceptedSourcePhraseIndex = value.lastAcceptedSourcePhraseIndex {
            sink.int(lastAcceptedSourcePhraseIndex)
        }
        sink.field("earliestEligibleFutureSample")
        sink.presence(value.earliestEligibleFutureSample != nil)
        if let earliestEligibleFutureSample = value.earliestEligibleFutureSample {
            sink.int64(earliestEligibleFutureSample)
        }
        sink.field("coreFingerprint"); sink.string(value.fingerprint)
    }

    static func encode(
        _ value: ModalPercussionVoiceState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("ModalPercussionVoiceState")
        sink.field("sampleRate"); sink.double(value.sampleRate)
        sink.field("slot0"); encode(value.slot0, into: &sink)
        sink.field("slot1"); encode(value.slot1, into: &sink)
        sink.field("slot2"); encode(value.slot2, into: &sink)
        sink.field("slot3"); encode(value.slot3, into: &sink)
    }

    static func encode(
        _ value: ModalPercussionVoiceSlotState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("ModalPercussionVoiceSlotState")
        sink.field("active"); sink.bool(value.active)
        sink.field("articulationSeed"); sink.uint64(value.articulationSeed)
        sink.field("material"); sink.raw(value.material.rawValue)
        sink.field("coupling"); sink.double(value.coupling)
        sink.field("ageFrames"); sink.int(value.ageFrames)
        sink.field("remainingFrames"); sink.int(value.remainingFrames)
        sink.field("mode0"); encode(value.mode0, into: &sink)
        sink.field("mode1"); encode(value.mode1, into: &sink)
        sink.field("mode2"); encode(value.mode2, into: &sink)
        sink.field("mode3"); encode(value.mode3, into: &sink)
        sink.field("mode4"); encode(value.mode4, into: &sink)
        sink.field("mode5"); encode(value.mode5, into: &sink)
        sink.field("mode6"); encode(value.mode6, into: &sink)
        sink.field("mode7"); encode(value.mode7, into: &sink)
    }

    static func encode(
        _ value: ModalPercussionModeState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("ModalPercussionModeState")
        sink.field("frequencyHz"); sink.double(value.frequencyHz)
        sink.field("poleRadius"); sink.double(value.poleRadius)
        sink.field("coefficient"); sink.double(value.coefficient)
        sink.field("weight"); sink.double(value.weight)
        sink.field("y1"); sink.double(value.y1)
        sink.field("y2"); sink.double(value.y2)
    }

    static func encode(_ value: [Float], into sink: inout StreamingFNV1a) {
        sink.collection(value.count)
        for sample in value { sink.float(sample) }
    }

    static func encode(
        _ value: [Float],
        into sink: inout StreamingFNV1a,
        cancellationRequested: @Sendable () -> Bool
    ) -> Bool {
        let cancellationChunkSampleCount = 1_024
        sink.collection(value.count)
        var index = 0
        while index < value.count {
            guard !cancellationRequested() else { return false }
            let chunkLength = min(cancellationChunkSampleCount, value.count - index)
            let chunkEnd = index + chunkLength
            while index < chunkEnd {
                sink.float(value[index])
                index += 1
            }
        }
        return true
    }

    static func encode(_ value: AutomaticMixState, into sink: inout StreamingFNV1a) {
        sink.aggregate("AutomaticMixState")
        sink.field("kickCorrectionDB"); sink.double(value.kickCorrectionDB)
    }

    static func encode(_ value: PolyphonicPadState, into sink: inout StreamingFNV1a) {
        sink.aggregate("PolyphonicPadState")
        sink.field("phases"); sink.collection(value.phases.count)
        for phase in value.phases { sink.double(phase) }
        sink.field("lowPass"); sink.collection(value.lowPass.count)
        for sample in value.lowPass { sink.double(sample) }
        sink.field("envelope"); sink.collection(value.envelope.count)
        for sample in value.envelope { sink.double(sample) }
    }

    static func encode(_ value: ResonantMonoState, into sink: inout StreamingFNV1a) {
        sink.aggregate("ResonantMonoState")
        sink.field("activePatch"); encode(value.activePatch, into: &sink)
        sink.field("phase"); sink.double(value.phase)
        sink.field("subPhase"); sink.double(value.subPhase)
        sink.field("nonlinearCore"); encode(value.nonlinearCore, into: &sink)
        sink.field("dcInput"); sink.double(value.dcInput)
        sink.field("dcOutput"); sink.double(value.dcOutput)
        sink.field("frequency"); sink.double(value.frequency)
        sink.field("envelope"); sink.double(value.envelope)
    }

    static func encode(
        _ value: TPTAntialiasedNonlinearCoreState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("TPTAntialiasedNonlinearCoreState")
        sink.field("inputShaper")
        encode(value.inputShaper, into: &sink)
        sink.field("filter")
        encode(value.filter, into: &sink)
        sink.field("outputShaper")
        encode(value.outputShaper, into: &sink)
    }

    static func encode(
        _ value: AntiderivativeAntialiasedTanhState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("AntiderivativeAntialiasedTanhState")
        sink.field("previousInput"); sink.double(value.previousInput)
        sink.field("hasPreviousInput"); sink.bool(value.hasPreviousInput)
    }

    static func encode(
        _ value: TPTStateVariableFilterState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("TPTStateVariableFilterState")
        sink.field("integrator1"); sink.double(value.integrator1)
        sink.field("integrator2"); sink.double(value.integrator2)
    }

    static func encode(_ value: SpectralTextureState, into sink: inout StreamingFNV1a) {
        sink.aggregate("SpectralTextureState")
        sink.field("activePatch"); encode(value.activePatch, into: &sink)
        sink.field("activePitchIdentity")
        sink.presence(value.activePitchIdentity != nil)
        if let identity = value.activePitchIdentity {
            sink.raw(identity.rawValue)
        }
        sink.field("phaseA"); sink.double(value.phaseA)
        sink.field("phaseB"); sink.double(value.phaseB)
        sink.field("phaseC"); sink.double(value.phaseC)
        sink.field("low"); sink.double(value.low)
        sink.field("band"); sink.double(value.band)
        sink.field("resonator"); sink.double(value.resonator)
        sink.field("previousResonator"); sink.double(value.previousResonator)
        sink.field("harmonicPhase"); sink.double(value.harmonicPhase)
        sink.field("harmonicLFOPhase"); sink.double(value.harmonicLFOPhase)
        sink.field("harmonicBandIntegrator")
        sink.double(value.harmonicBandIntegrator)
        sink.field("harmonicLowIntegrator")
        sink.double(value.harmonicLowIntegrator)
        sink.field("dcInput"); sink.double(value.dcInput)
        sink.field("dcOutput"); sink.double(value.dcOutput)
        sink.field("frequency"); sink.double(value.frequency)
        sink.field("noiseCursor"); sink.uint64(value.noiseCursor)
    }

    static func encode(_ value: InstrumentPatch?, into sink: inout StreamingFNV1a) {
        sink.presence(value != nil)
        if let value { sink.raw(value.rawValue) }
    }

    static func encode(_ value: InstrumentAssignment?, into sink: inout StreamingFNV1a) {
        sink.presence(value != nil)
        guard let value else { return }
        sink.aggregate("InstrumentAssignment")
        sink.field("use"); sink.raw(value.use.rawValue)
        sink.field("architecture"); sink.raw(value.architecture.rawValue)
        sink.field("patch"); sink.raw(value.patch.rawValue)
        sink.field("pitchIdentity")
        sink.raw(value.musicalPitchIdentity.rawValue)
        sink.field("color"); sink.double(value.automation.color)
        sink.field("shape"); sink.double(value.automation.shape)
        sink.field("motion"); sink.double(value.automation.motion)
        sink.field("space"); sink.double(value.automation.space)
        sink.field("effects"); sink.collection(value.effects.count)
        for effect in value.effects { sink.raw(effect.rawValue) }
    }

    static func encode(_ value: AlienVoiceState, into sink: inout StreamingFNV1a) {
        sink.aggregate("AlienVoiceState")
        sink.field("activeInstrument"); encode(value.activeInstrument, into: &sink)
        sink.field("phaseA"); sink.double(value.phaseA)
        sink.field("phaseB"); sink.double(value.phaseB)
        sink.field("modPhase"); sink.double(value.modPhase)
        sink.field("noisePhaseA"); sink.double(value.noisePhaseA)
        sink.field("noisePhaseB"); sink.double(value.noisePhaseB)
        sink.field("driftPhase"); sink.double(value.driftPhase)
        sink.field("drift"); sink.double(value.drift)
        sink.field("frequency"); sink.double(value.frequency)
        sink.field("envelope"); sink.double(value.envelope)
        sink.field("filterEnvelope"); sink.double(value.filterEnvelope)
        sink.field("timbreIntent"); encode(value.timbreIntent, into: &sink)
        sink.field("envelopeRelation"); sink.raw(value.envelopeRelation.rawValue)
        sink.field("timbreVelocity"); sink.double(value.timbreVelocity)
        sink.field("timbreTreatment"); encode(value.timbreTreatment, into: &sink)
        sink.field("velocityResponse"); encode(value.velocityResponse, into: &sink)
        sink.field("previousSource"); sink.double(value.previousSource)
        sink.field("filter1"); sink.double(value.filter1)
        sink.field("filter2"); sink.double(value.filter2)
        sink.field("filter3"); sink.double(value.filter3)
        sink.field("filter4"); sink.double(value.filter4)
        sink.field("mutationLow"); sink.double(value.mutationLow)
        sink.field("oversampleLow"); sink.double(value.oversampleLow)
        sink.field("echoLow"); sink.double(value.echoLow)
        sink.field("dcInput"); sink.double(value.dcInput)
        sink.field("dcOutput"); sink.double(value.dcOutput)
        sink.field("tailLevel"); sink.double(value.tailLevel)
        sink.field("comb"); encode(value.comb, into: &sink)
        sink.field("combIndex"); sink.int(value.combIndex)
        sink.field("allPass"); encode(value.allPass, into: &sink)
        sink.field("allPassIndex"); sink.int(value.allPassIndex)
        sink.field("echo"); encode(value.echo, into: &sink)
        sink.field("echoIndex"); sink.int(value.echoIndex)
        sink.field("effectParametersInitialized")
        sink.bool(value.effectParametersInitialized)
        sink.field("appliedCombScale"); sink.double(value.appliedCombScale)
        sink.field("targetCombScale"); sink.double(value.targetCombScale)
        sink.field("combScaleStep"); sink.double(value.combScaleStep)
        sink.field("appliedEchoScale"); sink.double(value.appliedEchoScale)
        sink.field("targetEchoScale"); sink.double(value.targetEchoScale)
        sink.field("echoScaleStep"); sink.double(value.echoScaleStep)
        sink.field("effectTransitionRemainingFrames")
        sink.int(value.effectTransitionRemainingFrames)
    }

    static func encode(
        _ value: AlienVoiceState,
        into sink: inout StreamingFNV1a,
        cancellationRequested: @Sendable () -> Bool
    ) -> Bool {
        guard !cancellationRequested() else { return false }
        sink.aggregate("AlienVoiceState")
        sink.field("activeInstrument"); encode(value.activeInstrument, into: &sink)
        sink.field("phaseA"); sink.double(value.phaseA)
        sink.field("phaseB"); sink.double(value.phaseB)
        sink.field("modPhase"); sink.double(value.modPhase)
        sink.field("noisePhaseA"); sink.double(value.noisePhaseA)
        sink.field("noisePhaseB"); sink.double(value.noisePhaseB)
        sink.field("driftPhase"); sink.double(value.driftPhase)
        sink.field("drift"); sink.double(value.drift)
        sink.field("frequency"); sink.double(value.frequency)
        sink.field("envelope"); sink.double(value.envelope)
        sink.field("filterEnvelope"); sink.double(value.filterEnvelope)
        sink.field("timbreIntent"); encode(value.timbreIntent, into: &sink)
        sink.field("envelopeRelation"); sink.raw(value.envelopeRelation.rawValue)
        sink.field("timbreVelocity"); sink.double(value.timbreVelocity)
        sink.field("timbreTreatment"); encode(value.timbreTreatment, into: &sink)
        sink.field("velocityResponse"); encode(value.velocityResponse, into: &sink)
        sink.field("previousSource"); sink.double(value.previousSource)
        sink.field("filter1"); sink.double(value.filter1)
        sink.field("filter2"); sink.double(value.filter2)
        sink.field("filter3"); sink.double(value.filter3)
        sink.field("filter4"); sink.double(value.filter4)
        sink.field("mutationLow"); sink.double(value.mutationLow)
        sink.field("oversampleLow"); sink.double(value.oversampleLow)
        sink.field("echoLow"); sink.double(value.echoLow)
        sink.field("dcInput"); sink.double(value.dcInput)
        sink.field("dcOutput"); sink.double(value.dcOutput)
        sink.field("tailLevel"); sink.double(value.tailLevel)
        sink.field("comb")
        guard encode(
            value.comb,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("combIndex"); sink.int(value.combIndex)
        sink.field("allPass")
        guard encode(
            value.allPass,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("allPassIndex"); sink.int(value.allPassIndex)
        sink.field("echo")
        guard encode(
            value.echo,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("echoIndex"); sink.int(value.echoIndex)
        sink.field("effectParametersInitialized")
        sink.bool(value.effectParametersInitialized)
        sink.field("appliedCombScale"); sink.double(value.appliedCombScale)
        sink.field("targetCombScale"); sink.double(value.targetCombScale)
        sink.field("combScaleStep"); sink.double(value.combScaleStep)
        sink.field("appliedEchoScale"); sink.double(value.appliedEchoScale)
        sink.field("targetEchoScale"); sink.double(value.targetEchoScale)
        sink.field("echoScaleStep"); sink.double(value.echoScaleStep)
        sink.field("effectTransitionRemainingFrames")
        sink.int(value.effectTransitionRemainingFrames)
        return true
    }

    static func encode(_ value: UpperTimbreIntent, into sink: inout StreamingFNV1a) {
        sink.aggregate("UpperTimbreIntent")
        sink.field("kind"); sink.raw(value.kind.rawValue)
        sink.field("amount"); sink.double(value.amount)
    }

    static func encode(_ value: AlienTimbreTreatment, into sink: inout StreamingFNV1a) {
        sink.aggregate("AlienTimbreTreatment")
        sink.field("amplitudeScale"); sink.double(value.amplitudeScale)
        sink.field("filterEnvelopeDepth"); sink.double(value.filterEnvelopeDepth)
        sink.field("filterEnvelopeDecaySeconds")
        sink.double(value.filterEnvelopeDecaySeconds)
        sink.field("driveScale"); sink.double(value.driveScale)
        sink.field("resonanceLift"); sink.double(value.resonanceLift)
        sink.field("detuneRatioLift"); sink.double(value.detuneRatioLift)
    }

    static func encode(_ value: AlienVelocityResponse, into sink: inout StreamingFNV1a) {
        sink.aggregate("AlienVelocityResponse")
        sink.field("spectralEnvelopeScale"); sink.double(value.spectralEnvelopeScale)
        sink.field("decayScale"); sink.double(value.decayScale)
    }

    static func encode(_ value: UpperTimbreStereoFrame?, into sink: inout StreamingFNV1a) {
        sink.presence(value != nil)
        if let value {
            sink.aggregate("UpperTimbreStereoFrame")
            sink.field("left"); sink.float(value.left)
            sink.field("right"); sink.float(value.right)
        }
    }

    // MARK: Generated-DSP continuation

    static func encode(
        _ value: GeneratedDSPContinuationState,
        into sink: inout StreamingFNV1a
    ) {
        sink.aggregate("GeneratedDSPContinuationState")
        sink.field("graph"); sink.presence(value.graph != nil)
        if let graph = value.graph { encode(graph, into: &sink) }
        sink.field("nodeStates"); encode(value.nodeStates, into: &sink)
        sink.field("splitLowLeft"); sink.double(value.splitLowLeft)
        sink.field("splitLowRight"); sink.double(value.splitLowRight)
        sink.field("retiringGraph"); sink.presence(value.retiringGraph != nil)
        if let graph = value.retiringGraph { encode(graph, into: &sink) }
        sink.field("retiringStates"); encode(value.retiringStates, into: &sink)
        sink.field("retiringBarsRemaining"); sink.int(value.retiringBarsRemaining)
    }

    static func encode(
        _ value: GeneratedDSPContinuationState,
        into sink: inout StreamingFNV1a,
        cancellationRequested: @Sendable () -> Bool
    ) -> Bool {
        guard !cancellationRequested() else { return false }
        sink.aggregate("GeneratedDSPContinuationState")
        sink.field("graph"); sink.presence(value.graph != nil)
        if let graph = value.graph { encode(graph, into: &sink) }
        guard !cancellationRequested() else { return false }
        sink.field("nodeStates")
        guard encode(
            value.nodeStates,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("splitLowLeft"); sink.double(value.splitLowLeft)
        sink.field("splitLowRight"); sink.double(value.splitLowRight)
        sink.field("retiringGraph"); sink.presence(value.retiringGraph != nil)
        if let graph = value.retiringGraph { encode(graph, into: &sink) }
        guard !cancellationRequested() else { return false }
        sink.field("retiringStates")
        guard encode(
            value.retiringStates,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("retiringBarsRemaining"); sink.int(value.retiringBarsRemaining)
        return true
    }

    static func encode(
        _ value: [Int: DSPGraphNodeState],
        into sink: inout StreamingFNV1a
    ) {
        let keys = value.keys.sorted()
        sink.dictionary(keys.count)
        for key in keys {
            sink.int(key)
            if let state = value[key] { encode(state, into: &sink) }
        }
    }

    static func encode(
        _ value: [Int: DSPGraphNodeState],
        into sink: inout StreamingFNV1a,
        cancellationRequested: @Sendable () -> Bool
    ) -> Bool {
        guard !cancellationRequested() else { return false }
        let keys = value.keys.sorted()
        sink.dictionary(keys.count)
        for key in keys {
            guard !cancellationRequested() else { return false }
            sink.int(key)
            if let state = value[key] {
                guard encode(
                    state,
                    into: &sink,
                    cancellationRequested: cancellationRequested
                ) else { return false }
            }
        }
        return true
    }

    static func encode(_ value: DSPGraphNodeState, into sink: inout StreamingFNV1a) {
        sink.aggregate("DSPGraphNodeState")
        sink.field("memoryLeft"); sink.double(value.memoryLeft)
        sink.field("memoryRight"); sink.double(value.memoryRight)
        sink.field("auxiliaryLeft"); sink.double(value.auxiliaryLeft)
        sink.field("auxiliaryRight"); sink.double(value.auxiliaryRight)
        sink.field("phase"); sink.double(value.phase)
        sink.field("delayLeft"); encode(value.delayLeft, into: &sink)
        sink.field("delayRight"); encode(value.delayRight, into: &sink)
        sink.field("writeIndex"); sink.int(value.writeIndex)
    }

    static func encode(
        _ value: DSPGraphNodeState,
        into sink: inout StreamingFNV1a,
        cancellationRequested: @Sendable () -> Bool
    ) -> Bool {
        guard !cancellationRequested() else { return false }
        sink.aggregate("DSPGraphNodeState")
        sink.field("memoryLeft"); sink.double(value.memoryLeft)
        sink.field("memoryRight"); sink.double(value.memoryRight)
        sink.field("auxiliaryLeft"); sink.double(value.auxiliaryLeft)
        sink.field("auxiliaryRight"); sink.double(value.auxiliaryRight)
        sink.field("phase"); sink.double(value.phase)
        sink.field("delayLeft")
        guard encode(
            value.delayLeft,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("delayRight")
        guard encode(
            value.delayRight,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("writeIndex"); sink.int(value.writeIndex)
        return true
    }

    // MARK: Quality continuation

    static func encode(_ value: QualityContinuationState, into sink: inout StreamingFNV1a) {
        sink.aggregate("QualityContinuationState")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("revision"); sink.int(value.revision)
        sink.field("policyVersion"); sink.string(value.policyVersion)
        sink.field("lastDecision"); encode(value.lastDecision, into: &sink)
        sink.field("acceptedPolicyVersion"); encode(value.acceptedPolicyVersion, into: &sink)
        sink.field("acceptedCandidateFingerprint")
        encode(value.acceptedCandidateFingerprint, into: &sink)
        sink.field("acceptedEvidenceFingerprint")
        encode(value.acceptedEvidenceFingerprint, into: &sink)
        sink.field("acceptedControllerStateFingerprint")
        encode(value.acceptedControllerStateFingerprint, into: &sink)
        sink.field("earliestEligibleFutureSample")
        encode(value.earliestEligibleFutureSample, into: &sink)
        sink.field("observedCandidateFingerprint")
        encode(value.observedCandidateFingerprint, into: &sink)
        sink.field("observedEvidenceFingerprint")
        encode(value.observedEvidenceFingerprint, into: &sink)
        sink.field("observedControllerStateFingerprint")
        encode(value.observedControllerStateFingerprint, into: &sink)
    }

    static func encode(_ value: QualityDecision, into sink: inout StreamingFNV1a) {
        sink.aggregate("QualityDecision")
        sink.field("schemaVersion"); sink.int(value.schemaVersion)
        sink.field("reasonCodeVersion"); sink.int(value.reasonCodeVersion)
        sink.field("policyVersion"); sink.string(value.policyVersion)
        sink.field("outcome"); sink.raw(value.outcome.rawValue)
        sink.field("reasonCodes"); sink.collection(value.reasonCodes.count)
        for reason in value.reasonCodes { sink.raw(reason.rawValue) }
        sink.field("candidateFingerprint"); encode(value.candidateFingerprint, into: &sink)
        sink.field("evidenceFingerprint"); encode(value.evidenceFingerprint, into: &sink)
        sink.field("eligibleFutureSample"); encode(value.eligibleFutureSample, into: &sink)
    }

    static func encode(_ value: String?, into sink: inout StreamingFNV1a) {
        sink.presence(value != nil)
        if let value { sink.string(value) }
    }

    static func encode(_ value: Int64?, into sink: inout StreamingFNV1a) {
        sink.presence(value != nil)
        if let value { sink.int64(value) }
    }
}

/// Streaming FNV-1a sink. Lengths are unsigned 64-bit values and Swift `Int`
/// values are normalized to signed 64-bit two's-complement before hashing, so
/// fingerprints do not depend on native memory layout or host endianness.
struct StreamingFNV1a {
    private(set) var value: UInt64 = 0xcbf29ce484222325

    mutating func domain(_ value: String) {
        marker(0xd0)
        string(value)
    }

    mutating func aggregate(_ value: String) {
        marker(0xa0)
        string(value)
    }

    mutating func field(_ value: String) {
        marker(0xf0)
        string(value)
    }

    mutating func raw(_ value: String) {
        marker(0xe0)
        string(value)
    }

    mutating func presence(_ present: Bool) {
        marker(0x0f)
        append(present ? 1 : 0)
    }

    mutating func collection(_ count: Int) {
        marker(0xc0)
        uint64(UInt64(count))
    }

    mutating func dictionary(_ count: Int) {
        marker(0xc1)
        uint64(UInt64(count))
    }

    mutating func bool(_ value: Bool) {
        marker(0xb0)
        append(value ? 1 : 0)
    }

    mutating func int(_ value: Int) {
        marker(0x68)
        int64(Int64(value))
    }

    mutating func int64(_ value: Int64) {
        marker(0x69)
        uint64(UInt64(bitPattern: value))
    }

    mutating func uint64(_ value: UInt64) {
        marker(0x75)
        fixed(value)
    }

    mutating func float(_ value: Float) {
        marker(0x34)
        fixed(value.bitPattern)
    }

    mutating func double(_ value: Double) {
        marker(0x64)
        fixed(value.bitPattern)
    }

    mutating func string(_ value: String) {
        marker(0x73)
        fixed(UInt64(value.utf8.count))
        for byte in value.utf8 { append(byte) }
    }

    private mutating func marker(_ value: UInt8) {
        append(value)
    }

    private mutating func append(_ byte: UInt8) {
        value ^= UInt64(byte)
        value &*= 0x100000001b3
    }

    private mutating func fixed<T: FixedWidthInteger>(_ input: T) {
        var littleEndian = input.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            for byte in bytes { append(byte) }
        }
    }
}
