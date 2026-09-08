import Foundation

public enum CoreError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidArgument(String)
    case unsupportedDate
    case provider(String)
    case workBudgetExceeded
    case unresolvedInterval
    public var description: String {
        switch self {
        case .invalidArgument(let message), .provider(let message): return message
        case .unsupportedDate: return "Date outside the calculation window 2000-01-01 through 2050-12-31 UTC."
        case .workBudgetExceeded: return "Calculation work budget exhausted; coverage is incomplete."
        case .unresolvedInterval: return "Could not resolve this search interval reliably."
        }
    }
}

public enum Body: String, CaseIterable, Codable, Sendable, Identifiable {
    case sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto
    public var id: String { rawValue }
    public var name: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .sun: "☉"
        case .moon: "☽"
        case .mercury: "☿"
        case .venus: "♀"
        case .mars: "♂"
        case .jupiter: "♃"
        case .saturn: "♄"
        case .uranus: "♅"
        case .neptune: "♆"
        case .pluto: "♇"
        }
    }
    public var canRetrograde: Bool { self != .sun && self != .moon }
}

public enum ZodiacSign: Int, CaseIterable, Codable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces
    public var name: String {
        ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"][rawValue]
    }
    public var symbol: String {
        ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"][rawValue]
    }
}

public enum Angle {
    public static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
    public static func difference(_ a: Double, _ b: Double) -> Double {
        let d = normalized(a - b + 180) - 180
        return d == -180 ? 180 : d
    }
}

public struct Position: Codable, Sendable, Equatable, Identifiable {
    public let body: Body
    public let longitude: Double
    public let latitude: Double
    /// Geocentric longitudinal velocity, degrees per elapsed day.
    public let velocity: Double
    public var id: Body { body }
    public init(body: Body, longitude: Double, latitude: Double, velocity: Double) throws {
        guard longitude.isFinite, latitude.isFinite, abs(latitude) <= 90, velocity.isFinite else {
            throw CoreError.provider("Invalid coordinates for \(body.name).")
        }
        self.body = body
        self.longitude = Angle.normalized(longitude)
        self.latitude = latitude
        self.velocity = velocity
    }
    public var sign: ZodiacSign { ZodiacSign.allCases[Int(longitude / 30)] }
    public var degreeText: String {
        let minutes = min(1799, Int((longitude.truncatingRemainder(dividingBy: 30) * 60).rounded()))
        return "\(minutes / 60)°\(String(format: "%02d", minutes % 60))′"
    }
    public func motion(stationaryThreshold: Double = 0.01) -> String {
        if body.canRetrograde && abs(velocity) < stationaryThreshold { return "Stationary" }
        return velocity < 0 && body.canRetrograde ? "Retrograde" : "Direct"
    }
}

public struct ProviderMetadata: Codable, Sendable, Equatable {
    public let name: String
    public let revision: String
    public let convention: String
    public let earliest: Date
    public let latestExclusive: Date
    public init(name: String, revision: String, convention: String, earliest: Date, latestExclusive: Date) {
        self.name = name
        self.revision = revision
        self.convention = convention
        self.earliest = earliest
        self.latestExclusive = latestExclusive
    }
    public func validate(_ date: Date) throws {
        guard date.timeIntervalSince1970.isFinite, date >= earliest, date < latestExclusive else {
            throw CoreError.unsupportedDate
        }
    }
}

public protocol EphemerisProvider: Sendable {
    var metadata: ProviderMetadata { get }
    func positions(at date: Date, bodies: [Body]) async throws -> [Position]
}

public protocol WallClock: Sendable { func now() -> Date }
public struct SystemWallClock: WallClock {
    public init() {}
    public func now() -> Date { Date() }
}

public struct SkySnapshot: Codable, Sendable {
    public let schemaVersion: Int
    public let provider: ProviderMetadata
    public let at: Date
    public let calculatedAt: Date
    public let positions: [Position]
    public init(provider: ProviderMetadata, at: Date, calculatedAt: Date, positions: [Position]) {
        schemaVersion = 1
        self.provider = provider
        self.at = at
        self.calculatedAt = calculatedAt
        self.positions = positions
    }
    public var moonPhase: String? {
        guard let moon = positions.first(where: { $0.body == .moon }),
            let sun = positions.first(where: { $0.body == .sun }) else { return nil }
        let phase = Angle.normalized(moon.longitude - sun.longitude)
        return ["New Moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full Moon", "Waning gibbous", "Last quarter", "Waning crescent"][Int((phase + 22.5) / 45) % 8]
    }
}
