import AutoTechnoCore
import Foundation

/// Pointer identity lives only during one synchronous snapshot. Reports never
/// expose addresses or retain PCM. Capacity includes unused allocated elements.
package struct NumericStorageOwnerRecord: Codable, Equatable, Sendable {
    package let owner: String
    package let elementCount: Int
    package let elementCapacity: Int
    package let elementStride: Int
    package let capacityBytes: Int
    package let aliasOf: String?
}

package struct NumericStorageSnapshot: Codable, Equatable, Sendable {
    package let phase: String
    /// Set only for a conditional group maximum of this physical phase.
    package let observedPhase: String?
    package let bar: Int
    package let uniqueBufferCapacityBytes: Int
    /// Existing typed scalar/field encoding headroom, separate from actual
    /// numeric buffers. It is not actual heap/dictionary/allocator attribution.
    package let typedMetadataHeadroomBytes: Int
    package let ownerRecords: [NumericStorageOwnerRecord]
    package let valid: Bool
    package var numericPlusTypedHeadroomBytes: Int {
        let total = uniqueBufferCapacityBytes.addingReportingOverflow(typedMetadataHeadroomBytes)
        return total.overflow ? Int.max : total.partialValue
    }
}

/// Detached-only, single-writer registration through nonescaping borrows.
/// Original owners must remain alive for the complete snapshot. A new inventory
/// is required for each phase: addresses can be reused after old buffers die.
package final class NumericStorageInventory {
    package static let maximumOwnerCount = 4_096
    private struct Buffer { let owner: String; var bytes: Int }
    private var seen: [UInt: Buffer] = [:]
    private var records: [NumericStorageOwnerRecord] = []
    package private(set) var uniqueBufferCapacityBytes = 0
    package private(set) var typedMetadataHeadroomBytes = 0
    package private(set) var valid = true

    package func register(_ samples: [Float], owner: String) { registerBuffer(samples, owner: owner) }
    package func register(_ samples: [Double], owner: String) { registerBuffer(samples, owner: owner) }
    package func register(_ samples: [Int], owner: String) { registerBuffer(samples, owner: owner) }
    package func register(_ samples: [Int64], owner: String) { registerBuffer(samples, owner: owner) }
    package func register(_ samples: [UInt64], owner: String) { registerBuffer(samples, owner: owner) }
    package func register(_ samples: [UInt8], owner: String) { registerBuffer(samples, owner: owner) }

    private func registerBuffer<Element>(_ samples: [Element], owner: String) {
        guard valid, records.count < Self.maximumOwnerCount,
            !owner.isEmpty, owner.utf8.count <= 256 else { valid = false; return }
        let stride = MemoryLayout<Element>.stride
        let bytes = samples.capacity.multipliedReportingOverflow(by: stride)
        guard stride > 0, !bytes.overflow else { valid = false; return }
        var alias: String?
        samples.withUnsafeBufferPointer { buffer in
            guard samples.capacity > 0 else { return }
            guard let base = buffer.baseAddress else { valid = false; return }
            let identity = UInt(bitPattern: base)
            if var previous = seen[identity] {
                alias = previous.owner
                // Equal storage can be presented through immutable views;
                // conservatively retain the largest declared capacity.
                if bytes.partialValue > previous.bytes {
                    let growth = bytes.partialValue - previous.bytes
                    add(growth, to: &uniqueBufferCapacityBytes)
                    previous.bytes = bytes.partialValue
                    seen[identity] = previous
                }
            } else {
                seen[identity] = Buffer(owner: owner, bytes: bytes.partialValue)
                add(bytes.partialValue, to: &uniqueBufferCapacityBytes)
            }
        }
        records.append(NumericStorageOwnerRecord(owner: owner,
            elementCount: samples.count, elementCapacity: samples.capacity,
            elementStride: stride, capacityBytes: bytes.partialValue, aliasOf: alias))
    }

    package func addTypedMetadataHeadroom(_ bytes: Int) {
        add(bytes, to: &typedMetadataHeadroomBytes)
    }

    private func add(_ bytes: Int, to total: inout Int) {
        let result = total.addingReportingOverflow(bytes)
        guard bytes >= 0, !result.overflow else { valid = false; return }
        total = result.partialValue
    }

    package func snapshot(phase: String, bar: Int) -> NumericStorageSnapshot {
        NumericStorageSnapshot(phase: phase, observedPhase: nil, bar: bar,
            uniqueBufferCapacityBytes: uniqueBufferCapacityBytes,
            typedMetadataHeadroomBytes: typedMetadataHeadroomBytes,
            ownerRecords: records, valid: valid &&
                !uniqueBufferCapacityBytes.addingReportingOverflow(typedMetadataHeadroomBytes).overflow)
    }
}

