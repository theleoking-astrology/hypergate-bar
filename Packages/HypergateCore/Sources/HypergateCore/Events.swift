import Foundation

public enum EventKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case ingress, square, opposition, stationRetrograde = "station_retrograde", stationDirect = "station_direct"
    case conjunction, semisquare, sesquiquadrate
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .stationRetrograde: "Station retrograde"
        case .stationDirect: "Station direct"
        default: rawValue.capitalized
        }
    }
    public var isStation: Bool { self == .stationDirect || self == .stationRetrograde }
    public var angles: [Double] {
        switch self {
        case .square: [90, 270]
        case .opposition: [180]
        case .conjunction: [0]
        case .semisquare: [45, 315]
        case .sesquiquadrate: [135, 225]
        default: []
        }
    }
    public static let standard: [EventKind] = [.ingress, .square, .opposition, .stationRetrograde, .stationDirect]
}

public struct AstroEvent: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let instant: Date
    public let kind: EventKind
    public let bodies: [Body]
    public let longitude: Double?
    public let aspectAngle: Double?
    public let previousSign: ZodiacSign?
    public let enteredSign: ZodiacSign?
    public init(id: String, instant: Date, kind: EventKind, bodies: [Body], longitude: Double? = nil,
                aspectAngle: Double? = nil, previousSign: ZodiacSign? = nil, enteredSign: ZodiacSign? = nil) {
        self.id = id; self.instant = instant; self.kind = kind; self.bodies = bodies
        self.longitude = longitude; self.aspectAngle = aspectAngle
        self.previousSign = previousSign; self.enteredSign = enteredSign
    }
    public var title: String {
        let names = bodies.map(\.name).joined(separator: " · ")
        if kind == .ingress, let enteredSign { return "\(names) enters \(enteredSign.name)" }
        return "\(names) · \(kind.name)"
    }
}

/// Fast first-slice lookup; the full forecast engine uses the same longitude and
/// bracket refinement, and replaces this entry point with canonical event records.
public enum IngressSearch {
    public static func next(body: Body, after start: Date, provider: any EphemerisProvider) async throws -> AstroEvent {
        var left = start
        var previous = try await position(body, left, provider)
        for _ in 0..<360 {
            try Task.checkCancellation()
            let right = left.addingTimeInterval(6 * 3600)
            let current = try await position(body, right, provider)
            if current.sign != previous.sign {
                let forward = Angle.difference(current.longitude, previous.longitude) > 0
                let boundary = Double(forward ? current.sign.rawValue : previous.sign.rawValue) * 30
                let instant = try await RootRefinement.solve(from: left, to: right) { date in
                    try await Angle.difference(position(body, date, provider).longitude, boundary)
                }
                let before = try await position(body, instant.addingTimeInterval(-2), provider)
                let after = try await position(body, instant.addingTimeInterval(2), provider)
                guard before.sign != after.sign else { throw CoreError.unresolvedInterval }
                let day = Int(floor(instant.timeIntervalSince1970 / 86400))
                return AstroEvent(id: "v1:\(body.rawValue):ingress:\(day):\(after.sign.rawValue)",
                                  instant: instant, kind: .ingress, bodies: [body], longitude: boundary,
                                  previousSign: before.sign, enteredSign: after.sign)
            }
            left = right; previous = current
        }
        throw CoreError.invalidArgument("No ingress found in the calculated 90-day window.")
    }
    private static func position(_ body: Body, _ date: Date, _ provider: any EphemerisProvider) async throws -> Position {
        guard let position = try await provider.positions(at: date, bodies: [body]).first else {
            throw CoreError.provider("Provider omitted requested body.")
        }
        return position
    }
}

public enum RootRefinement {
    public static func solve(from start: Date, to end: Date,
                             value: @Sendable (Date) async throws -> Double) async throws -> Date {
        var a = start; var b = end
        var fa = try await value(a)
        let fb = try await value(b)
        guard fa.isFinite, fb.isFinite else { throw CoreError.unresolvedInterval }
        if fa == 0 { return a }
        if fb == 0 { return b }
        guard (fa < 0) != (fb < 0) else { throw CoreError.unresolvedInterval }
        while b.timeIntervalSince(a) > 0.005 {
            try Task.checkCancellation()
            let middle = a.addingTimeInterval(b.timeIntervalSince(a) / 2)
            let fm = try await value(middle)
            guard fm.isFinite else { throw CoreError.unresolvedInterval }
            if fm == 0 { return middle }
            if (fa < 0) == (fm < 0) { a = middle; fa = fm } else { b = middle }
        }
        return a.addingTimeInterval(b.timeIntervalSince(a) / 2)
    }
}
