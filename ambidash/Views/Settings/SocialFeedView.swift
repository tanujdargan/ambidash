import SwiftUI
import SwiftData

struct SocialFeedView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AccountabilityPartner.createdAt) private var partners: [AccountabilityPartner]

    @State private var events: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        let t = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isLoading && events.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if events.isEmpty {
                    emptyState(t)
                } else {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                        eventRow(event, t)
                    }
                }
            }
            .padding(22)
        }
        .background(t.bg)
        .navigationTitle("Activity Feed")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadFeed() }
        .task { await loadFeed() }
    }

    @ViewBuilder
    private func eventRow(_ event: [String: Any], _ t: ResolvedTheme) -> some View {
        let code = event["code"] as? String ?? "—"
        let kind = event["kind"] as? String ?? "completed"
        let title = event["title"] as? String ?? ""
        let createdAt = (event["created_at"] as? String)
            .flatMap { ISO8601DateFormatter().date(from: $0) }

        let partner = partners.first { $0.code == code }
        let name = (partner?.displayName.isEmpty == false) ? partner!.displayName : code

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForKind(kind))
                .font(.system(size: 14))
                .foregroundStyle(colorForKind(kind, t))
                .frame(width: 28, height: 28)
                .background(colorForKind(kind, t).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(t.ink)
                    if let date = createdAt {
                        Text(timeAgo(date))
                            .font(.system(size: 11))
                            .foregroundStyle(t.faint)
                    }
                }
                Text(title)
                    .font(t.body(14))
                    .foregroundStyle(t.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(t.faint)
            Text("Your partners' activity will appear here as they complete goals and hit milestones.")
                .font(t.body(14))
                .foregroundStyle(t.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func iconForKind(_ kind: String) -> String {
        switch kind {
        case "completed": "checkmark.circle.fill"
        case "streak": "flame.fill"
        case "milestone": "flag.fill"
        case "encouragement": "heart.fill"
        default: "circle.fill"
        }
    }

    private func colorForKind(_ kind: String, _ t: ResolvedTheme) -> Color {
        switch kind {
        case "completed": t.ok
        case "streak": t.accent
        case "milestone": t.accent
        case "encouragement": .pink
        default: t.muted
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    private func loadFeed() async {
        isLoading = true
        defer { isLoading = false }
        let codes = partners.map(\.code)
        guard !codes.isEmpty else { return }
        events = await SupabaseService.shared.fetchPartnerFeed(codes: codes) ?? []
    }
}
