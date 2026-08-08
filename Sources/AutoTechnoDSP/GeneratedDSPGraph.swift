import AutoTechnoCore
import Foundation

package enum DSPGraphNodeKind: String, CaseIterable, Sendable {
    case toneGuard
    case saturation
    case waveFold
    case phaser
    case chorus
    case comb
    case echo
    case diffusion
    case resonator
    case stereoMotion

    var permitsFeedback: Bool {
        switch self {
        case .comb, .echo, .diffusion: true
        default: false
        }
    }
}

package enum DSPGraphMutationKind: String, CaseIterable, Sendable {
    case insert
    case bypass
    case replace
    case reorder
    case rerouteSend
}

package struct DSPGraphNode: Equatable, Sendable {
    package let id: Int
    package let kind: DSPGraphNodeKind
    package let branch: Int
    package let order: Int
    package let amount: Double
    package let mix: Double
    package let feedback: Double
    package let delaySeconds: Double

    package init(id: Int, kind: DSPGraphNodeKind, branch: Int, order: Int,
                amount: Double, mix: Double, feedback: Double = 0,
                delaySeconds: Double = 0) {
        self.id = max(0, id)
        self.kind = kind
        self.branch = min(2, max(0, branch))
        self.order = max(0, order)
        self.amount = min(1, max(0, amount))
        self.mix = min(0.82, max(0, mix))
        self.feedback = min(0.68, max(0, feedback))
        self.delaySeconds = min(0.42, max(0, delaySeconds))
    }
}

package struct DSPGraphMutation: Equatable, Sendable {
    package let kind: DSPGraphMutationKind
    package let phraseIndex: Int
    package let affectedNodeIDs: [Int]

    package init(kind: DSPGraphMutationKind, phraseIndex: Int, affectedNodeIDs: [Int]) {
        self.kind = kind
        self.phraseIndex = phraseIndex
        self.affectedNodeIDs = affectedNodeIDs.sorted()
    }
}

package struct DSPProtectedRouting: Equatable, Sendable {
    package let kick: Bool
    package let subAndBass: Bool
    package let maskingProtection: Bool
    package let glue: Bool
    package let limiter: Bool
    package let output: Bool

    package static let fixed = DSPProtectedRouting(
        kick: true, subAndBass: true, maskingProtection: true,
        glue: true, limiter: true, output: true
    )

    package init(kick: Bool, subAndBass: Bool, maskingProtection: Bool,
                glue: Bool, limiter: Bool, output: Bool) {
        self.kick = kick
        self.subAndBass = subAndBass
        self.maskingProtection = maskingProtection
        self.glue = glue
        self.limiter = limiter
        self.output = output
    }

    package var valid: Bool {
        kick && subAndBass && maskingProtection && glue && limiter && output
    }
}

package struct DSPGraphPlan: Equatable, Sendable {
    package static let maximumNodeCount = 24
    package static let maximumSerialDepth = 12
    package static let maximumBranchCount = 3

    package let sessionSeed: UInt64
    package let revision: Int
    package let nodes: [DSPGraphNode]
    package let mutation: DSPGraphMutation?
    package let lowEndProtected: Bool
    package let protectedRouting: DSPProtectedRouting

    package init(sessionSeed: UInt64, revision: Int, nodes: [DSPGraphNode],
                mutation: DSPGraphMutation?, lowEndProtected: Bool = true,
                protectedRouting: DSPProtectedRouting = .fixed) {
        self.sessionSeed = sessionSeed
        self.revision = max(0, revision)
        self.nodes = nodes.sorted {
            if $0.branch != $1.branch { return $0.branch < $1.branch }
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id < $1.id
        }
        self.mutation = mutation
        self.lowEndProtected = lowEndProtected
        self.protectedRouting = protectedRouting
    }

    package var branchCount: Int { (nodes.map(\.branch).max() ?? -1) + 1 }
    package var maximumDepth: Int {
        (0..<max(1, branchCount)).map { branch in nodes.filter { $0.branch == branch }.count }.max() ?? 0
    }

    package func hasSameTopology(as other: DSPGraphPlan) -> Bool {
        revision == other.revision && nodes == other.nodes &&
            lowEndProtected == other.lowEndProtected && protectedRouting == other.protectedRouting
    }
}

