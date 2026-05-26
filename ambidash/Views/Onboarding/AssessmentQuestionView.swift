import SwiftUI

struct AssessmentQuestionView: View {
    let question: AssessmentQuestion
    @Binding var selectedIds: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.text)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AmbidashTheme.textPrimary)

                if !question.subtitle.isEmpty {
                    Text(question.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AmbidashTheme.textSecondary)
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
                                    .foregroundStyle(AmbidashTheme.textPrimary)

                                if !option.description.isEmpty {
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundStyle(AmbidashTheme.textSecondary)
                                }
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AmbidashTheme.accent)
                            }
                        }
                        .padding(14)
                        .background(isSelected ? AmbidashTheme.accent.opacity(0.15) : AmbidashTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium)
                                .stroke(isSelected ? AmbidashTheme.accent : AmbidashTheme.border, lineWidth: isSelected ? 1.5 : 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}
