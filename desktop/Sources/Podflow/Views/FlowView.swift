import SwiftUI

/// The pipeline as a vertical stepper with status styling and connectors;
/// a failed stage halts the visual progression.
struct FlowView: View {
    let episode: Episode
    var stages: [PipelineStage] = PipelineStage.all

    private func status(for stage: PipelineStage) -> StepState {
        episode.status(of: stage.id)
    }

    private var failedIndex: Int? {
        stages.firstIndex { status(for: $0) == .failed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
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
                        Text(label(for: stage, state: state))
                            .font(.caption2)
                            .foregroundStyle(Theme.statusColor(state))
                    }
                    Spacer(minLength: 0)
                }

                if index < stages.count - 1 {
                    connector(after: index)
                }
            }
        }
    }

    private func label(for stage: PipelineStage, state: StepState) -> String {
        if stage.waitsForUser, state == .inProgress { return "wartet auf dich" }
        return Theme.statusLabel(state)
    }

    private func stageIcon(stage: PipelineStage, state: StepState, halted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 30, height: 30)
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
                if stage.waitsForUser {
                    Image(systemName: stage.systemImage).font(.caption).foregroundStyle(.blue)
                } else {
                    ProgressView().controlSize(.small)
                }
            case .done:
                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.red)
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
            .frame(width: 2, height: 12)
            .padding(.leading, 14)
    }
}
