import SwiftUI

struct AssessmentQuestionView: View {
    let question: AssessmentQuestion
    @Binding var selectedIds: Set<String>

    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.text)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(t.ink)

                if !question.subtitle.isEmpty {
                    Text(question.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(t.muted)
                }
            }

            VStack(spacing: 10) {
                ForEach(question.options) { option in
                    let isSelected = selectedIds.contains(option.id)

                    Button {
                        if question.multiSelect {
                            if isSelected {
                                selectedIds.remove(option.id)
                            } else {
                                selectedIds.insert(option.id)
                            }
                        } else {
                            selectedIds = [option.id]
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(.body)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundStyle(t.ink)

                                if !option.description.isEmpty {
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundStyle(t.muted)
                                }
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(t.accent)
                            }
                        }
                        .padding(14)
                        .background(isSelected ? t.accent.opacity(0.15) : t.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? t.accent : t.hair, lineWidth: isSelected ? 1.5 : 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}
