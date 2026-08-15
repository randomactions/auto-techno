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
        if Set(plan.nodes.map(\.branch)) != Set(0..<plan.branchCount) {
            violations.append("branch indices are not contiguous")
        }
        if Set(plan.nodes.map(\.id)).count != plan.nodes.count { violations.append("node ids are not unique") }
        if plan.revision < 0 { violations.append("negative graph revision") }
        if plan.nodes.contains(where: { $0.id < 0 || $0.id == Int.max }) {
            violations.append("unsafe node id")
        }
        if let mutation = plan.mutation {
            let expectedAffectedCount = mutation.kind == .reorder ? 2 : 1
            if mutation.phraseIndex < 0 || mutation.phraseIndex == Int.max {
                violations.append("unsafe mutation phrase")
            }
            if mutation.affectedNodeIDs.count != expectedAffectedCount ||
                Set(mutation.affectedNodeIDs).count != mutation.affectedNodeIDs.count ||
                mutation.affectedNodeIDs.contains(where: { $0 < 0 || $0 == Int.max }) {
                violations.append("invalid mutation ownership")
            }
        }
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
        // Route recovery replays the already-selected target graph against the
        // interrupted phrase's incoming graph state. Preserve its mutation
        // metadata so changed-node state is reset exactly as it was on the
        // original render when the topology differs.
        if routeRecovery { return previous }
        guard phrase.requestsTopologyMutation, phrase.kind != .energyRelease else {
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
        guard DSPGraphValidator.validate(candidate).valid else {
            // A rejected current-phrase mutation freezes the prior topology,
            // but the prior phrase's mutation metadata is not a new state
            // transition and must not leak into recovery provenance.
            return DSPGraphPlan(
                sessionSeed: sessionSeed,
                revision: previous.revision,
                nodes: previous.nodes,
                mutation: nil,
                lowEndProtected: previous.lowEndProtected,
                protectedRouting: previous.protectedRouting
            )
        }
        return candidate
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
        guard let preflight = Self(
            blocks: blocks,
            sampleRate: sampleRate,
            cancellationRequested: { false }
        ) else {
            preconditionFailure("Non-cancellable phrase preflight stopped unexpectedly")
        }
        self = preflight
    }

    package init?(
        blocks: [RenderBlock],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) {
        guard let report = AudioQualityReport(
            blocks: blocks,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        var barEvidence: [PhraseBarAudioEvidence] = []
        barEvidence.reserveCapacity(blocks.count)
        for block in blocks {
            guard !cancellationRequested(), let barMetrics = MusicalQualityMetrics(
                left: block.left,
                right: block.right,
                sampleRate: sampleRate,
                cancellationRequested: cancellationRequested
            ) else { return nil }
            let count = min(block.left.count, block.right.count)
            var peak = 0.0
            var energy = 0.0
            var finite = count > 0 && block.left.count == block.right.count
            for index in 0..<count {
                if index.isMultiple(of: 16_384), cancellationRequested() {
                    return nil
                }
                let left = Double(block.left[index])
                let right = Double(block.right[index])
                finite = finite && left.isFinite && right.isFinite
                peak = max(peak, abs(left), abs(right))
                energy += left * left + right * right
            }
            let rms = sqrt(energy / Double(max(1, count * 2)))
            barEvidence.append(PhraseBarAudioEvidence(
                bar: block.bar,
                loudness: barMetrics.integratedLoudness,
                spectralCentroid: barMetrics.spectralCentroid,
                transientDensity: barMetrics.transientDensity,
                crestFactor: rms > 0 ? peak / rms : 0,
                finite: finite && barMetrics.integratedLoudness.isFinite &&
                    barMetrics.spectralCentroid.isFinite &&
                    barMetrics.transientDensity.isFinite
            ))
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
        safetyValid = !barEvidence.isEmpty && barEvidence.allSatisfy { $0.finite } &&
            report.finite && report.truePeakEstimate <= 0.95 &&
            abs(report.dcOffset) < 0.05 && report.lowStereoCorrelation > 0.94 &&
            report.maxBoundaryDelta < 0.65
        // Movement is evidence for comparison, not a musicality threshold. A
        // sparse lock or break may be the most intentional candidate.
        interesting = safetyValid
    }
}

/// Construction-time binding between one transaction and its cached digest.
/// The private initializer is the only place the pair can be formed.
fileprivate struct BoundCandidateEvaluation {
    let transaction: AutonomousCandidateEvaluationTransaction
    let fingerprint: String

    init(_ transaction: AutonomousCandidateEvaluationTransaction) {
        self.transaction = transaction
        fingerprint = transaction.fingerprint
    }
}

/// Immutable reference storage keeps the complete prepared product off the
/// bounded cooperative-task stack while preserving atomic commit semantics.
package final class PreparedAutonomousPhrase: Sendable {
    package let plan: AutonomousPhrasePlan
    package let graph: DSPGraphPlan
    package let blocks: [RenderBlock]
    package let endingRenderState: RenderState
    package let endingGraphState: GeneratedDSPContinuationState
    package let audioPreflight: PhraseAudioPreflight
    package let upperTimbreEvidence: UpperTimbreEvidence
    package let selectedCandidateEvidence: AutonomousCandidateEvaluationVector
    package let candidateEvaluation: AutonomousCandidateEvaluationTransaction
    /// Computed from `candidateEvaluation` exactly once during finalization.
    /// The fileprivate initializer prevents pairing this cache with another
    /// transaction while keeping main-actor commit checks bounded.
    package let candidateEvaluationFingerprint: String
    package let commitProvenance: AutonomousPreparedCommitProvenance
    package let qualityDecision: QualityDecision
    package let incomingQualityState: QualityContinuationState
    package let qualityContinuationState: QualityContinuationState
    package let correctionRenderCount: Int
    package let usedAlternate: Bool
    package let usedFallback: Bool
    package let usedHomeTimbreFallback: Bool

    fileprivate init(
        plan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        blocks: [RenderBlock],
        endingRenderState: RenderState,
        endingGraphState: GeneratedDSPContinuationState,
        audioPreflight: PhraseAudioPreflight,
        upperTimbreEvidence: UpperTimbreEvidence,
        selectedCandidateEvidence: AutonomousCandidateEvaluationVector,
        boundCandidateEvaluation: BoundCandidateEvaluation,
        commitProvenance: AutonomousPreparedCommitProvenance,
        qualityDecision: QualityDecision,
        incomingQualityState: QualityContinuationState,
        qualityContinuationState: QualityContinuationState,
        correctionRenderCount: Int,
        usedAlternate: Bool,
        usedFallback: Bool,
        usedHomeTimbreFallback: Bool
    ) {
        self.plan = plan
        self.graph = graph
        self.blocks = blocks
        self.endingRenderState = endingRenderState
        self.endingGraphState = endingGraphState
        self.audioPreflight = audioPreflight
        self.upperTimbreEvidence = upperTimbreEvidence
        self.selectedCandidateEvidence = selectedCandidateEvidence
        candidateEvaluation = boundCandidateEvaluation.transaction
        candidateEvaluationFingerprint = boundCandidateEvaluation.fingerprint
        self.commitProvenance = commitProvenance
        self.qualityDecision = qualityDecision
        self.incomingQualityState = incomingQualityState
        self.qualityContinuationState = qualityContinuationState
        self.correctionRenderCount = correctionRenderCount
        self.usedAlternate = usedAlternate
        self.usedFallback = usedFallback
        self.usedHomeTimbreFallback = usedHomeTimbreFallback
    }

    package var combinedScore: Double {
        plan.interest.score * 0.82 + audioPreflight.movementScore * 0.18
    }

    package var playbackHardGatesPassed: Bool {
        !blocks.isEmpty && plan.interest.valid && audioPreflight.safetyValid &&
            upperTimbreEvidence.finite &&
            selectedCandidateEvidence.playbackHardGatesPassed
    }

    package var hardGatesPassed: Bool {
        playbackHardGatesPassed && selectedCandidateEvidence.hardGatesPassed
    }

    /// The uncalibrated foundation remains playable while clearly reporting
    /// qualification unavailable. Once a calibrated policy is installed, only
    /// qualified/adjusted authored material or the hard-safe score-owned
    /// conservative fallback may cross the atomic commit boundary.
    package var commitEligible: Bool {
        guard candidateEvaluation.isComplete,
              commitProvenance.candidateEvaluationFingerprint ==
                candidateEvaluationFingerprint,
              let selectedIndex = candidateEvaluation.selectedAttemptIndex,
              candidateEvaluation.attempts.indices.contains(selectedIndex),
              candidateEvaluation.attempts[selectedIndex].vector ==
                selectedCandidateEvidence,
              selectedCandidateEvidence.fullMix.sampleHash ==
                audioPreflight.quality.sampleHash,
              selectedCandidateEvidence.postGraphUpperTimbreEvidence ==
                upperTimbreEvidence,
              qualityContinuationState.observedControllerStateFingerprint ==
                selectedCandidateEvidence.routeContinuation
                    .controllerStateFingerprint,
              qualityDecision.evidenceFingerprint == candidateEvaluationFingerprint,
              commitProvenance.matches(
                candidateEvaluationFingerprint: candidateEvaluationFingerprint,
                selectedSampleHash: audioPreflight.quality.sampleHash,
                outgoingRenderDSPFingerprint:
                    selectedCandidateEvidence.routeContinuation
                        .outgoingRenderDSPFingerprint,
                qualityState: qualityContinuationState
              ) else {
            return false
        }
        return AutonomousCommitPolicy.isEligible(
            playbackHardGatesPassed: playbackHardGatesPassed,
            evaluationHardGatesPassed: selectedCandidateEvidence.hardGatesPassed,
            selectedSlot: candidateEvaluation.selectedSlot,
            decision: qualityDecision,
            continuationState: qualityContinuationState,
            candidateFingerprint: audioPreflight.quality.sampleHash,
            evidenceFingerprint: candidateEvaluationFingerprint,
            controllerStateFingerprint:
                selectedCandidateEvidence.routeContinuation
                    .controllerStateFingerprint
        )
    }
}

package enum AutonomousCommitPolicy {
    package static func isEligible(
        playbackHardGatesPassed: Bool,
        evaluationHardGatesPassed: Bool,
        selectedSlot: AutonomousCandidateSlot?,
        decision: QualityDecision,
        continuationState: QualityContinuationState,
        candidateFingerprint: String,
        evidenceFingerprint: String,
        controllerStateFingerprint: String
    ) -> Bool {
        guard playbackHardGatesPassed,
              !controllerStateFingerprint.isEmpty,
              !decision.policyVersion.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              decision.hasOutcomeConsistentReasonCodes,
              continuationState.lastDecision == decision,
              continuationState.acceptanceProvenanceComplete,
              decision.candidateFingerprint == candidateFingerprint,
              decision.evidenceFingerprint == evidenceFingerprint,
              continuationState.observedCandidateFingerprint == candidateFingerprint,
              continuationState.observedEvidenceFingerprint == evidenceFingerprint,
              continuationState.observedControllerStateFingerprint ==
                controllerStateFingerprint,
              !decision.isAcceptanceOutcome ||
                continuationState.acceptedControllerStateFingerprint ==
                    controllerStateFingerprint else {
            return false
        }
        if decision.policyVersion == QualityQualificationContract.uncalibratedPolicyVersion {
            return decision.outcome == .qualificationUnavailable
        }
        guard evaluationHardGatesPassed else { return false }
        switch decision.outcome {
        case .qualified, .adjusted:
            return selectedSlot == .primary || selectedSlot == .alternate
        case .conservativeFallback:
            return selectedSlot == .fallback
        case .qualificationUnavailable, .rejected, .deterministicHold:
            return false
        }
    }
}

/// One preparation transaction owns one corrective rerender budget across its
/// primary, alternate, and fallback candidates. This keeps detached work
/// bounded even when every candidate fails its evidence hard gate.
package struct AutonomousCorrectionBudget: Equatable, Sendable {
    package let maximum: Int
    package private(set) var used: Int

    package init(
        maximum: Int = QualityQualificationContract.maximumCorrectionRenders,
        used: Int = 0
    ) {
        self.maximum = max(0, maximum)
        self.used = min(max(0, used), self.maximum)
    }

    package mutating func claim() -> Bool {
        guard used < maximum else { return false }
        used += 1
        return true
    }
}

/// Claims every expensive candidate render before it starts. The transaction
/// record diagnoses bounds after the fact; this budget enforces them before
/// allocating PCM or mutating detached continuation state.
package struct AutonomousRenderPassBudget: Equatable, Sendable {
    package let maximum: Int
    package private(set) var used: Int

    package init(
        maximum: Int = QualityQualificationContract.maximumRenderPasses,
        used: Int = 0
    ) {
        self.maximum = max(0, maximum)
        self.used = min(max(0, used), self.maximum)
    }

    package mutating func claim() -> Bool {
        guard used < maximum else { return false }
        used += 1
        return true
    }
}

package enum AutonomousPreflightChoice: Equatable, Sendable {
    case primary
    case alternate
    case fallback
}

/// The calibrated evaluator owns this comparison after inspecting the complete
/// evidence vectors. Until calibration exists, preparation passes `.unavailable`
/// and preserves a hard-valid primary rather than inventing taste thresholds.
package enum AutonomousQualityComparison: Equatable, Sendable {
    case unavailable
    case primary
    case alternate
    case tie
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

/// Pure selection policy used by preparation and synthetic policy tests. Hard
/// gates are non-compensable. An unavailable or exact-tie quality comparison
/// preserves a hard-valid primary; a calibrated evaluator may explicitly order
/// the complete evidence vectors without teaching this selector DSP thresholds.
package enum AutonomousCandidateSelector {
    package static func needsAlternate(primary: AutonomousCandidateEvidence,
                                       qualityComparisonAvailable: Bool = false) -> Bool {
        !(primary.symbolicValid && primary.safetyValid) || qualityComparisonAvailable
    }

    package static func choose(primary: AutonomousCandidateEvidence,
                              alternate: AutonomousCandidateEvidence?,
                              qualityComparison: AutonomousQualityComparison = .unavailable)
        -> AutonomousPreflightChoice {
        if !needsAlternate(
            primary: primary,
            qualityComparisonAvailable: qualityComparison != .unavailable
        ) { return .primary }
        let primaryValid = primary.symbolicValid && primary.safetyValid
        let alternateValid = alternate.map { $0.symbolicValid && $0.safetyValid } ?? false
        // A calibrated policy may reject every surviving authored candidate.
        // That non-compensable result must reach the conservative score even
        // when exactly one candidate passed the lower-level signal gates.
        if qualityComparison == .fallback { return .fallback }
        switch (primaryValid, alternateValid) {
        case (true, true):
            switch qualityComparison {
            case .alternate: return .alternate
            case .unavailable, .primary, .tie: return .primary
            case .fallback: return .fallback
            }
        case (true, false): return .primary
        case (false, true): return .alternate
        case (false, false): return .fallback
        }
    }
}

package enum AutonomousCandidateCorrectionPolicy {
    package static func choose(
        selectedSlot: AutonomousCandidateSlot?,
        primaryRepairable: Bool,
        alternateRepairable: Bool
    ) -> AutonomousCandidateSlot? {
        if let selectedSlot {
            switch selectedSlot {
            case .primary: return primaryRepairable ? .primary : nil
            case .alternate: return alternateRepairable ? .alternate : nil
            case .fallback:
                if primaryRepairable { return .primary }
                if alternateRepairable { return .alternate }
                return nil
            }
        }
        if primaryRepairable { return .primary }
        if alternateRepairable { return .alternate }
        return nil
    }
}

package struct AutonomousCandidatePolicyVerdict: Equatable, Sendable {
    package let outcome: QualityDecisionOutcome
    package let reasonCodes: [QualityReasonCode]

    package init(
        outcome: QualityDecisionOutcome,
        reasonCodes: [QualityReasonCode]
    ) {
        self.outcome = outcome
        self.reasonCodes = Array(Set(reasonCodes)).sorted {
            $0.rawValue < $1.rawValue
        }
    }
}

/// A package-only seam for a future calibrated comparator. The production
/// overload below always installs the uncalibrated implementation; this is not
/// a second runtime, profile, or user-selectable mode.
package protocol AutonomousCandidateEvaluating: Sendable {
    var policyVersion: String { get }
    var evaluatorVersion: String { get }
    var requiresPairedCandidates: Bool { get }

    /// Candidate-local decision made only after the immutable primary exists.
    /// A calibrated evaluator can decline an unnecessary alternate when this
    /// phrase has no applicable checkpoint or the active route is outside its
    /// profile, while fixed test policies retain their declared behavior.
    func requestsPairedComparison(
        after primary: AutonomousCandidateEvaluationVector
    ) -> Bool

    func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison

    func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool

    func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict
}

package extension AutonomousCandidateEvaluating {
    func requestsPairedComparison(
        after primary: AutonomousCandidateEvaluationVector
    ) -> Bool {
        requiresPairedCandidates
    }
}

package struct UncalibratedAutonomousCandidateEvaluator:
    AutonomousCandidateEvaluating {
    package let policyVersion =
        QualityQualificationContract.uncalibratedPolicyVersion
    package let evaluatorVersion =
        QualityQualificationContract.uncalibratedEvaluatorVersion
    package let requiresPairedCandidates = false

    package init() {}

    package func compare(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector
    ) -> AutonomousQualityComparison {
        .unavailable
    }

    package func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        Self.requestsHomeUpperTimbreCorrection(for: candidate)
    }

    package static func requestsHomeUpperTimbreCorrection(
        for candidate: AutonomousCandidateEvaluationVector
    ) -> Bool {
        !candidate.symbolic.conservative &&
            candidate.hardGates.symbolicValid &&
            candidate.hardGates.graphValid &&
            candidate.hardGates.audioSafetyValid &&
            candidate.hardGates.fullMixFinite &&
            candidate.hardGates.blocksPresent &&
            candidate.hardGates.blockChannelsAligned &&
            candidate.hardGates.allSamplesFinite &&
            candidate.hardGates.completeInputs &&
            !candidate.postGraphUpperTimbreEvidence.finite
    }

    package func terminalVerdict(
        selected: AutonomousCandidateEvaluationVector,
        transaction: AutonomousCandidateEvaluationTransaction
    ) -> AutonomousCandidatePolicyVerdict {
        AutonomousCandidatePolicyVerdict(
            outcome: .qualificationUnavailable,
            reasonCodes: [.policyUncalibratedV1]
        )
    }
}

package enum AutonomousPhrasePreparer {
    private final class CandidateRenderContext {
        let sessionSeed: UInt64
        let memory: TemporalMusicalMemory
        let sampleRate: Double
        let incomingRenderState: RenderState
        let incomingGraphState: GeneratedDSPContinuationState
        let previousGraph: DSPGraphPlan?
        let planFingerprints: AutonomousCandidatePlanFingerprints
        let routeFingerprint: String
        let incomingContinuationFingerprint: String
        let incomingQualityStateFingerprint: String
        let previousGraphFingerprint: String
        let routeRecovery: Bool
        let routeChannelCount: Int
        let routeGeneration: Int
        let cancellationRequested: @Sendable () -> Bool

        init(
            sessionSeed: UInt64,
            memory: TemporalMusicalMemory,
            sampleRate: Double,
            incomingRenderState: RenderState,
            incomingGraphState: GeneratedDSPContinuationState,
            previousGraph: DSPGraphPlan?,
            planFingerprints: AutonomousCandidatePlanFingerprints,
            routeFingerprint: String,
            incomingContinuationFingerprint: String,
            incomingQualityStateFingerprint: String,
            previousGraphFingerprint: String,
            routeRecovery: Bool,
            routeChannelCount: Int,
            routeGeneration: Int,
            cancellationRequested: @escaping @Sendable () -> Bool
        ) {
            self.sessionSeed = sessionSeed
            self.memory = memory
            self.sampleRate = sampleRate
            self.incomingRenderState = incomingRenderState
            self.incomingGraphState = incomingGraphState
            self.previousGraph = previousGraph
            self.planFingerprints = planFingerprints
            self.routeFingerprint = routeFingerprint
            self.incomingContinuationFingerprint = incomingContinuationFingerprint
            self.incomingQualityStateFingerprint = incomingQualityStateFingerprint
            self.previousGraphFingerprint = previousGraphFingerprint
            self.routeRecovery = routeRecovery
            self.routeChannelCount = routeChannelCount
            self.routeGeneration = routeGeneration
            self.cancellationRequested = cancellationRequested
        }
    }

    package static func prepare(candidates: AutonomousPhraseCandidates,
                               sessionSeed: UInt64,
                               memory: TemporalMusicalMemory,
                               sampleRate: Double,
                               incomingRenderState: RenderState,
                               incomingGraphState: GeneratedDSPContinuationState,
                               previousGraph: DSPGraphPlan?,
                               incomingQualityState: QualityContinuationState = QualityContinuationState(),
                               routeRecovery: Bool = false,
                               routeChannelCount: Int = 2,
                               routeGeneration: Int = 0) -> PreparedAutonomousPhrase {
        guard let prepared = prepareTransaction(
            candidates: candidates,
            sessionSeed: sessionSeed,
            memory: memory,
            sampleRate: sampleRate,
            incomingRenderState: incomingRenderState,
            incomingGraphState: incomingGraphState,
            previousGraph: previousGraph,
            incomingQualityState: incomingQualityState,
            routeRecovery: routeRecovery,
            routeChannelCount: routeChannelCount,
            routeGeneration: routeGeneration,
            evaluator: UncalibratedAutonomousCandidateEvaluator(),
            cancellationRequested: { false }
        ) else {
            preconditionFailure("Non-cancellable preparation stopped unexpectedly")
        }
        return prepared
    }

    /// App-facing failable preparation. Cancellation is observed between
    /// candidate renders so a stale route cannot start another expensive pass.
    package static func prepareIfNotCancelled(
        candidates: AutonomousPhraseCandidates,
        sessionSeed: UInt64,
        memory: TemporalMusicalMemory,
        sampleRate: Double,
        incomingRenderState: RenderState,
        incomingGraphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?,
        incomingQualityState: QualityContinuationState = QualityContinuationState(),
        routeRecovery: Bool = false,
        routeChannelCount: Int = 2,
        routeGeneration: Int = 0,
        cancellationRequested: @escaping @Sendable () -> Bool = { Task.isCancelled }
    ) -> PreparedAutonomousPhrase? {
        prepareTransaction(
            candidates: candidates,
            sessionSeed: sessionSeed,
            memory: memory,
            sampleRate: sampleRate,
            incomingRenderState: incomingRenderState,
            incomingGraphState: incomingGraphState,
            previousGraph: previousGraph,
            incomingQualityState: incomingQualityState,
            routeRecovery: routeRecovery,
            routeChannelCount: routeChannelCount,
            routeGeneration: routeGeneration,
            evaluator: UncalibratedAutonomousCandidateEvaluator(),
            cancellationRequested: cancellationRequested
        )
    }

    package static func prepare<E: AutonomousCandidateEvaluating>(
        candidates: AutonomousPhraseCandidates,
        sessionSeed: UInt64,
        memory: TemporalMusicalMemory,
        sampleRate: Double,
        incomingRenderState: RenderState,
        incomingGraphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?,
        incomingQualityState: QualityContinuationState = QualityContinuationState(),
        routeRecovery: Bool = false,
        routeChannelCount: Int = 2,
        routeGeneration: Int = 0,
        evaluator: E
    ) -> PreparedAutonomousPhrase {
        guard let prepared = prepareTransaction(
            candidates: candidates,
            sessionSeed: sessionSeed,
            memory: memory,
            sampleRate: sampleRate,
            incomingRenderState: incomingRenderState,
            incomingGraphState: incomingGraphState,
            previousGraph: previousGraph,
            incomingQualityState: incomingQualityState,
            routeRecovery: routeRecovery,
            routeChannelCount: routeChannelCount,
            routeGeneration: routeGeneration,
            evaluator: evaluator,
            cancellationRequested: { false }
        ) else {
            preconditionFailure("Non-cancellable preparation stopped unexpectedly")
        }
        return prepared
    }

    package static func prepareIfNotCancelled<E: AutonomousCandidateEvaluating>(
        candidates: AutonomousPhraseCandidates,
        sessionSeed: UInt64,
        memory: TemporalMusicalMemory,
        sampleRate: Double,
        incomingRenderState: RenderState,
        incomingGraphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?,
        incomingQualityState: QualityContinuationState = QualityContinuationState(),
        routeRecovery: Bool = false,
        routeChannelCount: Int = 2,
        routeGeneration: Int = 0,
        evaluator: E,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> PreparedAutonomousPhrase? {
        prepareTransaction(
            candidates: candidates,
            sessionSeed: sessionSeed,
            memory: memory,
            sampleRate: sampleRate,
            incomingRenderState: incomingRenderState,
            incomingGraphState: incomingGraphState,
            previousGraph: previousGraph,
            incomingQualityState: incomingQualityState,
            routeRecovery: routeRecovery,
            routeChannelCount: routeChannelCount,
            routeGeneration: routeGeneration,
            evaluator: evaluator,
            cancellationRequested: cancellationRequested
        )
    }

    private static func prepareTransaction<E: AutonomousCandidateEvaluating>(
        candidates: AutonomousPhraseCandidates,
        sessionSeed: UInt64,
        memory: TemporalMusicalMemory,
        sampleRate: Double,
        incomingRenderState: RenderState,
        incomingGraphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?,
        incomingQualityState: QualityContinuationState,
        routeRecovery: Bool,
        routeChannelCount: Int,
        routeGeneration: Int,
        evaluator: E,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> PreparedAutonomousPhrase? {
        let incomingControllerFingerprint = automaticMixControllerFingerprint(
            incomingRenderState
        )
        let qualityStateHasNoObservation = incomingQualityState.revision == 0 &&
            incomingQualityState.observedCandidateFingerprint == nil &&
            incomingQualityState.observedEvidenceFingerprint == nil &&
            incomingQualityState.observedControllerStateFingerprint == nil
        let incomingControllerStateIsCoherent = qualityStateHasNoObservation
            ? incomingRenderState.automaticMixState.kickCorrectionDB ==
                AutomaticMixBalancer.homeKickCorrectionDB
            : incomingQualityState.observedControllerStateFingerprint ==
                incomingControllerFingerprint
        guard !cancellationRequested(), sampleRate.isFinite,
              sampleRate >= QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <= QualityQualificationContract.maximumSupportedSampleRate,
              routeChannelCount ==
                QualityQualificationContract.requiredRouteChannelCount,
              routeGeneration >= 0,
              memory.topologyRevision < Int.max,
              candidates.primary.startBar == memory.totalBars,
              candidates.primary.startBar == incomingRenderState.barIndex,
              candidates.primary.phraseIndex <
                Int.max - memory.topologyRevision,
              sessionSeed &+ 17 == candidates.primary.scene.seed,
              incomingQualityState.acceptanceProvenanceComplete,
              incomingControllerStateIsCoherent,
              candidateDebtsMatchMemory(candidates, memory: memory),
              candidateInputsAreBounded(candidates),
              candidateCharactersMatchSession(
                  candidates,
                  memory: memory,
                  sessionSeed: sessionSeed
              ),
              continuationInputsAreBounded(
                  renderState: incomingRenderState,
                  graphState: incomingGraphState,
                  previousGraph: previousGraph,
                  sessionSeed: sessionSeed,
                  routeRecovery: routeRecovery,
                  phraseIndex: candidates.primary.phraseIndex
              ) else {
            return nil
        }
        let planFingerprints = AutonomousCandidatePlanFingerprints.make(
            candidates: candidates
        )
        let previousGraphFingerprint = previousGraph.map {
            AutonomousCandidateFingerprint.graph($0)
        } ?? "none"
        guard let incomingContinuationFingerprint =
            AutonomousCandidateContinuationFingerprint.make(
                renderState: incomingRenderState,
                generatedDSPState: incomingGraphState,
                qualityState: incomingQualityState,
                topologyRevision: memory.topologyRevision,
                previousGraphFingerprint: previousGraphFingerprint,
                routeRecovery: routeRecovery,
                cancellationRequested: cancellationRequested
            )?.combined else { return nil }
        let incomingQualityStateFingerprint =
            AutonomousCandidateFingerprint.qualityState(incomingQualityState)
        let routeFingerprint = AutonomousCandidateFingerprint.route(
            sampleRate: sampleRate,
            channelCount: routeChannelCount,
            generation: routeGeneration
        )
        var correctionBudget = AutonomousCorrectionBudget()
        var renderPassBudget = AutonomousRenderPassBudget()
        var attempts: [AutonomousCandidateAttempt] = []
        attempts.reserveCapacity(QualityQualificationContract.maximumRenderPasses)
        let renderContext = CandidateRenderContext(
            sessionSeed: sessionSeed,
            memory: memory,
            sampleRate: sampleRate,
            incomingRenderState: incomingRenderState,
            incomingGraphState: incomingGraphState,
            previousGraph: previousGraph,
            planFingerprints: planFingerprints,
            routeFingerprint: routeFingerprint,
            incomingContinuationFingerprint: incomingContinuationFingerprint,
            incomingQualityStateFingerprint: incomingQualityStateFingerprint,
            previousGraphFingerprint: previousGraphFingerprint,
            routeRecovery: routeRecovery,
            routeChannelCount: routeChannelCount,
            routeGeneration: routeGeneration,
            cancellationRequested: cancellationRequested
        )

        func product(
            plan: AutonomousPhrasePlan,
            slot: AutonomousCandidateSlot,
            kind: AutonomousCandidateAttemptKind = .initialRender,
            forceSafeGraph: Bool = false,
            forceHomeUpperTimbre: Bool = false
        ) -> CandidateRenderProduct? {
            guard !renderContext.cancellationRequested(),
                  renderPassBudget.claim() else {
                return nil
            }
            guard let rendered = renderAttempt(
                plan: plan,
                slot: slot,
                kind: kind,
                sessionSeed: renderContext.sessionSeed,
                memory: renderContext.memory,
                sampleRate: renderContext.sampleRate,
                incomingRenderState: renderContext.incomingRenderState,
                incomingGraphState: renderContext.incomingGraphState,
                previousGraph: renderContext.previousGraph,
                planFingerprint: renderContext.planFingerprints[slot],
                routeFingerprint: renderContext.routeFingerprint,
                incomingContinuationFingerprint:
                    renderContext.incomingContinuationFingerprint,
                incomingQualityStateFingerprint:
                    renderContext.incomingQualityStateFingerprint,
                incomingKickCorrectionDB:
                    renderContext.incomingRenderState.automaticMixState
                        .kickCorrectionDB,
                incomingTopologyRevision: renderContext.memory.topologyRevision,
                previousGraphFingerprint: renderContext.previousGraphFingerprint,
                routeRecovery: renderContext.routeRecovery,
                routeChannelCount: renderContext.routeChannelCount,
                routeGeneration: renderContext.routeGeneration,
                forceSafeGraph: forceSafeGraph,
                forceHomeUpperTimbre: forceHomeUpperTimbre,
                cancellationRequested: renderContext.cancellationRequested
            ) else { return nil }
            return renderContext.cancellationRequested() ? nil : rendered
        }

        guard let initialPrimary = product(
            plan: candidates.primary,
            slot: .primary
        ) else { return nil }
        attempts.append(initialPrimary.attempt)
        var primaryVector = initialPrimary.vector
        var primaryAttemptIndex = 0
        var primaryProduct: CandidateRenderProduct? =
            initialPrimary.vector.selectionEvidence.safetyValid &&
            initialPrimary.vector.selectionEvidence.symbolicValid
                ? initialPrimary : nil

        var alternateVector: AutonomousCandidateEvaluationVector?
        var alternateAttemptIndex: Int?
        var alternateProduct: CandidateRenderProduct?
        var comparison: AutonomousQualityComparison = .unavailable

        let qualityComparisonRequested = evaluator.requestsPairedComparison(
            after: primaryVector
        )
        let primaryNeedsAlternate = AutonomousCandidateSelector.needsAlternate(
            primary: primaryVector.selectionEvidence,
            qualityComparisonAvailable: qualityComparisonRequested
        ) || (!routeRecovery && evaluator.requestsHomeUpperTimbreCorrection(
            for: primaryVector,
            slot: .primary
        ))
        if primaryNeedsAlternate {
            guard let initialAlternate = product(
                plan: candidates.alternate,
                slot: .alternate
            ) else { return nil }
            attempts.append(initialAlternate.attempt)
            alternateVector = initialAlternate.vector
            alternateAttemptIndex = attempts.count - 1
            let evidence = initialAlternate.vector.selectionEvidence
            alternateProduct = evidence.symbolicValid && evidence.safetyValid
                ? initialAlternate : nil
        }

        if qualityComparisonRequested, let alternateVector {
            comparison = evaluator.compare(
                primary: primaryVector,
                alternate: alternateVector
            )
        }

        var selectedSlot = selectedCandidateSlot(
            primary: primaryVector,
            alternate: alternateVector,
            comparison: comparison
        )

        let primaryRepairable = !routeRecovery &&
            evaluator.requestsHomeUpperTimbreCorrection(
                for: primaryVector,
                slot: .primary
            )
        let alternateRepairable = !routeRecovery && (alternateVector.map {
            evaluator.requestsHomeUpperTimbreCorrection(
                for: $0,
                slot: .alternate
            )
        } ?? false)
        let correctionSlot = AutonomousCandidateCorrectionPolicy.choose(
            selectedSlot: selectedSlot,
            primaryRepairable: primaryRepairable,
            alternateRepairable: alternateRepairable
        )

        if let correctionSlot, correctionBudget.claim() {
            let correctionPlan = correctionSlot == .primary
                ? candidates.primary : candidates.alternate
            guard let corrected = product(
                plan: correctionPlan,
                slot: correctionSlot,
                kind: .correctionRender,
                forceHomeUpperTimbre: true
            ) else { return nil }
            attempts.append(corrected.attempt)
            let correctedEvidence = corrected.vector.selectionEvidence
            if correctedEvidence.symbolicValid && correctedEvidence.safetyValid {
                if correctionSlot == .primary {
                    primaryVector = corrected.vector
                    primaryAttemptIndex = attempts.count - 1
                    primaryProduct = corrected
                } else {
                    alternateVector = corrected.vector
                    alternateAttemptIndex = attempts.count - 1
                    alternateProduct = corrected
                }
            }
            if qualityComparisonRequested, let alternateVector {
                comparison = evaluator.compare(
                    primary: primaryVector,
                    alternate: alternateVector
                )
            }
            selectedSlot = selectedCandidateSlot(
                primary: primaryVector,
                alternate: alternateVector,
                comparison: comparison
            )
        }

        let selected: CandidateRenderProduct
        let selectedAttemptIndex: Int
        switch selectedSlot {
        case .primary:
            guard let primaryProduct else { return nil }
            alternateProduct = nil
            selected = primaryProduct
            selectedAttemptIndex = primaryAttemptIndex
        case .alternate:
            guard let alternateProduct, let alternateAttemptIndex else { return nil }
            primaryProduct = nil
            selected = alternateProduct
            selectedAttemptIndex = alternateAttemptIndex
        case .fallback, .none:
            primaryProduct = nil
            alternateProduct = nil
            guard let fallback = product(
                plan: candidates.fallback,
                slot: .fallback,
                forceSafeGraph: true
            ) else { return nil }
            attempts.append(fallback.attempt)
            selected = fallback
            selectedAttemptIndex = attempts.count - 1
            selectedSlot = .fallback
        }

        guard !cancellationRequested(), attempts.count == renderPassBudget.used else {
            return nil
        }
        let transaction = AutonomousCandidateEvaluationTransaction(
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: evaluator.policyVersion,
            evaluatorVersion: evaluator.evaluatorVersion,
            planFingerprints: planFingerprints,
            attempts: attempts,
            selectedAttemptIndex: selectedAttemptIndex,
            selectedSlot: selectedSlot,
            comparison: transactionComparison(comparison),
            correctionCount: correctionBudget.used
        )
        return finalize(
            selected: selected,
            transaction: transaction,
            incomingQualityState: incomingQualityState,
            evaluator: evaluator
        )
    }

    /// Reject malformed score payloads before fingerprinting, allocating, or
    /// entering any candidate render. The director currently emits 4...16 bars;
    /// this hard ceiling protects future/package callers from unbounded work.
    private static func candidateInputsAreBounded(
        _ candidates: AutonomousPhraseCandidates
    ) -> Bool {
        let sharedPhraseIdentity =
            candidates.alternate.phraseIndex == candidates.primary.phraseIndex &&
            candidates.fallback.phraseIndex == candidates.primary.phraseIndex &&
            candidates.alternate.startBar == candidates.primary.startBar &&
            candidates.fallback.startBar == candidates.primary.startBar &&
            candidates.alternate.kind == candidates.primary.kind &&
            candidates.fallback.kind == .identityReturn &&
            candidates.alternate.scene.seed == candidates.primary.scene.seed &&
            candidates.fallback.scene.seed == candidates.primary.scene.seed &&
            candidates.alternate.dna == candidates.primary.dna &&
            candidates.fallback.dna == candidates.primary.dna
        return sharedPhraseIdentity &&
            candidateIsBounded(candidates.primary, for: .primary) &&
            candidateIsBounded(candidates.alternate, for: .alternate) &&
            candidateIsBounded(candidates.fallback, for: .fallback)
    }

    private static func candidateDebtsMatchMemory(
        _ candidates: AutonomousPhraseCandidates,
        memory: TemporalMusicalMemory
    ) -> Bool {
        guard memory.openDebts.count <= 128 else { return false }
        let openDebtIDs = memory.openDebts.map(\.id)
        func matchesIncomingDebts(_ plan: AutonomousPhrasePlan) -> Bool {
            if plan.kind == .energyRelease {
                return plan.paidDebtIDs == openDebtIDs
            }
            return plan.paidDebtIDs.isEmpty
        }
        return matchesIncomingDebts(candidates.primary) &&
            matchesIncomingDebts(candidates.alternate) &&
            candidates.fallback.paidDebtIDs.isEmpty
    }

    private static func candidateCharactersMatchSession(
        _ candidates: AutonomousPhraseCandidates,
        memory: TemporalMusicalMemory,
        sessionSeed: UInt64
    ) -> Bool {
        func planMatches(_ plan: AutonomousPhrasePlan) -> Bool {
            let expectedCharacter = AutonomousSessionDirector
                .canonicalPerformanceCharacter(
                    kind: plan.kind,
                    rootSeed: sessionSeed,
                    phraseIndex: plan.phraseIndex,
                    recentPerformanceCharacters:
                        memory.recentPerformanceCharacters,
                    alternate: plan.alternate,
                    conservative: plan.conservative
                )
            return plan.resolvedBars.allSatisfy { resolved in
                guard resolved.performanceCharacter == expectedCharacter else {
                    return false
                }
                if plan.conservative {
                    return resolved.foundationBehavior.companion ==
                        resolved.foundationCompanion
                }
                let expectedBehavior = PerformanceCharacterContract
                    .foundationBehavior(
                        for: expectedCharacter,
                        gesture: resolved.arrangementGesture,
                        localBar: resolved.performance.localBar,
                        phraseLength: resolved.performance.phraseLength
                    )
                return resolved.foundationBehavior == expectedBehavior &&
                    resolved.foundationCompanion == expectedBehavior.companion
            }
        }
        return planMatches(candidates.primary) &&
            planMatches(candidates.alternate) &&
            planMatches(candidates.fallback)
    }

    private static func candidateIsBounded(
        _ plan: AutonomousPhrasePlan,
        for slot: AutonomousCandidateSlot
    ) -> Bool {
        let scene = plan.scene
        let dna = plan.dna
        guard plan.phraseIndex >= 0, plan.startBar >= 0,
              (1...QualityQualificationContract.maximumPhraseBars).contains(
                plan.barCount
              ),
              plan.resolvedBars.count == plan.barCount,
              plan.startBar <= Int.max - plan.barCount,
              plan.paidDebtIDs.count <= 128,
              scene.bpm.isFinite,
              scene.bpm == AutonomousSessionDirector.bpm,
              scene.steps.count == 16,
              scene.groove.events.count <= 16 * 4,
              scene.motif.count <= 2,
              scene.sequencer.count <= 6,
              dna.sceneSeed == scene.seed,
              dna.modalDegrees.count <= 12,
              dna.rhythm.kickSteps.count <= 16,
              dna.rhythm.bassSteps.count <= 16,
              dna.rhythm.hatSteps.count <= 16,
              dna.rhythm.accentSteps.count <= 16,
              dna.motif.degrees.count <= 2,
              dna.motif.steps.count == dna.motif.degrees.count,
              dna.characteristicSyncopations.count <= 16,
              dna.foregroundPriority.count <= PerformanceRole.allCases.count,
              plan.endingInterlockState.previousChapters.count <= 2,
              plan.endingNarrativeState.activeSupportingRoles.count <= 3 else {
            return false
        }
        for (index, resolved) in plan.resolvedBars.enumerated() {
            guard resolvedBarIsBounded(
                resolved,
                index: index,
                plan: plan,
                slot: slot
            ) else { return false }
        }
        let canonicalScoreBars = canonicalKickSyntaxBars(for: plan)
        guard kickSyntaxScoreMatchesCanonical(
            plan.resolvedBars,
            canonical: canonicalScoreBars
        ) else { return false }
        guard plan.performanceCharacterEvidence.valid else { return false }
        switch slot {
        case .primary:
            return !plan.alternate && !plan.conservative
        case .alternate:
            return plan.alternate && !plan.conservative
        case .fallback:
            let groovePulseArticulationIsNeutral = plan.resolvedBars.allSatisfy {
                $0.groovePulses.allSatisfy {
                    $0.strikeZone == .middle &&
                        $0.damping == 0.5 &&
                        $0.timbreMicrovariation == 0
                }
            }
            return !plan.alternate && plan.conservative &&
                groovePulseArticulationIsNeutral
        }
    }

    @inline(never)
    private static func resolvedBarIsBounded(
        _ resolved: ResolvedPerformanceBar,
        index: Int,
        plan: AutonomousPhrasePlan,
        slot: AutonomousCandidateSlot
    ) -> Bool {
        let performance = resolved.performance
        let expectedBar = plan.startBar + index
        guard performance.bar == expectedBar else { return false }
        let events = resolved.ensemble.events
        guard events.count <= 16 * 6 else { return false }
        let maximumAtOneStep = resolved.ensemble.intentionalPileup ? 6 : 3
        let occupancy = Dictionary(grouping: events) { event in event.step }
        let kickEventSteps = events.filter { $0.voice == .kick }
            .map(\.step)
            .sorted()
        let kickScoreMatchesRole: Bool
        switch resolved.kickSyntaxRole {
        case .withheld:
            kickScoreMatchesRole = kickEventSteps.isEmpty &&
                resolved.ensemble.kickAnchors.isEmpty
        case .grounded, .recovery:
            kickScoreMatchesRole = !kickEventSteps.isEmpty &&
                kickEventSteps == resolved.ensemble.kickAnchors
        }
        let grooveEvents = events.filter { $0.voice == .groovePulse }
            .sorted { $0.step < $1.step }
        let grooveArticulations = resolved.groovePulses.sorted {
            $0.step < $1.step
        }
        var grooveScoreIsCanonical =
            grooveEvents.count == grooveArticulations.count &&
            Set(grooveEvents.map { event in event.step }).count ==
                grooveEvents.count
        if grooveScoreIsCanonical {
            for eventIndex in grooveEvents.indices {
                if grooveEvents[eventIndex].step !=
                    grooveArticulations[eventIndex].step ||
                    grooveEvents[eventIndex].intensity !=
                    grooveArticulations[eventIndex].intensity {
                    grooveScoreIsCanonical = false
                    break
                }
            }
        }
        let closedHatEvents = Array(events.enumerated().filter {
            $0.element.voice == .percussion
        })
        let canonicalClosedHatDecay = ClosedHatDecayResolver.articulations(
            from: resolved.ensemble,
            conservative: plan.conservative
        )
        let closedHatDecayIsCanonical =
            closedHatEvents.count <=
                AutonomousCandidateEvaluationVector.maximumClosedHatEventsPerBar &&
            resolved.closedHatDecayArticulations == canonicalClosedHatDecay &&
            resolved.closedHatDecayArticulations.count == closedHatEvents.count &&
            Set(resolved.closedHatDecayArticulations.map {
                $0.scoreEventIndex
            }).count == resolved.closedHatDecayArticulations.count
        let canonicalPercussionEchoTexture =
            PercussionEchoTextureResolver.articulation(
                ensemble: resolved.ensemble,
                kind: plan.kind,
                character: resolved.performanceCharacter,
                gesture: resolved.arrangementGesture,
                conservative: plan.conservative
            )
        let percussionEchoTextureIsCanonical =
            resolved.percussionEchoTexture == canonicalPercussionEchoTexture
        let fallbackScoreIsCanonical: Bool
        if slot == .fallback {
            let canonicalEnsemble = AutonomousSessionDirector.ensemblePlan(
                dna: plan.dna,
                bar: performance,
                focus: resolved.ensemble.focusRole,
                release: plan.kind == .energyRelease,
                kind: plan.kind,
                character: resolved.performanceCharacter,
                foundationBehavior: resolved.foundationBehavior,
                companion: resolved.foundationCompanion,
                gear: resolved.percussionGear,
                gesture: resolved.arrangementGesture,
                conservative: true
            )
            let canonicalGrooveEvents = canonicalEnsemble.events.filter {
                $0.voice == .groovePulse
            }
            let canonicalGroovePulses = GroovePulseResolver.articulations(
                from: canonicalEnsemble,
                absoluteBar: expectedBar,
                swingPercent: plan.dna.rhythm.swingPercent,
                percussionGear: resolved.percussionGear,
                eventSeed: performance.eventSeed,
                conservative: true
            )
            fallbackScoreIsCanonical =
                canonicalGrooveEvents == grooveEvents &&
                canonicalGroovePulses == grooveArticulations
        } else {
            fallbackScoreIsCanonical = true
        }
        return performance.phrase == plan.phraseIndex &&
            performance.localBar == index &&
            performance.phraseLength == plan.barCount &&
            performance.roles.count <= PerformanceRole.allCases.count &&
            Set(performance.roles).count == performance.roles.count &&
            performance.transformations.count <=
                MusicalTransformation.allCases.count &&
            Set(performance.transformations).count ==
                performance.transformations.count &&
            performance.accentContour.count == 16 &&
            performance.accentContour.allSatisfy { value in value.isFinite } &&
            occupancy.values.allSatisfy { $0.count <= maximumAtOneStep } &&
            resolved.ensemble.kickAnchors.count <= 16 &&
            Set(resolved.ensemble.kickAnchors).count ==
                resolved.ensemble.kickAnchors.count &&
            resolved.ensemble.kickAnchors.allSatisfy {
                (0..<16).contains($0)
            } && kickEventSteps == resolved.ensemble.kickAnchors &&
            kickScoreMatchesRole && resolved.groovePulses.count <= 8 &&
            Set(resolved.groovePulses.map { pulse in pulse.step }).count ==
                resolved.groovePulses.count && grooveScoreIsCanonical &&
            closedHatDecayIsCanonical && percussionEchoTextureIsCanonical &&
            fallbackScoreIsCanonical
    }

    /// Replays the director's baseline score and the one allowed kick-syntax
    /// post-pass before rendering. This rejects arbitrary kick deletion, stale
    /// anchors, forged roles, and malformed recovery arcs.
    private static func canonicalKickSyntaxBars(
        for plan: AutonomousPhrasePlan
    ) -> [ResolvedPerformanceBar] {
        let baseline = plan.resolvedBars.map { resolved in
            let ensemble = AutonomousSessionDirector.ensemblePlan(
                dna: plan.dna,
                bar: resolved.performance,
                focus: resolved.ensemble.focusRole,
                release: plan.kind == .energyRelease,
                kind: plan.kind,
                character: resolved.performanceCharacter,
                foundationBehavior: resolved.foundationBehavior,
                companion: resolved.foundationCompanion,
                gear: resolved.percussionGear,
                gesture: resolved.arrangementGesture,
                conservative: plan.conservative
            )
            return ResolvedPerformanceBar(
                performance: resolved.performance,
                ensemble: ensemble,
                arrangementGesture: resolved.arrangementGesture,
                percussionGear: resolved.percussionGear,
                performanceCharacter: resolved.performanceCharacter,
                foundationBehavior: resolved.foundationBehavior,
                foundationCompanion: resolved.foundationCompanion,
                pulseEchoEnabled: resolved.pulseEchoEnabled,
                interlockChapter: resolved.interlockChapter,
                groovePulses: GroovePulseResolver.articulations(
                    from: ensemble,
                    absoluteBar: resolved.performance.bar,
                    swingPercent: plan.dna.rhythm.swingPercent,
                    percussionGear: resolved.percussionGear,
                    eventSeed: resolved.performance.eventSeed,
                    conservative: plan.conservative
                ),
                closedHatDecayArticulations: ClosedHatDecayResolver.articulations(
                    from: ensemble,
                    conservative: plan.conservative
                ),
                spatialContrast: resolved.spatialContrast,
                narrative: resolved.narrative,
                kickSyntaxRole: .grounded,
                percussionEchoTexture:
                    PercussionEchoTextureResolver.articulation(
                        ensemble: ensemble,
                        kind: plan.kind,
                        character: resolved.performanceCharacter,
                        gesture: resolved.arrangementGesture,
                        conservative: plan.conservative
                    )
            )
        }
        return KickSyntaxResolver.resolve(
            resolvedBars: baseline,
            kind: plan.kind,
            paidDebtIDs: plan.paidDebtIDs,
            conservative: plan.conservative
        )
    }

    private static func kickSyntaxScoreMatchesCanonical(
        _ actual: [ResolvedPerformanceBar],
        canonical: [ResolvedPerformanceBar]
    ) -> Bool {
        guard actual.count == canonical.count else { return false }
        return zip(actual, canonical).allSatisfy { actualBar, canonicalBar in
            let actualKickEvents = actualBar.ensemble.events.filter {
                $0.voice == .kick
            }
            let canonicalKickEvents = canonicalBar.ensemble.events.filter {
                $0.voice == .kick
            }
            let actualNonKickEvents = actualBar.ensemble.events.filter {
                $0.voice != .kick
            }
            let canonicalNonKickEvents = canonicalBar.ensemble.events.filter {
                $0.voice != .kick
            }
            let syntaxGroovePulsesMatch = actualBar.kickSyntaxRole == .grounded ||
                actualBar.groovePulses == canonicalBar.groovePulses
            return actualBar.kickSyntaxRole == canonicalBar.kickSyntaxRole &&
                actualBar.ensemble.kickAnchors == canonicalBar.ensemble.kickAnchors &&
                actualKickEvents == canonicalKickEvents &&
                actualNonKickEvents == canonicalNonKickEvents &&
                syntaxGroovePulsesMatch
        }
    }

    /// Every continuation collection is owned by a fixed-delay DSP primitive.
    /// Reject package callers that bypass those owners before typed hashing or
    /// rendering can turn an arbitrary collection into unbounded work.
    private static func continuationInputsAreBounded(
        renderState: RenderState,
        graphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?,
        sessionSeed: UInt64,
        routeRecovery: Bool,
        phraseIndex: Int
    ) -> Bool {
        let maximumSampleRate =
            QualityQualificationContract.maximumSupportedSampleRate
        let maximumVoiceEchoFrames = Int(maximumSampleRate * 0.34) + 1
        let maximumVoiceCombFrames = Int(maximumSampleRate * 0.009) + 1
        let maximumVoiceAllPassFrames = Int(maximumSampleRate * 0.005) + 1
        let maximumGraphDelayFrames = Int(maximumSampleRate * 0.42) + 1
        let maximumFDNLineFrames = Int(
            maximumSampleRate *
                FeedbackDelayNetworkConfiguration.maximumDelaySeconds
        ) + 1
        let maximumFDNStorageFrames =
            maximumFDNLineFrames *
                FeedbackDelayNetworkConfiguration.lineCount

        func indexIsValid(_ index: Int, for count: Int) -> Bool {
            count == 0 ? index == 0 : (0..<count).contains(index)
        }
        func voiceIsBounded(_ state: AlienVoiceState) -> Bool {
            state.comb.count <= maximumVoiceCombFrames &&
                state.allPass.count <= maximumVoiceAllPassFrames &&
                state.echo.count <= maximumVoiceEchoFrames &&
                indexIsValid(state.combIndex, for: state.comb.count) &&
                indexIsValid(state.allPassIndex, for: state.allPass.count) &&
                indexIsValid(state.echoIndex, for: state.echo.count)
        }
        func graphPlanIsBounded(_ graph: DSPGraphPlan?) -> Bool {
            guard let graph else { return true }
            let nodeIDs = graph.nodes.map { node in node.id }
            let affectedIDs = graph.mutation?.affectedNodeIDs ?? []
            let affectedIDsMatchTopology = graph.mutation?.kind == .bypass
                ? Set(affectedIDs).isDisjoint(with: Set(nodeIDs))
                : Set(affectedIDs).isSubset(of: Set(nodeIDs))
            return DSPGraphValidator.validate(graph).valid &&
                graph.revision >= 0 && graph.revision < Int.max &&
                graph.nodes.count <= DSPGraphPlan.maximumNodeCount &&
                nodeIDs.allSatisfy { $0 >= 0 && $0 < Int.max } &&
                affectedIDs.count <= 2 &&
                affectedIDsMatchTopology
        }
        func nodeStateIsBounded(_ state: DSPGraphNodeState) -> Bool {
            state.delayLeft.count <= maximumGraphDelayFrames &&
                state.delayRight.count == state.delayLeft.count &&
                indexIsValid(state.writeIndex, for: state.delayLeft.count)
        }
        func spatialFDNStateIsBounded(
            _ state: FeedbackDelayNetworkState
        ) -> Bool {
            if state.storage.isEmpty || state.lineOffsets.isEmpty ||
                state.lineLengths.isEmpty || state.writeIndices.isEmpty ||
                state.dampingStates.isEmpty {
                return state.storage.isEmpty && state.lineOffsets.isEmpty &&
                    state.lineLengths.isEmpty && state.writeIndices.isEmpty &&
                    state.dampingStates.isEmpty
            }
            let lineCount = FeedbackDelayNetworkConfiguration.lineCount
            guard state.storage.count <= maximumFDNStorageFrames,
                  state.lineOffsets.count == lineCount,
                  state.lineLengths.count == lineCount,
                  state.writeIndices.count == lineCount,
                  state.dampingStates.count == lineCount,
                  state.dampingStates.allSatisfy(\.isFinite) else {
                return false
            }
            var expectedOffset = 0
            for line in 0..<lineCount {
                let length = state.lineLengths[line]
                guard state.lineOffsets[line] == expectedOffset,
                      length >= 3, length <= maximumFDNLineFrames,
                      indexIsValid(state.writeIndices[line], for: length),
                      expectedOffset <= state.storage.count - length else {
                    return false
                }
                expectedOffset += length
            }
            return expectedOffset == state.storage.count &&
                zip(
                    state.lineLengths,
                    state.lineLengths.dropFirst()
                ).allSatisfy { $0 < $1 }
        }
        let voices = [
            renderState.alienAnchorState,
            renderState.alienShadowState,
            renderState.alienAtmosphereState,
            renderState.alienResponseState,
            renderState.alienTransitionState,
        ]
        let nodeStatesAreBounded =
            graphState.nodeStates.count <= DSPGraphPlan.maximumNodeCount &&
            graphState.retiringStates.count <= DSPGraphPlan.maximumNodeCount &&
            graphState.nodeStates.values.allSatisfy(nodeStateIsBounded) &&
            graphState.retiringStates.values.allSatisfy(nodeStateIsBounded)
        let currentNodeIDs = Set(graphState.graph?.nodes.map(\.id) ?? [])
        let retiringNodeIDs = Set(graphState.retiringGraph?.nodes.map(\.id) ?? [])
        let graphStatesMatchOwners =
            Set(graphState.nodeStates.keys).isSubset(of: currentNodeIDs) &&
            Set(graphState.retiringStates.keys).isSubset(of: retiringNodeIDs)
        let graphsBelongToSession = [
            previousGraph,
            graphState.graph,
            graphState.retiringGraph,
        ].compactMap { $0 }.allSatisfy { $0.sessionSeed == sessionSeed }
        let graphBoundaryIsCoherent: Bool
        if !routeRecovery {
            graphBoundaryIsCoherent = graphState.graph == previousGraph
        } else {
            switch (graphState.graph, previousGraph) {
            case (nil, nil):
                graphBoundaryIsCoherent = renderState.barIndex == 0
            case (nil, let target?):
                graphBoundaryIsCoherent = renderState.barIndex == 0 &&
                    target.revision == 0 && target.mutation == nil
            case (let incoming?, let target?):
                if incoming.hasSameTopology(as: target) {
                    graphBoundaryIsCoherent = target.mutation == nil
                } else if incoming.revision < Int.max,
                          target.revision == incoming.revision + 1,
                          let mutation = target.mutation,
                          mutation.phraseIndex == phraseIndex {
                    let incomingIDs = Set(incoming.nodes.map(\.id))
                    let targetIDs = Set(target.nodes.map(\.id))
                    let affectedIDs = Set(mutation.affectedNodeIDs)
                    switch mutation.kind {
                    case .insert:
                        graphBoundaryIsCoherent = affectedIDs.isDisjoint(
                            with: incomingIDs
                        ) && affectedIDs.isSubset(of: targetIDs)
                    case .bypass:
                        graphBoundaryIsCoherent = affectedIDs.isSubset(
                            of: incomingIDs
                        ) && affectedIDs.isDisjoint(with: targetIDs)
                    case .replace, .reorder, .rerouteSend:
                        graphBoundaryIsCoherent = affectedIDs.isSubset(
                            of: incomingIDs
                        ) && affectedIDs.isSubset(of: targetIDs)
                    }
                } else {
                    graphBoundaryIsCoherent = false
                }
            case (_?, nil):
                graphBoundaryIsCoherent = false
            }
        }
        let retiringStateIsCoherent: Bool
        if graphState.retiringGraph == nil {
            retiringStateIsCoherent = graphState.retiringBarsRemaining == 0 &&
                graphState.retiringStates.isEmpty
        } else {
            retiringStateIsCoherent = (1...2).contains(
                graphState.retiringBarsRemaining
            )
        }
        return renderState.barIndex >= 0 &&
            renderState.delayBuffer.count <= Int(maximumSampleRate * 0.5) + 1 &&
            indexIsValid(
                renderState.delayWriteIndex,
                for: renderState.delayBuffer.count
            ) &&
            renderState.pulseEchoBuffer.count <= Int(maximumSampleRate * 0.75) + 1 &&
            indexIsValid(
                renderState.pulseEchoWriteIndex,
                for: renderState.pulseEchoBuffer.count
            ) &&
            renderState.earlyReflectionBuffer.count <=
                Int(maximumSampleRate * 0.013) + 1 &&
            indexIsValid(
                renderState.earlyReflectionWriteIndex,
                for: renderState.earlyReflectionBuffer.count
            ) &&
            renderState.chorusDelay.count <= Int(maximumSampleRate * 0.045) + 1 &&
            indexIsValid(
                renderState.chorusWriteIndex,
                for: renderState.chorusDelay.count
            ) &&
            spatialFDNStateIsBounded(renderState.spatialFDNState) &&
            (AutomaticMixBalancer.minimumKickCorrectionDB...0).contains(
                renderState.automaticMixState.kickCorrectionDB
            ) &&
            voices.allSatisfy(voiceIsBounded) &&
            graphPlanIsBounded(previousGraph) &&
            graphPlanIsBounded(graphState.graph) &&
            graphPlanIsBounded(graphState.retiringGraph) &&
            retiringStateIsCoherent &&
            nodeStatesAreBounded && graphStatesMatchOwners &&
            graphsBelongToSession && graphBoundaryIsCoherent
    }

    private static func selectedCandidateSlot(
        primary: AutonomousCandidateEvaluationVector,
        alternate: AutonomousCandidateEvaluationVector?,
        comparison: AutonomousQualityComparison
    ) -> AutonomousCandidateSlot? {
        let choice = AutonomousCandidateSelector.choose(
            primary: primary.selectionEvidence,
            alternate: alternate?.selectionEvidence,
            qualityComparison: comparison
        )
        switch choice {
        case .primary: return .primary
        case .alternate: return .alternate
        case .fallback: return nil
        }
    }

    private static func transactionComparison(
        _ comparison: AutonomousQualityComparison
    ) -> AutonomousCandidateComparison {
        switch comparison {
        case .unavailable: .unavailable
        case .primary: .primary
        case .alternate: .alternate
        case .tie: .tie
        case .fallback: .fallback
        }
    }

    private final class CandidateRenderProduct: Sendable {
        let slot: AutonomousCandidateSlot
        let plan: AutonomousPhrasePlan
        let graph: DSPGraphPlan
        let blocks: [RenderBlock]
        let endingRenderState: RenderState
        let endingGraphState: GeneratedDSPContinuationState
        let audioPreflight: PhraseAudioPreflight
        let vector: AutonomousCandidateEvaluationVector
        let attempt: AutonomousCandidateAttempt

        init(
            slot: AutonomousCandidateSlot,
            plan: AutonomousPhrasePlan,
            graph: DSPGraphPlan,
            blocks: [RenderBlock],
            endingRenderState: RenderState,
            endingGraphState: GeneratedDSPContinuationState,
            audioPreflight: PhraseAudioPreflight,
            vector: AutonomousCandidateEvaluationVector,
            attempt: AutonomousCandidateAttempt
        ) {
            self.slot = slot
            self.plan = plan
            self.graph = graph
            self.blocks = blocks
            self.endingRenderState = endingRenderState
            self.endingGraphState = endingGraphState
            self.audioPreflight = audioPreflight
            self.vector = vector
            self.attempt = attempt
        }
    }

    private static func renderAttempt(
        plan: AutonomousPhrasePlan,
        slot: AutonomousCandidateSlot,
        kind: AutonomousCandidateAttemptKind,
        sessionSeed: UInt64,
        memory: TemporalMusicalMemory,
        sampleRate: Double,
        incomingRenderState: RenderState,
        incomingGraphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?,
        planFingerprint: String,
        routeFingerprint: String,
        incomingContinuationFingerprint: String,
        incomingQualityStateFingerprint: String,
        incomingKickCorrectionDB: Double,
        incomingTopologyRevision: Int,
        previousGraphFingerprint: String,
        routeRecovery: Bool,
        routeChannelCount: Int,
        routeGeneration: Int,
        forceSafeGraph: Bool = false,
        forceHomeUpperTimbre: Bool = false,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> CandidateRenderProduct? {
        guard !cancellationRequested() else { return nil }
        let safeGraphSource = routeRecovery ? incomingGraphState.graph : previousGraph
        let proposedGraph = forceSafeGraph
            ? safeGraphSource.map {
                DSPGraphPlan(
                    sessionSeed: $0.sessionSeed,
                    revision: $0.revision,
                    nodes: $0.nodes,
                    mutation: nil,
                    lowEndProtected: $0.lowEndProtected,
                    protectedRouting: $0.protectedRouting
                )
            } ?? DSPGraphGenerator.safePlan(sessionSeed: sessionSeed)
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
        let homeTimbreFallback = routeRecovery || forceHomeUpperTimbre
        guard let blocks = AutonomousPhraseRenderer.renderIfNotCancelled(
            plan: plan, graph: graph, sampleRate: sampleRate,
            state: &renderState, graphState: &graphState,
            forceHomeUpperTimbre: homeTimbreFallback,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        guard !cancellationRequested() else { return nil }
        guard let audioPreflight = PhraseAudioPreflight(
            blocks: blocks,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        let timbreEvidence = UpperTimbreEvidence.aggregating(
            blocks.map(\.postGraphRemainderTimbreEvidence)
        )
        guard !cancellationRequested() else { return nil }
        guard let outgoingRenderDSPFingerprint =
            AutonomousCandidateFingerprint.renderDSPContinuation(
                renderState: renderState,
                generatedDSPState: graphState,
                cancellationRequested: cancellationRequested
            ) else { return nil }
        let controllerFingerprint = automaticMixControllerFingerprint(renderState)
        let graphFingerprint = AutonomousCandidateFingerprint.graph(graph)
        guard !cancellationRequested() else { return nil }
        guard let vector = AutonomousCandidateEvaluationVector.make(
            slot: slot,
            plan: plan,
            graph: graph,
            planFingerprint: planFingerprint,
            graphFingerprint: graphFingerprint,
            blocks: blocks,
            audioPreflight: audioPreflight,
            upperTimbreEvidence: timbreEvidence,
            sampleRate: sampleRate,
            routeChannelCount: routeChannelCount,
            routeGeneration: routeGeneration,
            routeFingerprint: routeFingerprint,
            incomingContinuationFingerprint: incomingContinuationFingerprint,
            incomingQualityStateFingerprint: incomingQualityStateFingerprint,
            incomingKickCorrectionDB: incomingKickCorrectionDB,
            incomingTopologyRevision: incomingTopologyRevision,
            previousGraphFingerprint: previousGraphFingerprint,
            routeRecovery: routeRecovery,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            controllerStateFingerprint: controllerFingerprint,
            incomingDramaticDebts: memory.openDebts,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        guard !cancellationRequested() else { return nil }
        let attempt = AutonomousCandidateAttempt(
            kind: kind,
            forceSafeGraph: forceSafeGraph,
            forceHomeUpperTimbre: homeTimbreFallback,
            reasonCodes: attemptReasonCodes(
                plan: plan,
                blocks: blocks,
                audioPreflight: audioPreflight,
                upperTimbreEvidence: timbreEvidence,
                vector: vector
            ),
            vector: vector
        )
        return CandidateRenderProduct(
            slot: slot,
            plan: plan,
            graph: graph,
            blocks: blocks,
            endingRenderState: renderState,
            endingGraphState: graphState,
            audioPreflight: audioPreflight,
            vector: vector,
            attempt: attempt
        )
    }

    private static func attemptReasonCodes(
        plan: AutonomousPhrasePlan,
        blocks: [RenderBlock],
        audioPreflight: PhraseAudioPreflight,
        upperTimbreEvidence: UpperTimbreEvidence,
        vector: AutonomousCandidateEvaluationVector
    ) -> [QualityReasonCode] {
        var reasons: [QualityReasonCode] = []
        if blocks.isEmpty || !vector.isComplete {
            reasons.append(.evidenceMissingV1)
        }
        if !audioPreflight.quality.finite || !upperTimbreEvidence.finite ||
            !vector.isFinite {
            reasons.append(.evidenceNonFiniteV1)
        }
        if blocks.isEmpty || !plan.interest.valid || !audioPreflight.safetyValid ||
            !upperTimbreEvidence.finite || !vector.hardGatesPassed {
            reasons.append(.hardGateFailedV1)
        }
        return reasons
    }

    private static func automaticMixControllerFingerprint(
        _ state: RenderState
    ) -> String {
        AutonomousCandidateFingerprint.automaticMixController(
            kickCorrectionDB: state.automaticMixState.kickCorrectionDB
        )
    }

    private static func finalize<E: AutonomousCandidateEvaluating>(
        selected: CandidateRenderProduct,
        transaction: AutonomousCandidateEvaluationTransaction,
        incomingQualityState: QualityContinuationState,
        evaluator: E
    ) -> PreparedAutonomousPhrase {
        let verdict = evaluator.terminalVerdict(
            selected: selected.vector,
            transaction: transaction
        )
        var reasonCodes = verdict.reasonCodes + selected.attempt.reasonCodes
        if selected.slot == .fallback {
            reasonCodes.append(.conservativeFallbackV1)
        }
        if selected.vector.routeContinuation.routeRecovery {
            // Fresh evidence from the replacement route is not stale. This
            // operational reason preserves recovery provenance without making
            // an otherwise qualified regenerated phrase non-compensable.
            reasonCodes.append(.routeRecoveryV1)
        }
        if !transaction.isComplete {
            reasonCodes.append(contentsOf: [
                .evidenceMissingV1,
                .hardGateFailedV1,
            ])
        }
        let boundCandidateEvaluation = BoundCandidateEvaluation(transaction)
        let transactionFingerprint = boundCandidateEvaluation.fingerprint
        let proposedDecision = QualityDecision(
            policyVersion: evaluator.policyVersion,
            outcome: verdict.outcome,
            reasonCodes: reasonCodes,
            candidateFingerprint: selected.vector.fullMix.sampleHash,
            evidenceFingerprint: transactionFingerprint
        )
        let outgoingQuality = incomingQualityState.recording(
            decision: proposedDecision,
            evidenceFingerprint: transactionFingerprint,
            controllerStateFingerprint:
                selected.vector.routeContinuation.controllerStateFingerprint
        )
        let commitProvenance = AutonomousPreparedCommitProvenance(
            candidateEvaluationFingerprint: transactionFingerprint,
            selectedSampleHash: selected.vector.fullMix.sampleHash,
            outgoingRenderDSPFingerprint:
                selected.vector.routeContinuation.outgoingRenderDSPFingerprint,
            qualityState: outgoingQuality
        )
        return PreparedAutonomousPhrase(
            plan: selected.plan,
            graph: selected.graph,
            blocks: selected.blocks,
            endingRenderState: selected.endingRenderState,
            endingGraphState: selected.endingGraphState,
            audioPreflight: selected.audioPreflight,
            upperTimbreEvidence: selected.vector.postGraphUpperTimbreEvidence,
            selectedCandidateEvidence: selected.vector,
            boundCandidateEvaluation: boundCandidateEvaluation,
            commitProvenance: commitProvenance,
            qualityDecision: outgoingQuality.lastDecision,
            incomingQualityState: incomingQualityState,
            qualityContinuationState: outgoingQuality,
            correctionRenderCount: transaction.correctionCount,
            usedAlternate: selected.slot == .alternate,
            usedFallback: selected.slot == .fallback,
            usedHomeTimbreFallback: selected.attempt.forceHomeUpperTimbre
        )
    }
}
