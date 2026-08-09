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
    package static func plan(_ plan: AutonomousPhrasePlan) -> String {
        digest(domain: "candidate-plan.typed.v3") { sink in
            encode(plan, into: &sink)
        }
    }

    package static func graph(_ graph: DSPGraphPlan) -> String {
        digest(domain: "generated-graph.typed.v1") { sink in
            encode(graph, into: &sink)
        }
    }

    package static func renderState(_ state: RenderState) -> String {
        digest(domain: "render-state.typed.v2") { sink in
            encode(state, into: &sink)
        }
    }

    package static func renderState(
        _ state: RenderState,
        cancellationRequested: @Sendable () -> Bool
    ) -> String? {
        cancellableDigest(
            domain: "render-state.typed.v2",
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

    package static func renderDSPContinuation(
        renderState: RenderState,
        generatedDSPState: GeneratedDSPContinuationState
    ) -> String {
        digest(domain: "render-dsp-continuation.typed.v2") { sink in
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
            domain: "render-dsp-continuation.typed.v2",
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
        sink.field("alternate"); sink.bool(value.alternate)
        sink.field("conservative"); sink.bool(value.conservative)
        sink.field("interest"); encode(value.interest, into: &sink)
        sink.field("endingInterlockState"); encode(value.endingInterlockState, into: &sink)
        sink.field("endingSpatialContrastState")
        encode(value.endingSpatialContrastState, into: &sink)
        sink.field("endingNarrativeState"); encode(value.endingNarrativeState, into: &sink)
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
        sink.field("arrangementGesture"); sink.raw(value.arrangementGesture.rawValue)
        sink.field("percussionGear"); sink.raw(value.percussionGear.rawValue)
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
        sink.field("spatialContrast"); encode(value.spatialContrast, into: &sink)
        sink.field("narrative"); encode(value.narrative, into: &sink)
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
        sink.field("reverbBuffer"); encode(value.reverbBuffer, into: &sink)
        sink.field("reverbWriteIndex"); sink.int(value.reverbWriteIndex)
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
        sink.field("previousResonantAnchorEvidenceFrame")
        encode(value.previousResonantAnchorEvidenceFrame, into: &sink)
        sink.field("previousDetunedCompanionEvidenceFrame")
        encode(value.previousDetunedCompanionEvidenceFrame, into: &sink)
        sink.field("previousGraphInputRemainderEvidenceFrame")
        encode(value.previousGraphInputRemainderEvidenceFrame, into: &sink)
        sink.field("previousPostGraphRemainderEvidenceFrame")
        encode(value.previousPostGraphRemainderEvidenceFrame, into: &sink)
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
        sink.field("reverbBuffer")
        guard encode(
            value.reverbBuffer,
            into: &sink,
            cancellationRequested: cancellationRequested
        ) else { return false }
        sink.field("reverbWriteIndex"); sink.int(value.reverbWriteIndex)
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
        sink.field("previousResonantAnchorEvidenceFrame")
        encode(value.previousResonantAnchorEvidenceFrame, into: &sink)
        sink.field("previousDetunedCompanionEvidenceFrame")
        encode(value.previousDetunedCompanionEvidenceFrame, into: &sink)
        sink.field("previousGraphInputRemainderEvidenceFrame")
        encode(value.previousGraphInputRemainderEvidenceFrame, into: &sink)
        sink.field("previousPostGraphRemainderEvidenceFrame")
        encode(value.previousPostGraphRemainderEvidenceFrame, into: &sink)
        return true
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

    static func encode(_ value: ResonantMonoState, into sink: inout StreamingFNV1a) {
        sink.aggregate("ResonantMonoState")
        sink.field("activePatch"); encode(value.activePatch, into: &sink)
        sink.field("phase"); sink.double(value.phase)
        sink.field("subPhase"); sink.double(value.subPhase)
        sink.field("filter1"); sink.double(value.filter1)
        sink.field("filter2"); sink.double(value.filter2)
        sink.field("filter3"); sink.double(value.filter3)
        sink.field("filter4"); sink.double(value.filter4)
        sink.field("dcInput"); sink.double(value.dcInput)
        sink.field("dcOutput"); sink.double(value.dcOutput)
        sink.field("frequency"); sink.double(value.frequency)
        sink.field("envelope"); sink.double(value.envelope)
    }

    static func encode(_ value: SpectralTextureState, into sink: inout StreamingFNV1a) {
        sink.aggregate("SpectralTextureState")
        sink.field("activePatch"); encode(value.activePatch, into: &sink)
        sink.field("phaseA"); sink.double(value.phaseA)
        sink.field("phaseB"); sink.double(value.phaseB)
        sink.field("phaseC"); sink.double(value.phaseC)
        sink.field("low"); sink.double(value.low)
        sink.field("band"); sink.double(value.band)
        sink.field("resonator"); sink.double(value.resonator)
        sink.field("previousResonator"); sink.double(value.previousResonator)
        sink.field("dcInput"); sink.double(value.dcInput)
        sink.field("dcOutput"); sink.double(value.dcOutput)
        sink.field("frequency"); sink.double(value.frequency)
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
private struct StreamingFNV1a {
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