package struct DSPGraphValidation: Equatable, Sendable {
    package let valid: Bool
    package let violations: [String]
}

package enum DSPGraphValidator {
    package static func validate(_ plan: DSPGraphPlan) -> DSPGraphValidation {
        var violations: [String] = []
        if !plan.lowEndProtected { violations.append("low-end path is not protected") }
        if !plan.protectedRouting.valid { violations.append("mandatory fixed routing is incomplete") }
        if plan.nodes.isEmpty { violations.append("graph has no upper-path processors") }
        if plan.nodes.count > DSPGraphPlan.maximumNodeCount { violations.append("node limit exceeded") }
        if plan.branchCount > DSPGraphPlan.maximumBranchCount { violations.append("branch limit exceeded") }
        if plan.maximumDepth > DSPGraphPlan.maximumSerialDepth { violations.append("serial-depth limit exceeded") }
        if Set(plan.nodes.map(\.id)).count != plan.nodes.count { violations.append("node ids are not unique") }
        if plan.mutation?.affectedNodeIDs.count ?? 0 > 2 { violations.append("more than one bounded mutation was encoded") }
        for node in plan.nodes {
            if !(0...2).contains(node.branch) { violations.append("invalid branch") }
            if !(0...1).contains(node.amount) || !(0...0.82).contains(node.mix) {
                violations.append("unbounded node amount")
            }
            if node.feedback > 0 && !node.kind.permitsFeedback {
                violations.append("feedback escaped a vetted memory module")
            }
            if node.feedback > 0.68 || node.delaySeconds > 0.42 {
                violations.append("memory bounds exceeded")
            }
        }
        for branch in 0..<max(1, plan.branchCount) {
            let orders = plan.nodes.filter { $0.branch == branch }.map(\.order).sorted()
            if orders != Array(0..<orders.count) { violations.append("branch order is not a directed chain") }
        }
        return DSPGraphValidation(valid: violations.isEmpty, violations: violations)
    }
}

