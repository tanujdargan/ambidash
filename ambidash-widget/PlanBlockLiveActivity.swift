#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

/// The Now/Next focus Live Activity — Lock Screen banner + Dynamic Island.
///
/// The live countdown is driven entirely by `Text(timerInterval:countsDown:)`
/// against `state.blockInterval`, so the SYSTEM ticks it with NO app wake-ups
/// (iOS-26 cheat-sheet §2). The app only `update()`s at block boundaries and
/// `end(.immediate)`s at day's end. We branch on `context.isStale` so a Live
/// Activity that outlived its last app update reads as "wrapping up" rather than
/// showing a wrong countdown.
@available(iOS 16.1, *)
struct PlanBlockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlanBlockAttributes.self) { context in
            // Lock Screen / banner presentation.
            LockScreenLiveActivityView(context: context)
                .containerBackground(.fill.tertiary, for: .widget)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — current block, live countdown, next block.
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: WidgetStyle.domainIcon(context.state.blockDomainRaw))
                            .foregroundStyle(WidgetStyle.domainColor(context.state.blockDomainRaw))
                        Text(context.state.blockTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.isStale {
                        Text("wrapping up")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(timerInterval: context.state.blockInterval, countsDown: true)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: 64)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let next = context.state.nextTitle {
                        HStack(spacing: 4) {
                            Text("Next")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(next)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let start = context.state.nextStart {
                                Text(start, format: .dateTime.hour().minute())
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("Last block of the day")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: WidgetStyle.domainIcon(context.state.blockDomainRaw))
                    .foregroundStyle(WidgetStyle.domainColor(context.state.blockDomainRaw))
            } compactTrailing: {
                if context.isStale {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                } else {
                    Text(timerInterval: context.state.blockInterval, countsDown: true)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: 52)
                }
            } minimal: {
                Image(systemName: WidgetStyle.domainIcon(context.state.blockDomainRaw))
                    .foregroundStyle(WidgetStyle.domainColor(context.state.blockDomainRaw))
            }
            .keylineTint(WidgetStyle.domainColor(context.state.blockDomainRaw))
        }
    }
}

@available(iOS 16.1, *)
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PlanBlockAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NOW")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if context.isStale {
                    Text("wrapping up")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text(timerInterval: context.state.blockInterval, countsDown: true)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: 86, alignment: .trailing)
                }
            }

            HStack(spacing: 7) {
                Image(systemName: WidgetStyle.domainIcon(context.state.blockDomainRaw))
                    .font(.system(size: 15))
                    .foregroundStyle(WidgetStyle.domainColor(context.state.blockDomainRaw))
                Text(context.state.blockTitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }

            if let next = context.state.nextTitle {
                HStack(spacing: 5) {
                    Text("NEXT")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(next)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let start = context.state.nextStart {
                        Text(start, format: .dateTime.hour().minute())
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Last block of the day")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }
}
#endif
