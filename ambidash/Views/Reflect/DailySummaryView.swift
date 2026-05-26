import SwiftUI

struct DailySummaryView: View {
    let plan: DailyPlan?
    let snapshot: IntegrationSnapshot?

    @Environment(ThemeManager.self) private var tm

    private var doneCount: Int { plan?.actions.filter { $0.statusRaw == "done" }.count ?? 0 }
    private var skippedCount: Int { plan?.actions.filter { $0.statusRaw == "skipped" }.count ?? 0 }
    private var totalCount: Int { plan?.actions.count ?? 0 }

    var body: some View {
        let t = tm.resolved
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Today's Results")

                VStack(spacing: 6) {
                    SummaryRow(label: "Actions completed", value: "\(doneCount) of \(totalCount)", color: doneCount == totalCount ? t.ok : t.accent)
                    SummaryRow(label: "Actions skipped", value: "\(skippedCount)", color: skippedCount > 0 ? t.danger : t.ok)

                    if let snap = snapshot {
                        SummaryRow(label: "Sleep", value: String(format: "%.1fh", snap.sleepHours), color: snap.sleepHours >= 7 ? t.ok : t.accent)
                        SummaryRow(label: "Screen time", value: String(format: "%.1fh", snap.screenTimeHours), color: snap.screenTimeHours <= 3 ? t.ok : t.danger)
                        SummaryRow(label: "Steps", value: "\(snap.steps)", color: snap.steps >= 8000 ? t.ok : t.accent)
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

    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(t.muted)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}
