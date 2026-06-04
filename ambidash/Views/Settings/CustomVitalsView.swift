// ambidash/Views/Settings/CustomVitalsView.swift
//
// v5 feat/v5-custom-vitals — manage the vitals you track. Pick from starter categories (Sleep,
// Exercise, Hydration, Nutrition, Mood, Focus, Energy) or define a fully custom one, set a unit +
// daily target, then log values over time and see each vital's history.
import SwiftUI
import SwiftData

struct CustomVitalsView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomVital.sortIndex) private var vitals: [CustomVital]
    @State private var showCategoryPicker = false
    @State private var editorCategory: VitalCategory?

    var body: some View {
        let t = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Track what matters to you. Pick a category or build your own — log values and watch the patterns.")
                    .font(t.body(13)).foregroundStyle(t.muted)

                if vitals.isEmpty {
                    Text("No vitals yet. Add one to start tracking.")
                        .font(t.body(13)).foregroundStyle(t.muted).padding(.top, 8)
                } else {
                    ForEach(vitals) { vital in
                        NavigationLink {
                            VitalDetailView(vital: vital)
                        } label: {
                            VitalRow(vital: vital).environment(tm)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }

                Button {
                    Haptics.light()
                    showCategoryPicker = true
                } label: {
                    Label("Add a vital", systemImage: "plus.circle").foregroundStyle(t.accent)
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .background(t.bg)
        .navigationTitle("Vitals")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("customvitals.screen")
        .sheet(isPresented: $showCategoryPicker) {
            VitalCategoryPicker { category in
                showCategoryPicker = false
                editorCategory = category
            }
            .environment(tm)
        }
        .sheet(item: $editorCategory) { category in
            VitalEditorSheet(category: category, nextSortIndex: (vitals.map(\.sortIndex).max() ?? -10) + 10)
                .environment(tm)
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(vitals[i]) }
        try? modelContext.save()
    }
}

// MARK: - Row

private struct VitalRow: View {
    @Environment(ThemeManager.self) private var tm
    let vital: CustomVital

    private var summary: VitalStats.Summary {
        VitalStats.summary(entries: (vital.entries ?? []).map { .init(value: $0.value, date: $0.date) }, target: vital.target)
    }

    var body: some View {
        let t = tm.resolved
        let s = summary
        HStack(spacing: 12) {
            Image(systemName: vital.iconSymbol)
                .font(.system(size: 18)).foregroundStyle(t.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(vital.name).font(t.heading(15)).foregroundStyle(t.ink)
                Text(vital.target > 0
                     ? "\(fmt(s.todayTotal)) / \(fmt(vital.target)) \(vital.unit) today"
                     : "\(fmt(s.todayTotal)) \(vital.unit) today")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(t.muted)
            }
            Spacer()
            if s.currentStreak > 0 {
                Label("\(s.currentStreak)", systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(t.accent)
            }
            if vital.target > 0 {
                ProgressRing(progress: s.progress, t: t)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(t.faint)
        }
        .padding(14)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProgressRing: View {
    let progress: Double
    let t: ResolvedTheme
    var body: some View {
        ZStack {
            Circle().stroke(t.hair, lineWidth: 3)
            Circle().trim(from: 0, to: progress)
                .stroke(t.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Detail + history

struct VitalDetailView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Bindable var vital: CustomVital
    @State private var logValue = ""

    private var points: [VitalStats.Point] { (vital.entries ?? []).map { .init(value: $0.value, date: $0.date) } }
    private var summary: VitalStats.Summary { VitalStats.summary(entries: points, target: vital.target) }
    private var sortedEntries: [VitalEntry] { (vital.entries ?? []).sorted { $0.date > $1.date } }

    var body: some View {
        let t = tm.resolved
        let s = summary
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    stat(t, value: fmt(s.todayTotal), label: "Today")
                    stat(t, value: s.weekAverage.map(fmt) ?? "—", label: "7-day avg")
                    stat(t, value: "\(s.currentStreak)", label: "Streak")
                }

                sparkline(t)

                // Quick log.
                HStack(spacing: 10) {
                    TextField("Value", text: $logValue)
                        .keyboardType(.decimalPad)
                        .padding(10).background(t.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                    Text(vital.unit).font(.caption).foregroundStyle(t.muted)
                    Button("Log") { log() }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(t.bg)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(t.accent).clipShape(RoundedRectangle(cornerRadius: 10))
                        .disabled(Double(logValue) == nil)
                }

                if !sortedEntries.isEmpty {
                    Text("History").font(t.heading(16)).foregroundStyle(t.ink)
                    ForEach(sortedEntries) { entry in
                        HStack {
                            Text("\(fmt(entry.value)) \(vital.unit)").font(t.body(14)).foregroundStyle(t.ink)
                            Spacer()
                            Text(entry.date.formatted(.dateTime.month().day().hour().minute()))
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(t.muted)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(t.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(22)
        }
        .background(t.bg)
        .navigationTitle(vital.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func stat(_ t: ResolvedTheme, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(t.heading(18)).foregroundStyle(t.ink)
            Text(label).font(.caption2).foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(t.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func sparkline(_ t: ResolvedTheme) -> some View {
        let totals = VitalStats.dailyTotals(entries: points, days: 7)
        let maxV = max(totals.max() ?? 1, vital.target, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(totals.enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 3)
                    .fill(v > 0 ? t.accent : t.hair)
                    .frame(height: max(4, CGFloat(v / maxV) * 60))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 64)
        .padding(12).background(t.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func log() {
        guard let v = Double(logValue) else { return }
        let entry = VitalEntry(value: v, date: .now)
        entry.vital = vital
        modelContext.insert(entry)
        try? modelContext.save()
        logValue = ""
        Haptics.success()
    }
}

// MARK: - Category picker + editor

private struct VitalCategoryPicker: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss
    let onPick: (VitalCategory) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(VitalCategory.allCases) { category in
                        Button {
                            Haptics.light()
                            onPick(category)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: category.defaultIcon).font(.system(size: 22)).foregroundStyle(t.accent)
                                Text(category.defaultName).font(t.body(13)).foregroundStyle(t.ink)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(t.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(t.bg)
            .navigationTitle("Choose a vital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

private struct VitalEditorSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let category: VitalCategory
    let nextSortIndex: Int

    @State private var name = ""
    @State private var unit = ""
    @State private var target = ""
    @State private var didSeed = false

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            Form {
                Section("Name") { TextField("Name", text: $name) }
                    .listRowBackground(t.surface)
                Section("Unit") { TextField("e.g. hrs, glasses, min", text: $unit) }
                    .listRowBackground(t.surface)
                Section("Daily target") {
                    TextField("0 for no target", text: $target).keyboardType(.decimalPad)
                }
                .listRowBackground(t.surface)
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .navigationTitle("New \(category.defaultName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { save() } }
            }
            .onAppear(perform: seed)
        }
    }

    private func seed() {
        guard !didSeed else { return }
        name = category.defaultName
        unit = category.defaultUnit
        target = category.defaultTarget > 0 ? fmt(category.defaultTarget) : ""
        didSeed = true
    }

    private func save() {
        let vital = CustomVital(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            unit: unit.trimmingCharacters(in: .whitespaces),
            target: Double(target) ?? 0,
            sortIndex: nextSortIndex
        )
        modelContext.insert(vital)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}

/// Compact number formatting shared by the vitals UI: drops a trailing ".0".
private func fmt(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
}
