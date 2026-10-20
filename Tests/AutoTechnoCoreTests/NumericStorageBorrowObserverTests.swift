import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Scoped detached numeric storage borrows", .serialized)
struct NumericStorageBorrowObserverTests {
    private final class Observer: NumericStorageBorrowObserver {
        struct Borrow: Equatable {
            let owner: String
            let bytes: Int
            let aliasOf: String?
        }
        var begins: [(phase: String, bar: Int)] = []
        var completed: [[Borrow]] = []
        var snapshots: [NumericStorageSnapshot] = []
        private var current: [Borrow] = []
        private var identities: [UInt: String] = [:]
        var open = false
        var valid = true
        func beginSnapshot(phase: String, bar: Int) {
            valid = valid && !open && identities.isEmpty && current.isEmpty
            open = true
            begins.append((phase, bar))
        }
        func observeBuffer(owner: String, base: UnsafeRawPointer, capacityBytes: Int) {
            valid = valid && open && capacityBytes > 0
            let key = UInt(bitPattern: base)
            current.append(Borrow(owner: owner, bytes: capacityBytes, aliasOf: identities[key]))
            if identities[key] == nil { identities[key] = owner }
        }
        func endSnapshot(_ snapshot: NumericStorageSnapshot) {
            valid = valid && open
            let expected = snapshot.ownerRecords.filter { $0.capacityBytes > 0 }.map {
                Borrow(owner: $0.owner, bytes: $0.capacityBytes, aliasOf: $0.aliasOf)
            }
            valid = valid && current == expected
            completed.append(current)
            snapshots.append(snapshot)
            // Pointer identity never survives the physical observation.
            identities.removeAll(keepingCapacity: false)
            current.removeAll(keepingCapacity: false)
            open = false
        }
    }

    @Test("Physical borrows include unused capacity, aliases and reserved empty buffers")
    func allocatedOwnersAndAliases() throws {
        let observer = Observer(), probe = PreparationWorkingStorageProbe(borrowObserver: observer)
        let floats = [Float](repeating: 1, count: 7), alias = floats
        var reserved: [Float] = []; reserved.reserveCapacity(257)
        let integers: [Int64] = [4, 5, 6]
        probe.observe(phase: "physical", bar: 3, additionalMaximumPhase: "conditional") { inventory in
            inventory.register(floats, owner: "floats")
            inventory.register(alias, owner: "alias")
            inventory.register(reserved, owner: "reserved")
            inventory.register(integers, owner: "integers")
            inventory.register([Float](), owner: "empty")
        }
        #expect(observer.valid && !observer.open)
        #expect(observer.begins.count == 1 && observer.completed.count == 1)
        #expect(observer.completed[0].map(\.owner) == ["floats", "alias", "reserved", "integers"])
        #expect(observer.completed[0][1].aliasOf == "floats")
        #expect(observer.completed[0][2].bytes == reserved.capacity * MemoryLayout<Float>.stride)
        #expect(probe.observationCount == 1 && probe.phaseObservationCounts == ["physical": 1])
        #expect(probe.snapshots.count == 2)
        #expect(try #require(observer.snapshots.first).ownerRecords.count == 5)
        withExtendedLifetime((floats, alias, reserved, integers)) {}
    }

    @Test("Borrow observation preserves the exact default snapshot wire and conditional maximum")
    func defaultSnapshotAndWireParity() throws {
        let ordinary = PreparationWorkingStorageProbe(), observer = Observer()
        let observed = PreparationWorkingStorageProbe(borrowObserver: observer)
        let values = [Double](repeating: 0.125, count: 47)
        for probe in [ordinary, observed] {
            for bar in 0..<3 {
                probe.observe(phase: "stage", bar: bar, additionalMaximumPhase: "group") { inventory in
                    inventory.register(values, owner: "values")
                    inventory.register(values, owner: "alias")
                    inventory.addTypedMetadataHeadroom(256 + bar)
                }
            }
        }
        #expect(ordinary.valid && observed.valid && observer.valid)
        #expect(ordinary.snapshots == observed.snapshots)
        #expect(ordinary.observationCount == observed.observationCount)
        #expect(ordinary.phaseObservationCounts == observed.phaseObservationCounts)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(ordinary.snapshots) == encoder.encode(observed.snapshots))
        #expect(observer.completed.count == 3 && observer.snapshots.count == 3)
        #expect(observer.begins.map(\.bar) == [0, 1, 2])
        withExtendedLifetime(values) {}
    }

    @Test("Existing phase and owner bounds refuse without manufacturing observer capacity")
    func existingBoundsAndInvalidSnapshot() {
        let values: [Float] = [1]
        let observer = Observer(), probe = PreparationWorkingStorageProbe(borrowObserver: observer)
        for index in 0..<PreparationWorkingStorageProbe.maximumPhaseCount {
            probe.observe(phase: "phase.\(index)", bar: 0) { $0.register(values, owner: "value") }
        }
        probe.observe(phase: "exhausted", bar: 0) { _ in Issue.record("exhausted registration executed") }
        #expect(!probe.valid && observer.valid)
        #expect(observer.begins.count == PreparationWorkingStorageProbe.maximumPhaseCount)
        let invalidObserver = Observer(), invalid = PreparationWorkingStorageProbe(borrowObserver: invalidObserver)
        invalid.observe(phase: "oversized", bar: 0) { inventory in
            for index in 0...NumericStorageInventory.maximumOwnerCount {
                inventory.register(values, owner: "owner.\(index)")
            }
        }
        #expect(!invalid.valid && invalidObserver.valid && !invalidObserver.open)
        #expect(invalidObserver.completed.first?.count == NumericStorageInventory.maximumOwnerCount)
        #expect(invalidObserver.snapshots.first?.valid == false)
        #expect(AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount == 128 * 1_024 * 1_024)
        #expect(QualityQualificationContract.maximumRenderPasses == 2)
        withExtendedLifetime(values) {}
    }

    @Test("The probe releases its diagnostic receiver and retains no owner PCM")
    func receiverLifetime() {
        weak var weakObserver: Observer?
        do {
            let observer = Observer(); weakObserver = observer
            let probe = PreparationWorkingStorageProbe(borrowObserver: observer)
            let values = [UInt8](repeating: 4, count: 19)
            probe.observe(phase: "one", bar: 0) { $0.register(values, owner: "bytes") }
            #expect(observer.valid && observer.completed.count == 1 && !observer.open)
            #expect(weakObserver != nil)
            withExtendedLifetime((probe, values)) {}
        }
        #expect(weakObserver == nil)
    }
}