package enum DSPGraphGenerator {
    package static func plan(sessionSeed: UInt64, phrase: AutonomousPhrasePlan,
                            memory: TemporalMusicalMemory, previous: DSPGraphPlan?,
                            routeRecovery: Bool = false) -> DSPGraphPlan {
        guard let previous else {
            return basePlan(sessionSeed: sessionSeed, phrase: phrase)
        }
        guard phrase.requestsTopologyMutation, phrase.kind != .energyRelease,
              !routeRecovery else {
            return DSPGraphPlan(sessionSeed: sessionSeed, revision: previous.revision,
                                nodes: previous.nodes, mutation: nil)
        }

        let mutationSeed = SceneDNA.derivedSeed(
            scene: sessionSeed,
            domain: UInt64(phrase.phraseIndex + memory.topologyRevision + 1),
            index: phrase.alternate ? 1 : 0
        )
        let kind = DSPGraphMutationKind.allCases[Int(mutationSeed % UInt64(DSPGraphMutationKind.allCases.count))]
        var nodes = previous.nodes
        var affected: [Int] = []

        switch kind {
        case .insert:
            let id = (nodes.map(\.id).max() ?? -1) + 1
            let branch = Int((mutationSeed >> 8) % UInt64(max(1, min(3, previous.branchCount))))
            let descriptor = node(id: id, branch: branch, order: nodes.filter { $0.branch == branch }.count,
                                  seed: mutationSeed, phrase: phrase)
            if nodes.count < DSPGraphPlan.maximumNodeCount {
                nodes.append(descriptor); affected = [id]
            }
        case .bypass:
            if nodes.count > 4 {
                let index = Int((mutationSeed >> 11) % UInt64(nodes.count))
                affected = [nodes[index].id]
                nodes.remove(at: index)
            }
        case .replace:
            let index = Int((mutationSeed >> 13) % UInt64(nodes.count))
            let old = nodes[index]
            nodes[index] = node(id: old.id, branch: old.branch, order: old.order,
                                seed: mutationSeed ^ 0x2E71ACE, phrase: phrase)
            affected = [old.id]
        case .reorder:
            let branch = Int((mutationSeed >> 15) % UInt64(max(1, previous.branchCount)))
            let indices = nodes.indices.filter { nodes[$0].branch == branch }
            if indices.count > 1 {
                let first = indices[Int((mutationSeed >> 18) % UInt64(indices.count))]
                let secondPosition = (indices.firstIndex(of: first)! + 1) % indices.count
                let second = indices[secondPosition]
                let a = nodes[first], b = nodes[second]
                nodes[first] = DSPGraphNode(id: a.id, kind: a.kind, branch: a.branch, order: b.order,
                                            amount: a.amount, mix: a.mix, feedback: a.feedback,
                                            delaySeconds: a.delaySeconds)
                nodes[second] = DSPGraphNode(id: b.id, kind: b.kind, branch: b.branch, order: a.order,
                                             amount: b.amount, mix: b.mix, feedback: b.feedback,
                                             delaySeconds: b.delaySeconds)
                affected = [a.id, b.id]
            }
        case .rerouteSend:
            let index = Int((mutationSeed >> 20) % UInt64(nodes.count))
            let old = nodes[index]
            let nextBranch = (old.branch + 1 + Int((mutationSeed >> 22) % 2)) % 3
            nodes[index] = DSPGraphNode(id: old.id, kind: old.kind, branch: nextBranch, order: 0,
                                        amount: old.amount, mix: old.mix, feedback: old.feedback,
                                        delaySeconds: old.delaySeconds)
            affected = [old.id]
        }

        nodes = normalized(nodes)
        let mutation = affected.isEmpty ? nil : DSPGraphMutation(
            kind: kind, phraseIndex: phrase.phraseIndex, affectedNodeIDs: affected
        )
        let candidate = DSPGraphPlan(
            sessionSeed: sessionSeed,
            revision: previous.revision + (mutation == nil ? 0 : 1),
            nodes: nodes,
            mutation: mutation
        )
        return DSPGraphValidator.validate(candidate).valid ? candidate : previous
    }

    package static func safePlan(sessionSeed: UInt64) -> DSPGraphPlan {
        DSPGraphPlan(sessionSeed: sessionSeed, revision: 0, nodes: [
            DSPGraphNode(id: 0, kind: .toneGuard, branch: 0, order: 0,
                         amount: 0.42, mix: 0.34),
            DSPGraphNode(id: 1, kind: .saturation, branch: 0, order: 1,
                         amount: 0.32, mix: 0.30),
            DSPGraphNode(id: 2, kind: .chorus, branch: 1, order: 0,
                         amount: 0.28, mix: 0.22, delaySeconds: 0.016),
            DSPGraphNode(id: 3, kind: .diffusion, branch: 1, order: 1,
                         amount: 0.30, mix: 0.20, feedback: 0.34, delaySeconds: 0.090),
        ], mutation: nil)
    }

    private static func basePlan(sessionSeed: UInt64, phrase: AutonomousPhrasePlan) -> DSPGraphPlan {
        let count = 7 + Int(SceneDNA.derivedSeed(scene: sessionSeed, domain: 0xD5A6, index: 0) % 5)
        var branchDepth = [0, 0, 0]
        let nodes = (0..<count).map { index -> DSPGraphNode in
            let seed = SceneDNA.derivedSeed(scene: sessionSeed, domain: 0xD5A6, index: index + 1)
            let branch = index < 2 ? 0 : Int(seed % 3)
            defer { branchDepth[branch] += 1 }
            return node(id: index, branch: branch, order: branchDepth[branch], seed: seed, phrase: phrase)
        }
        let candidate = DSPGraphPlan(sessionSeed: sessionSeed, revision: 0,
                                     nodes: normalized(nodes), mutation: nil)
        return DSPGraphValidator.validate(candidate).valid ? candidate : safePlan(sessionSeed: sessionSeed)
    }

    private static func node(id: Int, branch: Int, order: Int,
                             seed: UInt64, phrase: AutonomousPhrasePlan) -> DSPGraphNode {
        let palette = DSPGraphNodeKind.allCases
        let kind = palette[Int(seed % UInt64(palette.count))]
        let semanticAmount = min(1, 0.18 + phrase.scene.atmosphere * 0.34 + phrase.scene.textureChaos * 0.30 +
                                 Double((seed >> 9) % 101) / 500)
        let feedback = kind.permitsFeedback ? min(0.62, 0.18 + phrase.scene.hypnosis * 0.34) : 0
        let delay: Double
        switch kind {
        case .chorus: delay = 0.010 + Double((seed >> 15) % 12) / 1_000
        case .comb: delay = 0.018 + Double((seed >> 15) % 48) / 1_000
        case .echo: delay = 0.080 + Double((seed >> 15) % 260) / 1_000
        case .diffusion: delay = 0.045 + Double((seed >> 15) % 120) / 1_000
        default: delay = 0
        }
        return DSPGraphNode(
            id: id, kind: kind, branch: branch, order: order,
            amount: semanticAmount,
            mix: min(0.70, 0.12 + semanticAmount * 0.48),
            feedback: feedback,
            delaySeconds: delay
        )
    }

    private static func normalized(_ nodes: [DSPGraphNode]) -> [DSPGraphNode] {
        (0..<3).flatMap { branch -> [DSPGraphNode] in
            nodes.filter { $0.branch == branch }
                .sorted { lhs, rhs in lhs.order == rhs.order ? lhs.id < rhs.id : lhs.order < rhs.order }
                .enumerated().map { offset, node in
                    DSPGraphNode(id: node.id, kind: node.kind, branch: branch, order: offset,
                                 amount: node.amount, mix: node.mix, feedback: node.feedback,
                                 delaySeconds: node.delaySeconds)
                }
        }
    }
}