/// Optional diagnostic measurement, never quality/policy/admission authority.
/// It retains one maximum snapshot per declared phase, not PCM or raw pointers.
/// It does not cover unobserved transients, analysis, external source ownership,
/// encoding/metadata heap overhead, writer chunks, RSS or deadlines implicitly.
package final class PreparationWorkingStorageProbe: @unchecked Sendable {
    private var maxima: [String: NumericStorageSnapshot] = [:]
    package private(set) var valid = true
    package private(set) var observationCount = 0
    /// Physical observations only; conditional maxima do not increment this map.
    package private(set) var phaseObservationCounts: [String: Int] = [:]
    package var snapshots: [NumericStorageSnapshot] {
        maxima.keys.sorted().compactMap { maxima[$0] }
    }
    package static let maximumPhaseCount = 32

    package func observe(phase: String, bar: Int,
        additionalMaximumPhase: String? = nil,
        register: (NumericStorageInventory) -> Void) {
        let names = Set([phase] + (additionalMaximumPhase.map { [$0] } ?? []))
        let missing = names.filter { maxima[$0] == nil }.count
        guard valid, names.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }),
            maxima.count + missing <= Self.maximumPhaseCount else { valid = false; return }
        let inventory = NumericStorageInventory()
        register(inventory)
        let snapshot = inventory.snapshot(phase: phase, bar: bar)
        guard snapshot.valid else { valid = false; return }
        let observations = observationCount.addingReportingOverflow(1)
        let phaseCount = (phaseObservationCounts[phase] ?? 0).addingReportingOverflow(1)
        guard !observations.overflow, !phaseCount.overflow else { valid = false; return }
        observationCount = observations.partialValue
        phaseObservationCounts[phase] = phaseCount.partialValue
        for name in names {
            let value = name == phase ? snapshot : NumericStorageSnapshot(
                phase: name, observedPhase: phase, bar: snapshot.bar,
                uniqueBufferCapacityBytes: snapshot.uniqueBufferCapacityBytes,
                typedMetadataHeadroomBytes: snapshot.typedMetadataHeadroomBytes,
                ownerRecords: snapshot.ownerRecords, valid: snapshot.valid)
            let current = maxima[name]
            if current == nil || value.numericPlusTypedHeadroomBytes > current!.numericPlusTypedHeadroomBytes {
                maxima[name] = value
            }
        }
    }
}

extension NumericStorageInventory {
    package func register(_ capture: AutonomousBarRoleStemCapture, owner: String) {
        for channel in DiagnosticRoleStemChannel.allCases {
            register(capture.samples(for: channel), owner: owner + "." + channel.rawValue)
        }
    }

    package func registerBlocks(_ blocks: [RenderBlock], owner: String) {
        // Only the two channel owners are observed. Project them directly;
        // enumerating whole RenderBlock values copies all score/evidence fields
        // onto the already-deep detached render stack for no inventory purpose.
        for index in blocks.indices {
            register(blocks[index].left, owner: "\(owner).\(index).left")
            register(blocks[index].right, owner: "\(owner).\(index).right")
        }
    }

    func register(_ bar: RenderedBar, owner: String) {
        register(bar.samples, owner: owner + ".samples")
        register(bar.leftSamples, owner: owner + ".left")
        register(bar.rightSamples, owner: owner + ".right")
        register(bar.audibleKickSamples, owner: owner + ".audibleKick")
        register(bar.upperPercussionSamples, owner: owner + ".upperPercussion")
        register(bar.graphRemainderReferenceLeftSamples, owner: owner + ".graphReferenceLeft")
        register(bar.graphRemainderReferenceRightSamples, owner: owner + ".graphReferenceRight")
        register(bar.effectCarrierSamples, owner: owner + ".effectCarrier")
        register(bar.resonantAnchorSamples, owner: owner + ".resonantAnchor")
        register(bar.detunedCompanionSamples, owner: owner + ".detunedCompanion")
        if let capture = bar.diagnosticRoleStemCapture {
            register(capture.dryCenterReference, owner: owner + ".capture.center")
            register(capture.dryUpperReference, owner: owner + ".capture.upper")
            register(capture.kick, owner: owner + ".capture.kick")
            register(capture.foundation, owner: owner + ".capture.foundation")
            register(capture.modalFoundation, owner: owner + ".capture.modalFoundation")
            register(capture.percussion, owner: owner + ".capture.percussion")
            register(capture.upperTonal, owner: owner + ".capture.upperTonal")
            register(capture.atmosphere, owner: owner + ".capture.atmosphere")
            register(capture.protectedFoundation, owner: owner + ".capture.protectedFoundation")
            register(capture.sourceLeft, owner: owner + ".capture.sourceLeft")
            register(capture.sourceRight, owner: owner + ".capture.sourceRight")
        }
    }
}


