import Foundation

package enum LongHorizonEffectCarrierSchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier =
        "autotechno-long-horizon-effect-carrier.v1"
    package static let nonCarrierDose = 0.35
}

package enum LongHorizonEffectCarrierStatus: String, Codable, Sendable {
    case unselected
    case active
}

/// World-bound selection committed only through the canonical continuation.
/// A phrase may propose a carrier, but retries cannot mutate the held state.
package struct LongHorizonEffectCarrierState: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let worldID: UInt64
    package let status: LongHorizonEffectCarrierStatus
    package let role: SynthRole?
    package let selectedAtPhraseIndex: Int?

    package init(
        worldID: UInt64,
        status: LongHorizonEffectCarrierStatus,
        role: SynthRole?,
        selectedAtPhraseIndex: Int?
    ) {
        schemaVersion = LongHorizonEffectCarrierSchema.schemaVersion
        schemaIdentifier = LongHorizonEffectCarrierSchema.schemaIdentifier
        self.worldID = worldID
        let selectionIsValid = status == .active && role != nil &&
            selectedAtPhraseIndex.map { $0 >= 0 } == true
        self.status = selectionIsValid ? .active : .unselected
        self.role = selectionIsValid ? role : nil
        self.selectedAtPhraseIndex = selectionIsValid
            ? selectedAtPhraseIndex : nil
    }

    package static func unselected(
        worldID: UInt64
    ) -> LongHorizonEffectCarrierState {
        LongHorizonEffectCarrierState(
            worldID: worldID,
            status: .unselected,
            role: nil,
            selectedAtPhraseIndex: nil
        )
    }

    package var isValid: Bool {
        schemaVersion == LongHorizonEffectCarrierSchema.schemaVersion &&
            schemaIdentifier == LongHorizonEffectCarrierSchema.schemaIdentifier &&
            ((status == .active && role != nil &&
                selectedAtPhraseIndex.map { $0 >= 0 } == true) ||
             (status == .unselected && role == nil &&
                selectedAtPhraseIndex == nil))
    }
}

package struct LongHorizonEffectCarrierArticulation: Equatable, Sendable {
    package let state: LongHorizonEffectCarrierState
    package let active: Bool
    package let carrierDose: Double
    package let nonCarrierDose: Double
    package let requestedTarget: EffectWorldTarget

    package static let neutral = LongHorizonEffectCarrierArticulation(
        state: .unselected(worldID: 0),
        active: false,
        requestedTarget: .neutral
    )

    package init(
        state: LongHorizonEffectCarrierState,
        active: Bool,
        requestedTarget: EffectWorldTarget
    ) {
        self.state = state
        self.active = active && state.isValid && state.status == .active &&
            state.role != nil
        carrierDose = self.active ? 1 : 0
        nonCarrierDose = self.active
            ? LongHorizonEffectCarrierSchema.nonCarrierDose : 0
        self.requestedTarget = self.active ? requestedTarget : .neutral
    }

    package func dose(for role: SynthRole) -> Double {
        guard active, let carrier = state.role else { return 0 }
        return role == carrier ? carrierDose : nonCarrierDose
    }

    package func target(
        for role: SynthRole,
        assignment: InstrumentAssignment
    ) -> EffectWorldTarget {
        let dose = dose(for: role)
        guard dose > 0, assignment.isValid else { return .neutral }
        let requested = requestedTarget.interpolated(
            from: .neutral,
            progress: dose
        )
        let permissions = Set(assignment.effects)
        let automation = assignment.automation
        func permitted(
            _ value: Double,
            neutral: Double,
            enabled: Bool,
            automationAmount: Double
        ) -> Double {
            guard enabled else { return neutral }
            let amount = min(1, max(0, 0.55 + automationAmount * 0.45))
            return neutral + (value - neutral) * amount
        }
        return EffectWorldTarget(
            spectralFocus: permitted(
                requested.spectralFocus,
                neutral: EffectWorldTarget.neutral.spectralFocus,
                enabled: permissions.contains(.drive) || permissions.contains(.comb),
                automationAmount: automation.color
            ),
            nonlinearPressure: permitted(
                requested.nonlinearPressure,
                neutral: EffectWorldTarget.neutral.nonlinearPressure,
                enabled: permissions.contains(.drive),
                automationAmount: automation.shape
            ),
            modulationMotion: permitted(
                requested.modulationMotion,
                neutral: EffectWorldTarget.neutral.modulationMotion,
                enabled: permissions.contains(.chorus) || permissions.contains(.comb) ||
                    permissions.contains(.unsyncedEcho),
                automationAmount: automation.motion
            ),
            echoMemory: permitted(
                requested.echoMemory,
                neutral: EffectWorldTarget.neutral.echoMemory,
                enabled: permissions.contains(.unsyncedEcho) ||
                    permissions.contains(.pulseEcho),
                automationAmount: automation.space
            ),
            spatialDepth: permitted(
                requested.spatialDepth,
                neutral: EffectWorldTarget.neutral.spatialDepth,
                enabled: permissions.contains(.filteredReverb),
                automationAmount: automation.space
            )
        )
    }
}

package enum LongHorizonEffectCarrierResolver {
    package static func resolve(
        incoming: LongHorizonEffectCarrierState,
        materialWorld: LongHorizonMaterialWorldPlan,
        phraseIndex: Int,
        phraseKind: AutonomousPhraseKind,
        synthPerformance: SynthPerformancePlan
    ) -> LongHorizonEffectCarrierArticulation {
        guard materialWorld.worldID != 0,
              materialWorld.polymetricGrammar.isValid,
              incoming.isValid else { return .neutral }
        let normalized = incoming.worldID == materialWorld.worldID
            ? incoming : .unselected(worldID: materialWorld.worldID)
        let selected: LongHorizonEffectCarrierState
        if normalized.status == .active {
            selected = normalized
        } else {
            let activeRoles = Set(
                synthPerformance.bars.flatMap(\.upperNotes).map(\.role)
            )
            guard let role = priority(for: materialWorld.axes.roles).first(
                where: activeRoles.contains
            ) else {
                selected = normalized
                return LongHorizonEffectCarrierArticulation(
                    state: selected,
                    active: false,
                    requestedTarget: materialWorld.axes.effect
                )
            }
            selected = LongHorizonEffectCarrierState(
                worldID: materialWorld.worldID,
                status: .active,
                role: role,
                selectedAtPhraseIndex: phraseIndex
            )
        }
        let eligibleNow = selected.role.map { role in
            synthPerformance.bars.contains { !$0.upperNotes(for: role).isEmpty }
        } == true
        return LongHorizonEffectCarrierArticulation(
            state: selected,
            active: phraseKind != .identityReturn && eligibleNow,
            requestedTarget: materialWorld.axes.effect
        )
    }

    private static func priority(
        for hierarchy: LongHorizonRoleHierarchy
    ) -> [SynthRole] {
        switch hierarchy {
        case .protagonistLed:
            [.anchor, .response, .shadow, .transition, .atmosphere]
        case .atmosphereLed:
            [.atmosphere, .transition, .response, .shadow, .anchor]
        case .percussionLed:
            [.response, .transition, .shadow, .anchor, .atmosphere]
        case .foundationLed:
            [.shadow, .anchor, .response, .atmosphere, .transition]
        }
    }
}
