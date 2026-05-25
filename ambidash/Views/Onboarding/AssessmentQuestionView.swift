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

                if !question.subtitle.isEmpty {
                    Text(question.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

                                if !option.description.isEmpty {
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(14)
                        .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}
