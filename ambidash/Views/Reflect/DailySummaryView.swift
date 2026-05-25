import SwiftUI

struct DailySummaryView: View {
    let plan: DailyPlan?
    let snapshot: IntegrationSnapshot?

    private var doneCount: Int { plan?.actions.filter { $0.statusRaw == "done" }.count ?? 0 }
    private var skippedCount: Int { plan?.actions.filter { $0.statusRaw == "skipped" }.count ?? 0 }
    private var totalCount: Int { plan?.actions.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S RESULTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(spacing: 6) {
                SummaryRow(label: "Actions completed", value: "\(doneCount) of \(totalCount)", color: doneCount == totalCount ? .green : .orange)
                SummaryRow(label: "Actions skipped", value: "\(skippedCount)", color: skippedCount > 0 ? .red : .green)

                if let snap = snapshot {
                    SummaryRow(label: "Sleep", value: String(format: "%.1fh", snap.sleepHours), color: snap.sleepHours >= 7 ? .green : .orange)
                    SummaryRow(label: "Screen time", value: String(format: "%.1fh", snap.screenTimeHours), color: snap.screenTimeHours <= 3 ? .green : .red)
                    SummaryRow(label: "Steps", value: "\(snap.steps)", color: snap.steps >= 8000 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}
