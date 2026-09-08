import CAstronomyEngine
import Foundation
import HypergateCore

public struct AstronomyEngineProvider: EphemerisProvider {
    public let metadata = ProviderMetadata(
        name: "Astronomy Engine",
        revision: "865d3da7d8112bbc7911238052c6af4aaf877181",
        convention: "tropical-geocentric-true-ecliptic-of-date; light-time+aberration; no gravitational deflection; upstream delta-T; v1",
        earliest: Date(timeIntervalSince1970: 946684800),
        latestExclusive: Date(timeIntervalSince1970: 2556144000)
    )
    public init() {}
    public func positions(at date: Date, bodies: [Body]) async throws -> [Position] {
        try metadata.validate(date)
        try Task.checkCancellation()
        return try await AstronomyExecutor.shared.positions(at: date, bodies: bodies)
    }
}

/// Every call into the C library, including calls from different provider instances,
/// is isolated here. No C value or pointer crosses this boundary.
private actor AstronomyExecutor {
    static let shared = AstronomyExecutor()
    private func bodyCode(_ body: Body) -> astro_body_t {
        switch body {
        case .sun: BODY_SUN
        case .moon: BODY_MOON
        case .mercury: BODY_MERCURY
        case .venus: BODY_VENUS
        case .mars: BODY_MARS
        case .jupiter: BODY_JUPITER
        case .saturn: BODY_SATURN
        case .uranus: BODY_URANUS
        case .neptune: BODY_NEPTUNE
        case .pluto: BODY_PLUTO
        }
    }
    private func coordinates(_ body: Body, _ date: Date) throws -> (Double, Double) {
        let days = (date.timeIntervalSince1970 - 946728000) / 86400
        let time = Astronomy_TimeFromDays(days)
        var vector = Astronomy_BackdatePosition(time, BODY_EARTH, bodyCode(body), ABERRATION)
        guard vector.status == ASTRO_SUCCESS else { throw CoreError.provider("C vector calculation failed for \(body.name): \(vector.status.rawValue)") }
        vector.t = time
        let ecliptic = Astronomy_Ecliptic(vector)
        guard ecliptic.status == ASTRO_SUCCESS, ecliptic.elon.isFinite, ecliptic.elat.isFinite else {
            throw CoreError.provider("C ecliptic conversion failed for \(body.name).")
        }
        return (ecliptic.elon, ecliptic.elat)
    }
    private func velocity(_ body: Body, _ date: Date, step: Double) throws -> Double {
        let center = try coordinates(body, date).0
        func sample(_ multiple: Double) throws -> Double {
            try Angle.difference(coordinates(body, date.addingTimeInterval(step * multiple)).0, center)
        }
        return try (sample(-2) - 8 * sample(-1) + 8 * sample(1) - sample(2)) / (12 * step) * 86400
    }
    func positions(at date: Date, bodies: [Body]) throws -> [Position] {
        try bodies.map { body in
            try Task.checkCancellation()
            let (longitude, latitude) = try coordinates(body, date)
            let coarse = try velocity(body, date, step: 600)
            let fine = try velocity(body, date, step: 300)
            guard abs(coarse - fine) < 0.00001 else { throw CoreError.provider("Longitudinal derivative did not converge for \(body.name).") }
            return try Position(body: body, longitude: longitude, latitude: latitude, velocity: fine)
        }
    }
}