package struct DSPGraphNodeState: Equatable, Sendable {
    var memoryLeft = 0.0
    var memoryRight = 0.0
    var auxiliaryLeft = 0.0
    var auxiliaryRight = 0.0
    var phase = 0.0
    var delayLeft: [Float] = []
    var delayRight: [Float] = []
    var writeIndex = 0
}

package struct GeneratedDSPContinuationState: Equatable, Sendable {
    package var graph: DSPGraphPlan?
    var nodeStates: [Int: DSPGraphNodeState] = [:]
    var splitLowLeft = 0.0
    var splitLowRight = 0.0
    package internal(set) var retiringGraph: DSPGraphPlan?
    var retiringStates: [Int: DSPGraphNodeState] = [:]
    package internal(set) var retiringBarsRemaining = 0

    package init() {}
}

package enum GeneratedDSPGraphRenderer {
    package static func process(left: [Float], right: [Float], sampleRate: Double,
                               plan: DSPGraphPlan,
                               state: inout GeneratedDSPContinuationState) -> ([Float], [Float]) {
        let count = min(left.count, right.count)
        guard count > 0, sampleRate > 0 else { return (left, right) }
        if let old = state.graph, !old.hasSameTopology(as: plan) {
            state.retiringGraph = old
            state.retiringStates = state.nodeStates
            state.retiringBarsRemaining = 2
            let retainedIDs = Set(plan.nodes.map(\.id))
            let resetIDs = Set(plan.mutation?.affectedNodeIDs ?? [])
            state.nodeStates = state.nodeStates.filter {
                retainedIDs.contains($0.key) && !resetIDs.contains($0.key)
            }
        }
        state.graph = plan

        let coefficient = 1 - exp(-2 * Double.pi * 180 / sampleRate)
        var lowLeft = [Float](repeating: 0, count: count)
        var lowRight = [Float](repeating: 0, count: count)
        var upperLeft = [Float](repeating: 0, count: count)
        var upperRight = [Float](repeating: 0, count: count)
        for index in 0..<count {
            state.splitLowLeft += (Double(left[index]) - state.splitLowLeft) * coefficient
            state.splitLowRight += (Double(right[index]) - state.splitLowRight) * coefficient
            lowLeft[index] = Float(state.splitLowLeft)
            lowRight[index] = Float(state.splitLowRight)
            upperLeft[index] = left[index] - lowLeft[index]
            upperRight[index] = right[index] - lowRight[index]
        }

        var currentLeft = upperLeft
        var currentRight = upperRight
        processUpper(left: &currentLeft, right: &currentRight, sampleRate: sampleRate,
                     plan: plan, states: &state.nodeStates)

        if let retiring = state.retiringGraph, state.retiringBarsRemaining > 0 {
            var oldLeft = state.retiringBarsRemaining == 2 ? upperLeft : [Float](repeating: 0, count: count)
            var oldRight = state.retiringBarsRemaining == 2 ? upperRight : [Float](repeating: 0, count: count)
            processUpper(left: &oldLeft, right: &oldRight, sampleRate: sampleRate,
                         plan: retiring, states: &state.retiringStates)
            if state.retiringBarsRemaining == 2 {
                for index in 0..<count {
                    let progress = Double(index) / Double(max(1, count - 1))
                    let oldGain = cos(progress * .pi / 2)
                    let newGain = sin(progress * .pi / 2)
                    currentLeft[index] = Float(Double(oldLeft[index]) * oldGain + Double(currentLeft[index]) * newGain)
                    currentRight[index] = Float(Double(oldRight[index]) * oldGain + Double(currentRight[index]) * newGain)
                }
            } else {
                for index in 0..<count {
                    let tail = 0.16 * (1 - Double(index) / Double(max(1, count - 1)))
                    currentLeft[index] += Float(Double(oldLeft[index]) * tail)
                    currentRight[index] += Float(Double(oldRight[index]) * tail)
                }
            }
            state.retiringBarsRemaining -= 1
            if state.retiringBarsRemaining == 0 {
                state.retiringGraph = nil
                state.retiringStates.removeAll(keepingCapacity: false)
            }
        }

        var outputLeft = [Float](repeating: 0, count: count)
        var outputRight = [Float](repeating: 0, count: count)
        let normalizer = tanh(1.08)
        for index in 0..<count {
            outputLeft[index] = Float(tanh(Double(lowLeft[index] + currentLeft[index]) * 1.08) / normalizer * 0.90)
            outputRight[index] = Float(tanh(Double(lowRight[index] + currentRight[index]) * 1.08) / normalizer * 0.90)
        }
        return (outputLeft, outputRight)
    }

    private static func processUpper(left: inout [Float], right: inout [Float],
                                     sampleRate: Double, plan: DSPGraphPlan,
                                     states: inout [Int: DSPGraphNodeState]) {
        let count = min(left.count, right.count)
        let branchCount = max(1, plan.branchCount)
        var branchLeft = Array(repeating: left, count: branchCount)
        var branchRight = Array(repeating: right, count: branchCount)
        for node in plan.nodes {
            guard branchLeft.indices.contains(node.branch) else { continue }
            var nodeState = states[node.id] ?? DSPGraphNodeState()
            processNode(left: &branchLeft[node.branch], right: &branchRight[node.branch],
                        sampleRate: sampleRate, node: node, state: &nodeState)
            states[node.id] = nodeState
        }
        let gain = 1.0 / Double(branchCount)
        for index in 0..<count {
            left[index] = Float(branchLeft.reduce(0.0) { $0 + Double($1[index]) } * gain)
            right[index] = Float(branchRight.reduce(0.0) { $0 + Double($1[index]) } * gain)
        }
    }

    private static func processNode(left: inout [Float], right: inout [Float],
                                    sampleRate: Double, node: DSPGraphNode,
                                    state: inout DSPGraphNodeState) {
        let count = min(left.count, right.count)
        guard count > 0 else { return }
        let wet = node.mix
        let dry = 1 - wet
        switch node.kind {
        case .toneGuard:
            let coefficient = 1 - exp(-2 * Double.pi * (240 + node.amount * 1_100) / sampleRate)
            for index in 0..<count {
                state.memoryLeft += (Double(left[index]) - state.memoryLeft) * coefficient
                state.memoryRight += (Double(right[index]) - state.memoryRight) * coefficient
                let shapedLeft = Double(left[index]) - state.memoryLeft * node.amount * 0.42
                let shapedRight = Double(right[index]) - state.memoryRight * node.amount * 0.42
                left[index] = Float(Double(left[index]) * dry + shapedLeft * wet)
                right[index] = Float(Double(right[index]) * dry + shapedRight * wet)
            }
        case .saturation:
            let drive = 1 + node.amount * 3.2
            let norm = tanh(drive)
            for index in 0..<count {
                let l = tanh(Double(left[index]) * drive) / norm
                let r = tanh(Double(right[index]) * drive) / norm
                left[index] = Float(Double(left[index]) * dry + l * wet)
                right[index] = Float(Double(right[index]) * dry + r * wet)
            }
        case .waveFold:
            let drive = 1.2 + node.amount * 4.5
            for index in 0..<count {
                let l = sin(Double(left[index]) * drive) / max(1, drive * 0.44)
                let r = sin(Double(right[index]) * drive) / max(1, drive * 0.44)
                left[index] = Float(Double(left[index]) * dry + l * wet)
                right[index] = Float(Double(right[index]) * dry + r * wet)
            }
        case .phaser:
            let coefficient = 0.18 + node.amount * 0.58
            for index in 0..<count {
                let inputLeft = Double(left[index]), inputRight = Double(right[index])
                let outputLeft = -coefficient * inputLeft + state.memoryLeft + coefficient * state.auxiliaryLeft
                let outputRight = -coefficient * inputRight + state.memoryRight + coefficient * state.auxiliaryRight
                state.memoryLeft = inputLeft; state.memoryRight = inputRight
                state.auxiliaryLeft = outputLeft; state.auxiliaryRight = outputRight
                left[index] = Float(inputLeft * dry + outputLeft * wet)
                right[index] = Float(inputRight * dry + outputRight * wet)
            }
        case .chorus, .comb, .echo, .diffusion:
            processDelay(left: &left, right: &right, sampleRate: sampleRate,
                         node: node, state: &state)
        case .resonator:
            let frequency = 180 + node.amount * 1_800
            let coefficient = 2 * sin(Double.pi * frequency / sampleRate)
            let damping = 0.91 - node.amount * 0.12
            for index in 0..<count {
                state.auxiliaryLeft += coefficient * state.memoryLeft
                state.memoryLeft += coefficient * (Double(left[index]) - state.auxiliaryLeft - state.memoryLeft * damping)
                state.auxiliaryRight += coefficient * state.memoryRight
                state.memoryRight += coefficient * (Double(right[index]) - state.auxiliaryRight - state.memoryRight * damping)
                left[index] = Float(Double(left[index]) * dry + state.auxiliaryLeft * wet * 0.35)
                right[index] = Float(Double(right[index]) * dry + state.auxiliaryRight * wet * 0.35)
            }
        case .stereoMotion:
            let rate = 0.035 + node.amount * 0.18
            for index in 0..<count {
                let pan = sin(state.phase) * node.amount * 0.42
                state.phase += 2 * Double.pi * rate / sampleRate
                if state.phase >= 2 * Double.pi { state.phase -= 2 * Double.pi }
                let l = Double(left[index]) * (1 - max(0, pan)) + Double(right[index]) * max(0, -pan) * 0.18
                let r = Double(right[index]) * (1 - max(0, -pan)) + Double(left[index]) * max(0, pan) * 0.18
                left[index] = Float(Double(left[index]) * dry + l * wet)
                right[index] = Float(Double(right[index]) * dry + r * wet)
            }
        }
    }

    private static func processDelay(left: inout [Float], right: inout [Float],
                                     sampleRate: Double, node: DSPGraphNode,
                                     state: inout DSPGraphNodeState) {
        let minimum = node.kind == .chorus ? 0.008 : 0.012
        let delaySeconds = max(minimum, node.delaySeconds)
        let frames = max(32, Int(sampleRate * delaySeconds))
        if state.delayLeft.count != frames {
            state.delayLeft = [Float](repeating: 0, count: frames)
            state.delayRight = [Float](repeating: 0, count: frames)
            state.writeIndex = 0
        }
        let dry = 1 - node.mix
        for index in 0..<min(left.count, right.count) {
            let readIndex: Int
            if node.kind == .chorus {
                let modulation = Int((0.5 + 0.5 * sin(state.phase)) * Double(min(frames - 1, max(1, frames / 3))))
                readIndex = (state.writeIndex - modulation + frames) % frames
                state.phase += 2 * Double.pi * (0.08 + node.amount * 0.22) / sampleRate
            } else {
                readIndex = state.writeIndex
            }
            let delayedLeft = Double(state.delayLeft[readIndex])
            let delayedRight = Double(state.delayRight[readIndex])
            let inputLeft = Double(left[index]), inputRight = Double(right[index])
            let cross = node.kind == .diffusion ? 0.18 : 0.04
            state.delayLeft[state.writeIndex] = Float(inputLeft + delayedLeft * node.feedback + delayedRight * cross)
            state.delayRight[state.writeIndex] = Float(inputRight + delayedRight * node.feedback + delayedLeft * cross)
            state.writeIndex = (state.writeIndex + 1) % frames
            left[index] = Float(inputLeft * dry + delayedLeft * node.mix)
            right[index] = Float(inputRight * dry + delayedRight * node.mix)
        }
    }
}

