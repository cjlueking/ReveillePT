import Foundation

enum Geometry {
    /// Unsigned angle in degrees at `vertex` between the rays to `a` and `c` (0...180).
    static func angle(_ a: Vec2, vertex b: Vec2, _ c: Vec2) -> Double? {
        angleBetween(a - b, c - b)
    }

    /// Unsigned angle in degrees between two vectors (0...180), nil if either is zero length.
    static func angleBetween(_ u: Vec2, _ v: Vec2) -> Double? {
        let m = u.length * v.length
        guard m > 1e-9 else { return nil }
        let cosine = max(-1, min(1, u.dot(v) / m))
        return acos(cosine) * 180 / .pi
    }

    static func midpoint(_ a: Vec2, _ b: Vec2) -> Vec2 { (a + b) * 0.5 }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }
}
