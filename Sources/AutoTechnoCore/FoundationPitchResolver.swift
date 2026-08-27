import Foundation

/// Canonical modal policy for the protected foundation. The renderer receives
/// a resolved frequency from Core and cannot add an unowned chromatic tension
/// note. Harmonic tension remains available to explicitly scored upper roles.
package enum FoundationPitchResolver {
    package static func modalDegree(dna: SceneDNA, step: Int) -> Int {
        let index = dna.rhythm.bassSteps.firstIndex(of: step) ?? (step / 2)
        if dna.modalIdentity == .phrygian {
            let protectedDegrees = [0, 7, 0, 12]
            return protectedDegrees[index % protectedDegrees.count]
        }
        return dna.modalDegrees[index % dna.modalDegrees.count]
    }

    package static func frequency(dna: SceneDNA, step: Int) -> Double {
        let degree = modalDegree(dna: dna, step: step)
        return 43.65 * pow(2, Double(dna.tonalCenter + degree) / 12)
    }
}
