import Foundation
import Observation
import OSLog
import HypergateCore
import HypergateAstronomyEngine

@MainActor @Observable
final class AppState {
    static let shared = AppState()
    private let provider = AstronomyEngineProvider()
    private let clock: any WallClock
    private let logger = Logger(subsystem: "ai.hypergate.HypergateBar", category: "calculation")
    var sky: SkySnapshot?
    var nextMoonIngress: AstroEvent?
    var error: String?
    var calculating = false
    private var generation = 0
    init(clock: any WallClock = SystemWallClock()) { self.clock = clock }
    func refresh() async {
        generation += 1
        let token = generation
        calculating = true
        defer { if token == generation { calculating = false } }
        do {
            let now = clock.now()
            let positions = try await provider.positions(at: now, bodies: Body.allCases)
            guard token == generation, !Task.isCancelled else { return }
            sky = SkySnapshot(provider: provider.metadata, at: now, calculatedAt: clock.now(), positions: positions)
            let ingress = try await IngressSearch.next(body: .moon, after: now, provider: provider)
            guard token == generation, !Task.isCancelled else { return }
            nextMoonIngress = ingress
            error = nil
            logger.info("Sky and next Moon ingress calculated")
        } catch is CancellationError {
            return
        } catch {
            guard token == generation else { return }
            self.error = String(describing: error)
            logger.error("Calculation failed: \(String(describing: error), privacy: .public)")
        }
    }
    var moon: Position? { sky?.positions.first { $0.body == .moon } }
}
