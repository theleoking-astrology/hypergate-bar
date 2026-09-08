import AppKit
import HypergateCore
import UniformTypeIdentifiers

@MainActor enum EventExport {
  static func save(_ document: EventDocument) throws {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "hypergate-events.json"
    panel.title = "Export calculated events"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try UTCDate.encoder().encode(document).write(to: url, options: .atomic)
  }
}
