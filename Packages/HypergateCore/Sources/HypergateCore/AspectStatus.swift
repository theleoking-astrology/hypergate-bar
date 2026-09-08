import Foundation

public struct AspectStatus: Sendable, Identifiable {
    public enum Trend: String, Sendable { case applying, separating, exact, turning }
    public let bodies: [Body]
    public let kind: EventKind
    public let orb: Double
    public let allowedOrb: Double
    public let trend: Trend
    public var id: String { bodies.map(\.rawValue).joined(separator: "+") + kind.rawValue }
    public static func current(positions: [Position], types: [EventKind], majorOrb: Double = 3, minorOrb: Double = 1) -> [AspectStatus] {
        var result: [AspectStatus] = []
        for i in positions.indices {
            for j in positions.indices where j > i {
                let a = positions[i]; let b = positions[j]
                for type in types where !type.angles.isEmpty {
                    let separation = Angle.normalized(a.longitude - b.longitude)
                    guard let error = type.angles.map({ Angle.difference(separation, $0) }).min(by: { abs($0) < abs($1) }) else { continue }
                    let allowed = type == .semisquare || type == .sesquiquadrate ? minorOrb : majorOrb
                    guard abs(error) <= allowed else { continue }
                    let rate = a.velocity - b.velocity
                    let trend: Trend = abs(error) < 1e-6 ? .exact : abs(rate) < 1e-7 ? .turning : error * rate < 0 ? .applying : .separating
                    result.append(AspectStatus(bodies: [a.body, b.body], kind: type, orb: abs(error), allowedOrb: allowed, trend: trend))
                }
            }
        }
        return result.sorted { $0.orb < $1.orb }
    }
}
