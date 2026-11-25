import UIKit

/// Light haptic taps (iPhone only; iPads ignore them).
enum Haptics {
    static func goal() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func rep() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
