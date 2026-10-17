// Standalone CI diagnostic. No runtime import, output admission, or oracle change.
// Frozen inputs come from the thirteen differing bars of the canonical
// root48291 four-hour trace; the full4...16-bar grid prevents cherry-picking
// only that progress value when comparing native scalar arithmetic.
import Foundation

let configuration = CommandLine.arguments.last ?? ""
precondition(["debug", "release"].contains(configuration))
func bits(_ value: Double) -> String { String(value.bitPattern, radix: 16) }
func emit(_ fields: [String: String]) throws {
    var record = fields
    record["schema"] = "autotechno-native-planning-scalar.v1"
    record["configuration"] = configuration
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    print("NATIVE_PLANNING_SCALAR_JSON " + String(decoding: try encoder.encode(record), as: UTF8.self))
}

for length in 4...16 {
    for index in 0..<length {
        let progress = Double(index) / Double(length - 1)
        let angle = progress * .pi * 2
        try emit(["kind": "grid", "length": String(length), "index": String(index),
                  "progressBits": bits(progress), "piBits": bits(.pi),
                  "angleBits": bits(angle), "sinBits": bits(sin(angle))])
    }
}

// Bit patterns are diagnostics, not platform-specific acceptance values.
let cases: [(bar: Int, priorBits: UInt64, progressBits: UInt64)] = [
    (210, 0x3fe47ae147ae147b, 0x3fc1111111111111),
    (818, 0x3fe1eb851eb851ec, 0x3fc1111111111111),
    (959, 0x3fe394f011a06667, 0x3fc1111111111111),
    (988, 0x3fe40ef33c566d9c, 0x3fc1111111111111),
    (1638, 0x3fe47ae147ae147b, 0x3fc1111111111111),
    (2091, 0x3fe1eb851eb851ec, 0x3fc1111111111111),
    (4372, 0x3fe47ae147ae147b, 0x3fc1111111111111),
    (4967, 0x3fe4a9f20ba5f7a4, 0x3fc1111111111111),
    (4983, 0x3fe4a3521cdde580, 0x3fc1111111111111),
    (5298, 0x3fe1eb851eb851ec, 0x3fc1111111111111),
    (6067, 0x3fe4ea536a1746f0, 0x3fc1111111111111),
    (6586, 0x3fe57e2950b14861, 0x3fc1111111111111),
    (6615, 0x3fe4ea536a1746f0, 0x3fc1111111111111),
 ]
for entry in cases {
    let prior = Double(bitPattern: entry.priorBits)
    let progress = Double(bitPattern: entry.progressBits)
    let angle = progress * .pi * 2
    let wave = sin(angle)
    let product = prior * 0.72
    let base = product + 0.18
    let weightedWave = wave * 0.06
    // Match AutonomousSessionDirector.tension's expression and also expose
    // each intermediate operation to distinguish math-library from arithmetic drift.
    let tension = min(0.72, max(0.32, prior * 0.72 + 0.18 + sin(progress * .pi * 2) * 0.06))
    try emit(["kind": "observed-case", "bar": String(entry.bar),
              "priorBits": bits(prior), "progressBits": bits(progress),
              "angleBits": bits(angle), "sinBits": bits(wave),
              "productBits": bits(product), "baseBits": bits(base),
              "weightedWaveBits": bits(weightedWave), "tensionBits": bits(tension)])
}
print("Native scalar diagnostic only; no runtime qualification or accepted platform oracle.")
