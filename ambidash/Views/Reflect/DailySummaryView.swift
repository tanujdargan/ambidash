import SwiftUI

struct DailySummaryView: View {
    let plan: DailyPlan?
    let snapshot: IntegrationSnapshot?

    private var doneCount: Int { plan?.actions.filter { $0.statusRaw == "done" }.count ?? 0 }
    private var skippedCount: Int { plan?.actions.filter { $0.statusRaw == "skipped" }.count ?? 0 }
    private var totalCount: Int { plan?.actions.count ?? 0 }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Today's Results")

                VStack(spacing: 6) {
                    SummaryRow(label: "Actions completed", value: "\(doneCount) of \(totalCount)", color: doneCount == totalCount ? AmbidashTheme.statusGood : AmbidashTheme.statusWarn)
                    SummaryRow(label: "Actions skipped", value: "\(skippedCount)", color: skippedCount > 0 ? AmbidashTheme.statusBad : AmbidashTheme.statusGood)

                    if let snap = snapshot {
                        SummaryRow(label: "Sleep", value: String(format: "%.1fh", snap.sleepHours), color: snap.sleepHours >= 7 ? AmbidashTheme.statusGood : AmbidashTheme.statusWarn)
                        SummaryRow(label: "Screen time", value: String(format: "%.1fh", snap.screenTimeHours), color: snap.screenTimeHours <= 3 ? AmbidashTheme.statusGood : AmbidashTheme.statusBad)
                        SummaryRow(label: "Steps", value: "\(snap.steps)", color: snap.steps >= 8000 ? AmbidashTheme.statusGood : AmbidashTheme.statusWarn)
                    }
                }
            }
        }
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
                .foregroundStyle(AmbidashTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}
