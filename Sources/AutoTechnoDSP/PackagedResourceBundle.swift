import Foundation

/// Packaging-only resource lookup for a conventional signed macOS app bundle.
/// SwiftPM builds retain their generated module-bundle fallback unchanged.
enum PackagedResourceBundle {
    static nonisolated let current: Bundle = {
        if let resourceURL = Bundle.main.resourceURL,
           let packaged = Bundle(
            url: resourceURL.appendingPathComponent(
                "AutoTechno_AutoTechnoDSP.bundle",
                isDirectory: true
            )
           ) {
            return packaged
        }
        return .module
    }()
}