package struct PhraseBarAudioEvidence: Equatable, Sendable {
    package let bar: Int
    package let loudness: Double
    package let spectralCentroid: Double
    package let transientDensity: Double
    package let crestFactor: Double
    package let finite: Bool
}

package struct PhraseAudioPreflight: Equatable, Sendable {
    package let quality: AudioQualityReport
    package let bars: [PhraseBarAudioEvidence]
    package let movementScore: Double
    package let safetyValid: Bool
    package let interesting: Bool

    package init(blocks: [RenderBlock], sampleRate: Double) {
        let report = AudioQualityReport(blocks: blocks, sampleRate: sampleRate)
        let barEvidence = blocks.map { block -> PhraseBarAudioEvidence in
            let barReport = AudioQualityReport(blocks: [block], sampleRate: sampleRate)
            return PhraseBarAudioEvidence(
                bar: block.bar,
                loudness: Double(barReport.loudnessEstimate),
                spectralCentroid: barReport.musical.spectralCentroid,
                transientDensity: barReport.musical.transientDensity,
                crestFactor: barReport.rms > 0
                    ? Double(barReport.peak / barReport.rms)
                    : 0,
                finite: barReport.finite
            )
        }
        let loudnessValues = barEvidence.map { $0.loudness }
        let spectralValues = barEvidence.map { $0.spectralCentroid }
        let transientValues = barEvidence.map { $0.transientDensity }
        let crestValues = barEvidence.map { $0.crestFactor }
        let loudnessMovement = min(1, ((loudnessValues.max() ?? -120) - (loudnessValues.min() ?? -120)) / 8)
        let spectralMovement = min(1, ((spectralValues.max() ?? 0) - (spectralValues.min() ?? 0)) / 800)
        let transientMovement = min(1, ((transientValues.max() ?? 0) - (transientValues.min() ?? 0)) / 2.5)
        let dynamicMovement = min(1, ((crestValues.max() ?? 0) - (crestValues.min() ?? 0)) / 3)
        quality = report
        bars = barEvidence
        movementScore = loudnessMovement * 0.34 + spectralMovement * 0.24 +
            transientMovement * 0.22 + dynamicMovement * 0.20
        safetyValid = barEvidence.allSatisfy { $0.finite } && report.finite && report.truePeakEstimate <= 0.95 &&
            abs(report.dcOffset) < 0.05 && report.lowStereoCorrelation > 0.94 &&
            report.maxBoundaryDelta < 0.65
        interesting = safetyValid && movementScore >= 0.30
    }
}

