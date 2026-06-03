import SwiftUI
import SwiftData

/// v4 mentor-system SCAFFOLD (honest: this is the foundation, NOT the full
/// marketplace). Surfaces the two things a real mentor program needs first — an
/// opt-in choice (get matched vs bring your own mentor) and the mentee→mentor
/// progression framed as a REWARD to unlock, never a paywall. Real cross-user
/// matching, the mentor/mentee link, and commission billing are future work.
struct MentorProgramCard: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile

    @State private var showInvite = false
    private let mentorTarget = 30

    private var progress: Double {
        min(1, Double(max(0, profile.mentorProgressDays)) / Double(mentorTarget))
    }
    private var unlocked: Bool { profile.mentorProgressDays >= mentorTarget }

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: "Mentorship")

            Text("A real person in your corner. Get matched with a mentor, or bring your own and share your progress.")
                .font(t.body(13))
                .foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                optInRow("seekMatch", "Match me with a mentor", "person.2.fill", t)
                optInRow("ownMentor", "Share with my own mentor", "square.and.arrow.up", t)
                optInRow("none", "Not now", "moon.zzz.fill", t)
            }

            // Generate a shareable code / connect with someone.
            Button {
                Haptics.light()
                showInvite = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: profile.connectedPeerCode.isEmpty ? "qrcode" : "checkmark.circle.fill")
                        .font(.system(size: 13))
                    Text(profile.connectedPeerCode.isEmpty ? "Invite & connect" : "Connected — manage")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(t.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(t.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.scalePress)
            .accessibilityIdentifier("mentor.inviteButton")

            t.hair.frame(height: 0.5).padding(.vertical, 2)

            // Mentee → mentor progression — an incentive to reach, not a barrier to entry.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(t.accent)
                    Text("Become a mentor")
                        .font(t.heading(15))
                        .foregroundStyle(t.ink)
                    Spacer()
                    Text("\(profile.mentorProgressDays)/\(mentorTarget) days")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.muted)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(t.hair).frame(height: 6)
                        Capsule().fill(t.accent).frame(width: max(6, geo.size.width * progress), height: 6)
                    }
                }
                .frame(height: 6)
                Text(unlocked
                     ? "Unlocked — you can guide others now (and earn from it down the line)."
                     : "Keep showing up — at \(mentorTarget) days you unlock mentoring others.")
                    .font(t.body(12))
                    .foregroundStyle(t.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mentor.program")
        .sheet(isPresented: $showInvite) {
            MentorInviteSheet(profile: profile).environment(tm)
        }
    }

    @ViewBuilder
    private func optInRow(_ value: String, _ label: String, _ icon: String, _ t: ResolvedTheme) -> some View {
        let selected = profile.mentorOptInRaw == value
        Button {
            Haptics.selection()
            profile.mentorOptInRaw = value
            try? modelContext.save()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? t.accent : t.muted)
                    .frame(width: 20)
                Text(label)
                    .font(t.body(14))
                    .foregroundStyle(t.ink)
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? t.accent : t.faint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selected ? t.accentSoft : t.sunken)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
