// ambidash/Views/Settings/AppRestrictionsViews.swift
//
// v5 feat/v5-app-restrictions — the UI for scheduled restriction windows, per-app daily budgets,
// the weekly usage report, and the override-with-reason flow. These hang off AppLimitsView (only
// shown once Screen Time is approved). Every mutation re-reconciles the DeviceActivity schedules
// through AppLimitController; on the Simulator that's a safe no-op, so the screens still work for
// editing config.
import SwiftUI
import SwiftData
#if os(iOS)
import FamilyControls
#endif

// MARK: - Shared reconcile helper

@MainActor
private func reconcileSchedules(_ context: ModelContext) {
    let windows = (try? context.fetch(FetchDescriptor<RestrictionWindow>())) ?? []
    let budgets = (try? context.fetch(FetchDescriptor<AppBudget>())) ?? []
    AppLimitController.shared.applySchedules(windows: windows, budgets: budgets)
}

// MARK: - Restriction windows

struct RestrictionWindowsView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RestrictionWindow.startMinute) private var windows: [RestrictionWindow]
    @State private var editing: RestrictionWindow?
    @State private var showAdd = false

    var body: some View {
        let t = tm.resolved
        List {
            Section {
                Text("Block your chosen apps automatically during these windows — e.g. social media during work hours.")
                    .font(.footnote).foregroundStyle(t.muted)
            }
            .listRowBackground(t.surface)

            ForEach(windows) { window in
                Button { editing = window } label: { windowRow(window, t) }
                    .listRowBackground(t.surface)
            }
            .onDelete(perform: delete)

            Section {
                Button {
                    showAdd = true
                } label: {
                    Label("Add a window", systemImage: "plus.circle")
                        .foregroundStyle(t.accent)
                }
            }
            .listRowBackground(t.surface)
        }
        .scrollContentBackground(.hidden)
        .background(t.bg)
        .navigationTitle("Restriction Windows")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            WindowEditorView(window: nil)
        }
        .sheet(item: $editing) { window in
            WindowEditorView(window: window)
        }
    }

    @ViewBuilder
    private func windowRow(_ window: RestrictionWindow, _ t: ResolvedTheme) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(window.name.isEmpty ? "Untitled window" : window.name)
                    .font(t.body(15)).foregroundStyle(window.isEnabled ? t.ink : t.muted)
                Text("\(clock(window.startMinute))–\(clock(window.endMinute)) · \(RestrictionSchedule.label(for: window.weekdayMask))")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(t.muted)
            }
            Spacer()
            if !window.isEnabled {
                Text("Off").font(.caption2).foregroundStyle(t.faint)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(t.faint)
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(windows[i]) }
        try? modelContext.save()
        reconcileSchedules(modelContext)
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

struct WindowEditorView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let window: RestrictionWindow?

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var weekdayMask = RestrictionSchedule.weekdaysMonFri
    @State private var isEnabled = true
    @State private var didSeed = false

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Work hours", text: $name)
                }
                .listRowBackground(t.surface)

                Section("Time") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endDate, displayedComponents: .hourAndMinute)
                }
                .listRowBackground(t.surface)

                Section("Repeat") {
                    weekdayPicker(t)
                }
                .listRowBackground(t.surface)

                Section {
                    Toggle("Enabled", isOn: $isEnabled).tint(t.accent)
                }
                .listRowBackground(t.surface)
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .navigationTitle(window == nil ? "New Window" : "Edit Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear(perform: seed)
        }
    }

    @ViewBuilder
    private func weekdayPicker(_ t: ResolvedTheme) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let on = RestrictionSchedule.contains(weekdayMask, weekday: i)
                Button {
                    weekdayMask ^= (1 << i)
                } label: {
                    Text(RestrictionSchedule.weekdayShort[i].prefix(1))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(on ? t.accent : t.surface)
                        .foregroundStyle(on ? t.bg : t.muted)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(t.hair, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func seed() {
        guard !didSeed else { return }
        if let w = window {
            name = w.name
            startDate = dateFrom(minutes: w.startMinute)
            endDate = dateFrom(minutes: w.endMinute)
            weekdayMask = w.weekdayMask
            isEnabled = w.isEnabled
        } else {
            startDate = dateFrom(minutes: 540)
            endDate = dateFrom(minutes: 1020)
        }
        didSeed = true
    }

    private func save() {
        let start = minutesFrom(date: startDate)
        let end = minutesFrom(date: endDate)
        if let w = window {
            w.name = name; w.startMinute = start; w.endMinute = end
            w.weekdayMask = weekdayMask; w.isEnabled = isEnabled
        } else {
            let w = RestrictionWindow(name: name, startMinute: start, endMinute: end,
                                      weekdayMask: weekdayMask, isEnabled: isEnabled)
            modelContext.insert(w)
        }
        try? modelContext.save()
        reconcileSchedules(modelContext)
        Haptics.success()
        dismiss()
    }

    private func dateFrom(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }
    private func minutesFrom(date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

// MARK: - Daily budgets

struct AppBudgetsView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppBudget.createdAt) private var budgets: [AppBudget]
    @State private var showAdd = false

    var body: some View {
        let t = tm.resolved
        List {
            Section {
                Text("Give an app a daily time budget. When it's spent, the app is blocked for the rest of the day.")
                    .font(.footnote).foregroundStyle(t.muted)
            }
            .listRowBackground(t.surface)

            ForEach(budgets) { budget in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(budget.name.isEmpty ? "Untitled budget" : budget.name)
                            .font(t.body(15)).foregroundStyle(budget.isEnabled ? t.ink : t.muted)
                        Text("\(budget.dailyMinutes) min/day")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(t.muted)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { budget.isEnabled },
                        set: { budget.isEnabled = $0; try? modelContext.save(); reconcileSchedules(modelContext) }
                    )).labelsHidden().tint(t.accent)
                }
                .listRowBackground(t.surface)
            }
            .onDelete(perform: delete)

            Section {
                Button { showAdd = true } label: {
                    Label("Add a budget", systemImage: "plus.circle").foregroundStyle(t.accent)
                }
            }
            .listRowBackground(t.surface)
        }
        .scrollContentBackground(.hidden)
        .background(t.bg)
        .navigationTitle("Daily Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) { BudgetEditorView() }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(budgets[i]) }
        try? modelContext.save()
        reconcileSchedules(modelContext)
    }
}

