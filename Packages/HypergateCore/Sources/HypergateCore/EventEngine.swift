import Foundation

public struct EventQuery: Codable, Sendable, Equatable {
  public let from: Date
  public let to: Date
  public let bodies: [Body]
  public let types: [EventKind]
  public init(
    from: Date, to: Date, bodies: [Body] = Body.allCases, types: [EventKind] = EventKind.standard
  ) throws {
    guard from.timeIntervalSince1970.isFinite, to.timeIntervalSince1970.isFinite,
      to > from, to.timeIntervalSince(from) <= 90 * 86400, !bodies.isEmpty, !types.isEmpty
    else {
      throw CoreError.invalidArgument(
        "Choose bodies/types and an increasing time range of at most 90 days.")
    }
    self.from = from
    self.to = to
    self.bodies = Body.allCases.filter { bodies.contains($0) }
    self.types = EventKind.allCases.filter { types.contains($0) }
  }
}

public struct EventDocument: Codable, Sendable {
  public let schemaVersion: Int
  public let algorithmRevision: String
  public let provider: ProviderMetadata
  public let calculatedAt: Date
  public let query: EventQuery
  public let coverageEnd: Date
  public let complete: Bool
  public let events: [AstroEvent]
  public init(
    provider: ProviderMetadata, calculatedAt: Date, query: EventQuery, events: [AstroEvent]
  ) {
    schemaVersion = 1
    algorithmRevision = EventEngine.algorithmRevision
    self.provider = provider
    self.calculatedAt = calculatedAt
    self.query = query
    coverageEnd = query.to
    complete = true
    self.events = events
  }
}

public actor EventEngine {
  public static let algorithmRevision = "adaptive-longitude-v1-20260908"
  public nonisolated let provider: any EphemerisProvider
  private let cache: EphemerisCache
  private let evaluationBudget: Int
  private let clock: any WallClock
  public init(
    provider: any EphemerisProvider, evaluationBudget: Int = 500_000,
    clock: any WallClock = SystemWallClock()
  ) {
    self.provider = provider
    self.evaluationBudget = evaluationBudget
    self.clock = clock
    cache = EphemerisCache(provider: provider)
  }
  public func events(_ query: EventQuery) async throws -> EventDocument {
    try provider.metadata.validate(query.from)
    guard query.to <= provider.metadata.latestExclusive else { throw CoreError.unsupportedDate }
    let search = EventSearch(cache: cache, metadata: provider.metadata, budget: evaluationBudget)
    let events = try await search.run(query)
    return EventDocument(
      provider: provider.metadata, calculatedAt: clock.now(), query: query, events: events)
  }
}

private actor EphemerisCache {
  let provider: any EphemerisProvider
  var samples: [Date: [Body: Position]] = [:]
  init(provider: any EphemerisProvider) { self.provider = provider }
  func at(_ date: Date) async throws -> [Body: Position] {
    if let cached = samples[date] { return cached }
    let positions = try await provider.positions(at: date, bodies: Body.allCases)
    guard positions.count == Body.allCases.count,
      Set(positions.map(\.body)).count == positions.count,
      positions.allSatisfy({ $0.longitude.isFinite && $0.latitude.isFinite && $0.velocity.isFinite }
      )
    else {
      throw CoreError.provider("Provider returned an incomplete or invalid sky sample.")
    }
    let value = Dictionary(uniqueKeysWithValues: positions.map { ($0.body, $0) })
    if samples.count >= 24_000 { samples.removeAll(keepingCapacity: true) }
    samples[date] = value
    return value
  }
}

private enum SearchSignal: Sendable {
  case longitude(Body)
  case separation(Body, Body)
  case velocity(Body)
  var periodic: Bool { if case .velocity = self { false } else { true } }
  var bodies: [Body] {
    switch self {
    case .longitude(let body), .velocity(let body): [body]
    case .separation(let a, let b): [a, b]
    }
  }
}

private struct SignalSample: Sendable {
  let value: Double
  let derivative: Double
}

private struct Candidate: Sendable {
  let instant: Date
  let target: Double
  let signal: SearchSignal
  let kind: EventKind
}