/// Synchronous nested observation scope. Captured immutable outer owners live
/// only for this call; neither the probe nor the inventory retains this scope.
/// Never capture an inout owner being modified by the observed callee. That
/// callee registers its own live state and workspace at the observation point.
package struct PreparationStorageObservation {
    package let probe: PreparationWorkingStorageProbe
    package let prefix: String
    package let bar: Int
    private let registerOuter: (NumericStorageInventory) -> Void
    private let additionalMaximumPhase: String?

    package init(probe: PreparationWorkingStorageProbe, prefix: String, bar: Int,
        additionalMaximumPhase: String? = nil, registerOuter: @escaping (NumericStorageInventory) -> Void = { _ in }) {
        self.probe = probe; self.prefix = prefix; self.bar = bar
        self.registerOuter = registerOuter
        self.additionalMaximumPhase = additionalMaximumPhase
    }

    package func observe(_ phase: String, register: (NumericStorageInventory) -> Void) {
        probe.observe(phase: prefix.isEmpty ? phase : prefix + "." + phase, bar: bar,
            additionalMaximumPhase: additionalMaximumPhase) { inventory in
            registerOuter(inventory)
            register(inventory)
            withExtendedLifetime(self) {}
        }
    }

    /// Reuses the same immutable outer owners for this synchronous bar only.
    package func atBar(_ bar: Int) -> PreparationStorageObservation {
        PreparationStorageObservation(probe: probe, prefix: prefix, bar: bar,
            additionalMaximumPhase: additionalMaximumPhase, registerOuter: registerOuter)
    }

    /// One conditional maximum of the same physical snapshots, not another
    /// inventory, PCM owner, render, or increment of the observation count.
    package func retainingMaximum(_ phase: String?) -> PreparationStorageObservation {
        PreparationStorageObservation(probe: probe, prefix: prefix, bar: bar,
            additionalMaximumPhase: phase, registerOuter: registerOuter)
    }

    /// Joins live owners without consuming a new phase namespace. The closure
    /// must exclude mutable buffers borrowed by the observed helper.
    package func joiningOwners(
        _ register: @escaping (NumericStorageInventory) -> Void) -> PreparationStorageObservation {
        PreparationStorageObservation(probe: probe, prefix: prefix, bar: bar,
            additionalMaximumPhase: additionalMaximumPhase) { inventory in
            self.registerOuter(inventory)
            register(inventory)
        }
    }

    package func extending(_ component: String,
        registerOuter: @escaping (NumericStorageInventory) -> Void) -> PreparationStorageObservation {
        PreparationStorageObservation(probe: probe, prefix: prefix.isEmpty ? component : prefix + "." + component, bar: bar,
            additionalMaximumPhase: additionalMaximumPhase) {
            inventory in
            self.registerOuter(inventory)
            registerOuter(inventory)
        }
    }
}


extension NumericStorageInventory {
    package func register(_ product: AutonomousPhraseRenderProduct, owner: String) {
        registerBlocks(product.blocks, owner: owner + ".primary")
        for (ordinal, hold) in product.repeatHoldEvolutionCandidates.enumerated() {
            registerHoldBlocks(hold.blocks, owner: "\(owner).hold.\(ordinal)")
        }
        for (ordinal, capture) in product.diagnosticRoleStemCaptures.enumerated() {
            register(capture, owner: "\(owner).capture.\(ordinal)")
        }
        withExtendedLifetime(product) {}
    }

    package func register(_ source: PreparedAutonomousPhrase, owner: String) {
        registerBlocks(source.blocks, owner: owner + ".primary")
        for (ordinal, hold) in source.repeatHoldEvolutions.enumerated() {
            registerHoldBlocks(hold.blocks, owner: "\(owner).hold.\(ordinal)")
        }
        for (ordinal, capture) in source.diagnosticRoleStemCaptures.enumerated() {
            register(capture, owner: "\(owner).capture.\(ordinal)")
        }
        AutonomousTypedFingerprint.registerContinuationStorage(
            renderState: source.endingRenderState, generatedDSPState: source.endingGraphState,
            inventory: self, owner: owner + ".continuation")
        withExtendedLifetime(source) {}
    }

    package func registerHoldBlocks(_ blocks: [RepeatHoldEvolutionRenderBlock], owner: String) {
        for (ordinal, block) in blocks.enumerated() {
            register(block.left, owner: "\(owner).\(ordinal).left")
            register(block.right, owner: "\(owner).\(ordinal).right")
        }
    }
}
