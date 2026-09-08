import Foundation
import Testing
@testable import HypergateCore
import HypergateAstronomyEngine

@Test func anglesWrapAndPreserveSignAtRoundingBoundary() throws {
    #expect(Angle.normalized(-1) == 359)
    #expect(Angle.normalized(360) == 0)
    #expect(Angle.difference(1, 359) == 2)
    let p = try Position(body: .moon, longitude: 29.9999, latitude: 0, velocity: 12)
    #expect(p.sign == .aries)
    #expect(p.degreeText == "29°59′")
}

@Test func strictDatesRejectImpossibleAndOffsetlessInput() throws {
    #expect(throws: CoreError.self) { try UTCDate.parse("2026-02-30T00:00:00Z") }
    #expect(throws: CoreError.self) { try UTCDate.parse("2026-09-08T19:00:00") }
    #expect(try UTCDate.parse("2026-09-08T12:00:00-07:00") == UTCDate.parse("2026-09-08T19:00:00Z"))
}

@Test func providerReturnsTenRealFinitePositions() async throws {
    let provider = AstronomyEngineProvider()
    let at = try UTCDate.parse("2026-09-08T19:00:00Z")
    let positions = try await provider.positions(at: at, bodies: Body.allCases)
    #expect(positions.count == 10)
    #expect(positions.allSatisfy { $0.longitude >= 0 && $0.longitude < 360 && $0.velocity.isFinite })
    #expect(positions.first { $0.body == .sun }?.sign == .virgo)
}

@Test func unsupportedDateFails() async throws {
    let provider = AstronomyEngineProvider()
    await #expect(throws: CoreError.self) {
        try await provider.positions(at: UTCDate.parse("1999-01-01T00:00:00Z"), bodies: [.moon])
    }
}
