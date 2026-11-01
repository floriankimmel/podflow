import SwiftUI

/// The live pipeline visualization: the profile's ordered stages as a vertical
/// stepper with status styling and connectors; a failed stage halts the visual
/// progression (design.md — Episode detail).
struct FlowView: View {
    let stages: [EpisodeProfile.Stage]
    let record: BackendEpisode?
    var localDone: Set<String> = []

    private func status(for stage: EpisodeProfile.Stage) -> StepState {
        let state = record?.status(of: stage.key) ?? .pending
        if state == .pending, localDone.contains(stage.key) { return .done }
        return state
    }

    private var failedIndex: Int? {
        stages.firstIndex { status(for: $0) == .failed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.key) { index, stage in
                let state = status(for: stage)
                let halted = failedIndex.map { index > $0 } ?? false

                HStack(spacing: 12) {
                    stageIcon(stage: stage, state: state, halted: halted)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stage.label)
                            .font(.callout.weight(state == .inProgress ? .semibold : .regular))
                            .foregroundStyle(halted ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(Theme.statusLabel(state))
                            .font(.caption2)
                            .foregroundStyle(Theme.statusColor(state))
                    }
                    Spacer(minLength: 0)
                    if state == .failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .help("Diese Stufe ist fehlgeschlagen.")
                    }
                }

                if index < stages.count - 1 {
                    connector(after: index)
                }
            }
        }
    }

    private func stageIcon(stage: EpisodeProfile.Stage, state: StepState, halted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 34, height: 34)
                .overlay(
                    Circle().strokeBorder(
                        state == .pending || halted
                            ? AnyShapeStyle(Color.secondary.opacity(0.35))
                            : AnyShapeStyle(Theme.statusColor(state)),
                        style: StrokeStyle(lineWidth: 2, dash: state == .pending ? [3, 3] : [])
                    )
                )
            switch state {
            case .inProgress:
                ProgressView()
                    .controlSize(.small)
            case .done:
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
            case .pending:
                Image(systemName: stage.systemImage)
                    .font(.caption)
                    .foregroundStyle(halted ? .tertiary : .secondary)
            }
        }
    }

    private func connector(after index: Int) -> some View {
        let state = status(for: stages[index])
        let haltedHere = failedIndex.map { index >= $0 } ?? false
        return Rectangle()
            .fill(state == .done && !haltedHere ? Theme.statusColor(.done) : Color.secondary.opacity(0.25))
            .frame(width: 2, height: 18)
            .padding(.leading, 16)
    }
}
