import SwiftUI

struct InsightCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PATTERN SPOTTED")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.blue)
                .tracking(0.5)

            Text("Connect Apple Health and Calendar to unlock AI-powered insights about your patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