struct BudgetEditorView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var minutes = 30
    @State private var showPicker = false
    #if os(iOS)
    @State private var selection = FamilyActivitySelection()
    #endif

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Instagram", text: $name)
                }
                .listRowBackground(t.surface)

                Section("Daily allowance") {
                    Stepper("\(minutes) minutes", value: $minutes, in: 5...480, step: 5)
                }
                .listRowBackground(t.surface)

                #if os(iOS)
                Section("Apps") {
                    Button {
                        showPicker = true
                    } label: {
                        let count = selection.applicationTokens.count + selection.categoryTokens.count
                        Label(count == 0 ? "Choose apps" : "\(count) picked", systemImage: "apps.iphone")
                            .foregroundStyle(t.accent)
                    }
                }
                .listRowBackground(t.surface)
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            #if os(iOS)
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
            #endif
        }
    }

    private func save() {
        var data: Data? = nil
        #if os(iOS)
        data = try? JSONEncoder().encode(selection)
        #endif
        let budget = AppBudget(name: name, dailyMinutes: minutes, selectionData: data, isEnabled: true)
        modelContext.insert(budget)
        try? modelContext.save()
        reconcileSchedules(modelContext)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Weekly report

struct WeeklyRestrictionReportView: View {
    @Environment(ThemeManager.self) private var tm
    @Query private var windows: [RestrictionWindow]
    @Query private var budgets: [AppBudget]
    @Query(sort: \RestrictionOverride.timestamp, order: .reverse) private var overrides: [RestrictionOverride]

    private var report: RestrictionSchedule.WeeklyUsageReport {
        RestrictionSchedule.weeklyReport(
            windows: windows.map { .init(startMinute: $0.startMinute, endMinute: $0.endMinute, weekdayMask: $0.weekdayMask, isEnabled: $0.isEnabled) },
            enabledBudgetCount: budgets.filter { $0.isEnabled }.count,
            overrides: overrides.map { .init(timestamp: $0.timestamp, reason: $0.reason, minutesGranted: $0.minutesGranted) }
        )
    }

    var body: some View {
        let t = tm.resolved
        let r = report
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("This week")
                    .font(t.heading(20)).foregroundStyle(t.ink)

                HStack(spacing: 12) {
                    statCard(t, value: "\(r.enabledWindowCount)", label: "Windows")
                    statCard(t, value: "\(r.enabledBudgetCount)", label: "Budgets")
                    statCard(t, value: r.scheduledRestrictedLabel, label: "Scheduled")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Overrides")
                        .font(t.heading(16)).foregroundStyle(t.ink)
                    Text(r.overrideCount == 0
                         ? "No overrides this week — nicely held."
                         : "\(r.overrideCount) override\(r.overrideCount == 1 ? "" : "s"), \(r.totalOverrideMinutes) min total. No judgment — just awareness.")
                        .font(t.body(13)).foregroundStyle(t.muted)
                    if let top = r.topReason {
                        Text("Most common reason: \(top)")
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(t.muted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if !overrides.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent overrides").font(t.heading(16)).foregroundStyle(t.ink)
                        ForEach(overrides.prefix(8)) { o in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(o.reason.isEmpty ? "No reason given" : o.reason)
                                    .font(t.body(13)).foregroundStyle(t.ink)
                                Text("\(o.sourceName) · \(o.timestamp.formatted(.dateTime.month().day().hour().minute()))")
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(t.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(t.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(22)
        }
        .background(t.bg)
        .navigationTitle("Weekly Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func statCard(_ t: ResolvedTheme, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(t.heading(20)).foregroundStyle(t.ink)
            Text(label).font(.caption2).foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Override sheet

struct OverrideReasonSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let sourceName: String
    let sourceKind: String

    @State private var reason = ""
    @State private var minutes = 15

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            Form {
                Section {
                    Text("Lifting a limit is fine — telling yourself why builds awareness. This is logged for your weekly report, never to shame you.")
                        .font(.footnote).foregroundStyle(t.muted)
                }
                .listRowBackground(t.surface)

                Section("Why are you overriding?") {
                    TextField("e.g. need to reply to a message", text: $reason, axis: .vertical)
                        .lineLimit(1...3)
                }
                .listRowBackground(t.surface)

                Section("For how long?") {
                    Stepper("\(minutes) minutes", value: $minutes, in: 5...120, step: 5)
                }
                .listRowBackground(t.surface)
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .navigationTitle("Override")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Lift limit") { confirm() } }
            }
        }
    }

    private func confirm() {
        AppLimitController.shared.liftShieldTemporarily(minutes: minutes)
        let log = RestrictionOverride(sourceName: sourceName, sourceKind: sourceKind, reason: reason, minutesGranted: minutes)
        modelContext.insert(log)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