package struct PreparedAutonomousPhrase: Sendable {
    package let plan: AutonomousPhrasePlan
    package let graph: DSPGraphPlan
    package let blocks: [RenderBlock]
    package let endingRenderState: RenderState
    package let endingGraphState: GeneratedDSPContinuationState
    package let audioPreflight: PhraseAudioPreflight
    package let usedAlternate: Bool
    package let usedFallback: Bool

    package var combinedScore: Double {
        plan.interest.score * 0.55 + audioPreflight.movementScore * 0.45
    }
}

package enum AutonomousPreflightChoice: Equatable, Sendable {
    case primary
    case alternate
    case fallback
}

package struct AutonomousCandidateEvidence: Equatable, Sendable {
    package let symbolicValid: Bool
    package let safetyValid: Bool
    package let interesting: Bool
    package let combinedScore: Double

    package init(symbolicValid: Bool, safetyValid: Bool, interesting: Bool,
                combinedScore: Double) {
        self.symbolicValid = symbolicValid
        self.safetyValid = safetyValid
        self.interesting = interesting
        self.combinedScore = min(1, max(0, combinedScore))
    }
}

/// Pure selection policy used by preparation and by synthetic anti-stagnation
/// tests. An interesting, valid primary is retained immediately; otherwise an
/// alternate may compete. Equal scores always preserve the primary.
package enum AutonomousCandidateSelector {
    package static func needsAlternate(primary: AutonomousCandidateEvidence) -> Bool {
        !(primary.symbolicValid && primary.safetyValid && primary.interesting)
    }

    package static func choose(primary: AutonomousCandidateEvidence,
                              alternate: AutonomousCandidateEvidence?) -> AutonomousPreflightChoice {
        if !needsAlternate(primary: primary) { return .primary }
        let primaryValid = primary.symbolicValid && primary.safetyValid
        let alternateValid = alternate.map { $0.symbolicValid && $0.safetyValid } ?? false
        switch (primaryValid, alternateValid) {
        case (true, true):
            guard let alternate else { return .primary }
            return alternate.combinedScore > primary.combinedScore ? .alternate : .primary
        case (true, false): return .primary
        case (false, true): return .alternate
        case (false, false): return .fallback
        }
    }
}