private actor EventSearch {
  let cache: EphemerisCache
  let metadata: ProviderMetadata
  let budget: Int
  var evaluations = 0
  var requestedSamples: [Date: [Body: Position]] = [:]
  init(cache: EphemerisCache, metadata: ProviderMetadata, budget: Int) {
    self.cache = cache
    self.metadata = metadata
    self.budget = budget
  }
  func position(_ body: Body, _ date: Date) async throws -> Position {
    try Task.checkCancellation()
    if requestedSamples[date] == nil {
      evaluations += 1
      guard evaluations <= budget else { throw CoreError.workBudgetExceeded }
      requestedSamples[date] = try await cache.at(date)
    }
    guard let position = requestedSamples[date]?[body] else {
      throw CoreError.provider("Missing body.")
    }
    return position
  }
  func sample(_ signal: SearchSignal, _ date: Date) async throws -> SignalSample {
    switch signal {
    case .longitude(let body):
      let p = try await position(body, date)
      return SignalSample(value: p.longitude, derivative: p.velocity)
    case .separation(let a, let b):
      let pa = try await position(a, date)
      let pb = try await position(b, date)
      return SignalSample(
        value: Angle.normalized(pa.longitude - pb.longitude), derivative: pa.velocity - pb.velocity)
    case .velocity(let body):
      let p = try await position(body, date)
      let left = max(metadata.earliest, date.addingTimeInterval(-300))
      let right = min(
        metadata.latestExclusive.addingTimeInterval(-0.001), date.addingTimeInterval(300))
      let a = try await position(body, left)
      let b = try await position(body, right)
      return SignalSample(
        value: p.velocity,
        derivative: (b.velocity - a.velocity) / right.timeIntervalSince(left) * 86400)
    }
  }
  func run(_ query: EventQuery) async throws -> [AstroEvent] {
    var result: [AstroEvent] = []
    var day = Date(timeIntervalSince1970: floor(query.from.timeIntervalSince1970 / 86400) * 86400)
    while day < query.to {
      try Task.checkCancellation()
      let start = max(day, metadata.earliest)
      let end = min(
        day.addingTimeInterval(86400), metadata.latestExclusive.addingTimeInterval(-0.001))
      var candidates: [Candidate] = []
      for body in query.bodies {
        if query.types.contains(.ingress) {
          candidates += try await search(
            .longitude(body), kind: .ingress, targets: (0..<12).map { Double($0) * 30 },
            start: start, end: end)
        }
        if body.canRetrograde, query.types.contains(where: \.isStation) {
          candidates += try await search(
            .velocity(body), kind: .stationDirect, targets: [0], start: start, end: end)
        }
      }
      for a in query.bodies.indices {
        for b in query.bodies.indices where b > a {
          for kind in query.types where !kind.angles.isEmpty {
            candidates += try await search(
              .separation(query.bodies[a], query.bodies[b]), kind: kind, targets: kind.angles,
              start: start, end: end)
          }
        }
      }
      var ordinals: [String: Int] = [:]
      for candidate in candidates.sorted(by: { $0.instant < $1.instant }) {
        let delta = 0.5
        let beforeTime = max(metadata.earliest, candidate.instant.addingTimeInterval(-delta))
        let afterTime = min(
          metadata.latestExclusive.addingTimeInterval(-0.001),
          candidate.instant.addingTimeInterval(delta))
        guard beforeTime < candidate.instant, afterTime > candidate.instant else {
          throw CoreError.unresolvedInterval
        }
        let before = try await sample(candidate.signal, beforeTime)
        let after = try await sample(candidate.signal, afterTime)
        var kind = candidate.kind
        var previous: ZodiacSign?
        var entered: ZodiacSign?
        if case .longitude = candidate.signal {
          previous = ZodiacSign.allCases[Int(Angle.normalized(before.value) / 30)]
          entered = ZodiacSign.allCases[Int(Angle.normalized(after.value) / 30)]
          if previous == entered { continue }
        } else if case .velocity = candidate.signal {
          guard (before.value < 0) != (after.value < 0) else { continue }
          kind = before.value > 0 ? .stationRetrograde : .stationDirect
          guard query.types.contains(kind) else { continue }
        }
        let semantic =
          candidate.signal.bodies.map(\.rawValue).joined(separator: "+") + ":" + kind.rawValue + ":"
          + String(Int(candidate.target))
        // Half-open refined subinterval ownership removes duplicate endpoint
        // discoveries without merging distinct roots by timestamp proximity.
        let ordinal = ordinals[semantic, default: 0]
        ordinals[semantic] = ordinal + 1
        let id = "v1:\(semantic):\(Int(floor(day.timeIntervalSince1970 / 86400))):\(ordinal)"
        guard candidate.instant >= query.from, candidate.instant < query.to else { continue }
        result.append(
          AstroEvent(
            id: id, instant: candidate.instant, kind: kind, bodies: candidate.signal.bodies,
            longitude: kind == .ingress ? candidate.target : nil,
            aspectAngle: kind.angles.isEmpty ? nil : candidate.target,
            previousSign: previous, enteredSign: entered))
      }
      day = day.addingTimeInterval(86400)
    }
    return result.sorted { $0.instant == $1.instant ? $0.id < $1.id : $0.instant < $1.instant }
  }
  func search(_ signal: SearchSignal, kind: EventKind, targets: [Double], start: Date, end: Date)
    async throws -> [Candidate]
  {
    var found: [Candidate] = []
    var a = start
    while a < end {
      let b = min(end, a.addingTimeInterval(6 * 3600))
      found += try await segment(signal, kind: kind, targets: targets, a: a, b: b, depth: 0)
      a = b
    }
    return found
  }
  func segment(
    _ signal: SearchSignal, kind: EventKind, targets: [Double], a: Date, b: Date, depth: Int
  ) async throws -> [Candidate] {
    guard depth <= 20 else { throw CoreError.unresolvedInterval }
    let duration = b.timeIntervalSince(a)
    var times = (0...4).map { a.addingTimeInterval(duration * Double($0) / 4) }
    var samples: [SignalSample] = []
    for time in times { samples.append(try await sample(signal, time)) }
    let maximumSpeed = samples.map { abs($0.derivative) }.max() ?? 0
    // Keep an angular segment well away from the 180° unwrapping ambiguity.
    if signal.periodic && maximumSpeed * duration / 86400 > 15 {
      let midpoint = times[2]
      let left = try await segment(
        signal, kind: kind, targets: targets, a: a, b: midpoint, depth: depth + 1)
      return try await left
        + segment(signal, kind: kind, targets: targets, a: midpoint, b: b, depth: depth + 1)
    }
    // Solve derivative sign changes, then split at every relative-motion extremum.
    // This finds both roots around an extremum even when value endpoints agree.
    for i in 0..<4 where (samples[i].derivative < 0) != (samples[i + 1].derivative < 0) {
      let turning = try await RootRefinement.solve(from: times[i], to: times[i + 1]) { date in
        try await self.sample(signal, date).derivative
      }
      if turning > a && turning < b { times.append(turning) }
    }
    times = Array(Set(times)).sorted()
    var found: [Candidate] = []
    for i in 0..<(times.count - 1) {
      let left = times[i]
      let right = times[i + 1]
      let fa = try await sample(signal, left).value
      let fb = try await sample(signal, right).value
      let unwrappedB = signal.periodic ? fa + Angle.difference(fb, fa) : fb
      for target in targets {
        let branch = signal.periodic ? fa + Angle.difference(target, fa) : target
        let low = min(fa, unwrappedB)
        let high = max(fa, unwrappedB)
        guard branch >= low - 1e-10, branch <= high + 1e-10 else { continue }
        let root: Date
        if abs(fa - branch) <= 1e-10 {
          root = left
        } else if abs(unwrappedB - branch) <= 1e-10 {
          root = right
        } else {
          root = try await RootRefinement.solve(from: left, to: right) { date in
            let value = try await self.sample(signal, date).value
            return signal.periodic ? Angle.difference(value, target) : value - target
          }
        }
        if root >= left && root < right {
          found.append(Candidate(instant: root, target: target, signal: signal, kind: kind))
        }
      }
    }
    return found
  }
}
