import HypergateCore
import SwiftUI

struct EventDetailView: View {
  let event: AstroEvent
  let state: AppState
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(event.title).font(.title2.bold())
      LabeledContent("Local time", value: state.formatted(event.instant))
      LabeledContent("Display zone", value: state.zone.identifier)
      LabeledContent("UTC", value: UTCDate.string(event.instant))
      if let angle = event.aspectAngle {
        LabeledContent("Directed separation", value: "\(angle.formatted())°")
      }
      if let previous = event.previousSign, let entered = event.enteredSign {
        LabeledContent("Crossing", value: "\(previous.name) → \(entered.name)")
      }
      Text(
        "Calculated tropical, geocentric event. Numerical refinement and astronomical accuracy are different; see the published accuracy matrix."
      ).foregroundStyle(.secondary)
      Text(event.id).font(.caption.monospaced()).textSelection(.enabled)
      Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
    }.padding(24).frame(width: 520)
  }
}

struct EventRow: View {
  let event: AstroEvent
  let state: AppState
  var body: some View {
    Button {
      state.selectedEvent = event
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(event.title).foregroundStyle(.primary)
          Text(state.formatted(event.instant)).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
      }.padding(.vertical, 5).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(
      "\(event.title), \(state.formatted(event.instant)), details")
  }
}