package enum AutonomousPhrasePreparer {
    package static func prepare(candidates: AutonomousPhraseCandidates,
                               sessionSeed: UInt64,
                               memory: TemporalMusicalMemory,
                               sampleRate: Double,
                               incomingRenderState: RenderState,
                               incomingGraphState: GeneratedDSPContinuationState,
                               previousGraph: DSPGraphPlan?,
                               routeRecovery: Bool = false) -> PreparedAutonomousPhrase {
        let primary = render(plan: candidates.primary, sessionSeed: sessionSeed, memory: memory,
                           sampleRate: sampleRate, incomingRenderState: incomingRenderState,
                           incomingGraphState: incomingGraphState, previousGraph: previousGraph,
                           routeRecovery: routeRecovery)
        let primaryEvidence = evidence(for: primary)
        guard AutonomousCandidateSelector.needsAlternate(primary: primaryEvidence) else { return primary }

        let alternate = render(plan: candidates.alternate, sessionSeed: sessionSeed, memory: memory,
                               sampleRate: sampleRate, incomingRenderState: incomingRenderState,
                               incomingGraphState: incomingGraphState, previousGraph: previousGraph,
                               routeRecovery: routeRecovery)
        switch AutonomousCandidateSelector.choose(
            primary: primaryEvidence,
            alternate: evidence(for: alternate)
        ) {
        case .primary: return primary
        case .alternate: return alternate
        case .fallback: break
        }
        return render(plan: candidates.fallback, sessionSeed: sessionSeed, memory: memory,
                      sampleRate: sampleRate, incomingRenderState: incomingRenderState,
                      incomingGraphState: incomingGraphState, previousGraph: previousGraph,
                      routeRecovery: routeRecovery, forceSafeGraph: true)
    }

    private static func evidence(for phrase: PreparedAutonomousPhrase) -> AutonomousCandidateEvidence {
        AutonomousCandidateEvidence(
            symbolicValid: phrase.plan.interest.valid,
            safetyValid: phrase.audioPreflight.safetyValid,
            interesting: phrase.audioPreflight.interesting,
            combinedScore: phrase.combinedScore
        )
    }

    private static func render(plan: AutonomousPhrasePlan, sessionSeed: UInt64,
                               memory: TemporalMusicalMemory, sampleRate: Double,
                               incomingRenderState: RenderState,
                               incomingGraphState: GeneratedDSPContinuationState,
                               previousGraph: DSPGraphPlan?, routeRecovery: Bool,
                               forceSafeGraph: Bool = false) -> PreparedAutonomousPhrase {
        let proposedGraph = forceSafeGraph
            ? (previousGraph ?? DSPGraphGenerator.safePlan(sessionSeed: sessionSeed))
            : DSPGraphGenerator.plan(sessionSeed: sessionSeed, phrase: plan, memory: memory,
                                     previous: previousGraph, routeRecovery: routeRecovery)
        let graph: DSPGraphPlan
        if DSPGraphValidator.validate(proposedGraph).valid {
            graph = proposedGraph
        } else if let previousGraph, DSPGraphValidator.validate(previousGraph).valid {
            graph = previousGraph
        } else {
            graph = DSPGraphGenerator.safePlan(sessionSeed: sessionSeed)
        }
        var renderState = incomingRenderState
        var graphState = incomingGraphState
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan, graph: graph, sampleRate: sampleRate,
            state: &renderState, graphState: &graphState
        )
        return PreparedAutonomousPhrase(
            plan: plan,
            graph: graph,
            blocks: blocks,
            endingRenderState: renderState,
            endingGraphState: graphState,
            audioPreflight: PhraseAudioPreflight(blocks: blocks, sampleRate: sampleRate),
            usedAlternate: plan.alternate,
            usedFallback: plan.conservative
        )
    }
}
