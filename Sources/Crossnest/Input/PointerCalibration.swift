import CoreGraphics
import Foundation

/// Learns how far the pointer really moves per raw mouse count at each speed, i.e. the user's tracking
/// speed and acceleration curve, by watching normal use while the pointer is attached. Precision-mode
/// Mouse Lock applies the same curve, so the pointer feels exactly as it does everywhere else.
///
/// Speeds are binned by powers of two of the raw distance per event (0.5–1, 1–2, 2–4 … 256+).
struct PointerCalibration {
    private static let binCount = 10
    private static let defaultsKey = "mouseLockCalibration"
    /// Samples needed before a bin is trusted.
    private static let minimumSamples = 8

    private var ratios: [Double]
    private var counts: [Int]
    private var unsavedSamples = 0

    init() {
        let saved = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [Double]
        if let saved, saved.count == Self.binCount * 2 {
            ratios = Array(saved[0..<Self.binCount])
            counts = saved[Self.binCount...].map { Int($0) }
        } else {
            ratios = Array(repeating: 1, count: Self.binCount)
            counts = Array(repeating: 0, count: Self.binCount)
        }
    }

    /// Records one movement seen while the pointer was attached: the raw count and the real pixel distance.
    mutating func learn(raw: Double, actual: Double) {
        guard raw >= 0.5, actual > 0, actual < 2000 else { return }
        let bin = Self.bin(for: raw)
        let ratio = actual / raw
        counts[bin] += 1
        // Exponential moving average; the first few samples move it quickly.
        let alpha = max(0.03, 1 / Double(counts[bin]))
        ratios[bin] += (ratio - ratios[bin]) * alpha
        unsavedSamples += 1
        if unsavedSamples >= 500 { save() }
    }

    /// Pixels per raw count at this raw speed, interpolated between bins.
    func scale(forRaw raw: Double) -> Double {
        guard raw >= 0.5 else { return trustedRatio(0) }
        let exact = log2(raw) + 1  // 1 → 1.0, 2 → 2.0 …
        let lower = Int(exact.rounded(.down))
        let upper = lower + 1
        let fraction = exact - Double(lower)
        let a = trustedRatio(lower), b = trustedRatio(upper)
        return a + (b - a) * fraction
    }

    var hasLearnedAnything: Bool { counts.contains { $0 >= Self.minimumSamples } }

    mutating func save() {
        unsavedSamples = 0
        UserDefaults.standard.set(ratios + counts.map(Double.init), forKey: Self.defaultsKey)
    }

    // MARK: - Private

    private static func bin(for raw: Double) -> Int {
        min(max(Int((log2(raw) + 1).rounded(.down)), 0), binCount - 1)
    }

    /// The bin's ratio if it has enough samples, otherwise the nearest trusted bin's, otherwise 1.
    private func trustedRatio(_ bin: Int) -> Double {
        let index = min(max(bin, 0), Self.binCount - 1)
        if counts[index] >= Self.minimumSamples { return ratios[index] }
        for distance in 1..<Self.binCount {
            for candidate in [index - distance, index + distance] where (0..<Self.binCount).contains(candidate) {
                if counts[candidate] >= Self.minimumSamples { return ratios[candidate] }
            }
        }
        return 1
    }
}
