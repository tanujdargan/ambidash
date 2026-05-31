#if canImport(AlarmKit)
import WidgetKit
import SwiftUI
import AlarmKit

/// GENTLE TIMELINE ALARMS — the Live Activity UI for an opt-in AlarmKit block-start
/// alarm (iOS 26+). AlarmKit alarms create a SYSTEM-managed Live Activity; the
/// alerting state is fully system-drawn, but a widget extension is REQUIRED to render
/// the COUNTDOWN and PAUSED (snooze) states — without it the system may dismiss the
/// alarm before it fires. We render a calm Lock Screen view + a compact Dynamic
/// Island, reading `AlarmAttributes<BlockAlarmMetadata>` + `AlarmPresentationState`.
///
/// The whole file is gated on `canImport(AlarmKit)` so it never breaks the mac build,
/// and the configuration is added to the @main bundle behind `#available(iOS 26)`.
@available(iOS 26.1, *)
struct BlockAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<BlockAlarmMetadata>.self) { context in
            BlockAlarmLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill")
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.blockTitle ?? "Block")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BlockAlarmCountdownText(state: context.state)
                        .font(.title3.monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                BlockAlarmCountdownText(state: context.state)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(context.attributes.tintColor)
            }
            .keylineTint(context.attributes.tintColor)
        }
    }
}

/// The Lock Screen presentation for the countdown / paused (snooze) states. The
/// alerting state itself is drawn by the system, so we only handle the non-alerting
/// modes here.
@available(iOS 26.1, *)
struct BlockAlarmLockScreenView: View {
    let context: ActivityViewContext<AlarmAttributes<BlockAlarmMetadata>>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "alarm.fill")
                .font(.title3)
                .foregroundStyle(context.attributes.tintColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.metadata?.blockTitle ?? "Your block")
                    .font(.headline)
                    .lineLimit(1)
                switch context.state.mode {
                case .paused:
                    Label("Snoozing", systemImage: "zzz")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                case .countdown, .alert:
                    Text("Starting soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            Spacer()
            BlockAlarmCountdownText(state: context.state)
                .font(.title2.monospacedDigit().bold())
                .foregroundStyle(context.attributes.tintColor)
        }
        .padding()
    }
}

/// A small countdown / time label driven by the alarm's presentation state.
@available(iOS 26.1, *)
struct BlockAlarmCountdownText: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let info):
            Text(info.fireDate, style: .timer)
        case .paused(let info):
            let remaining = max(0, info.totalCountdownDuration - info.previouslyElapsedDuration)
            Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
        case .alert(let info):
            Text("\(info.time.hour):\(String(format: "%02d", info.time.minute))")
        @unknown default:
            Text("--:--")
        }
    }
}
#endif
