import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Desktop Goals: a master list grouped by life pillar, with an inline
/// detail/editor pane, add-goal sheet, and JSON file import. Reads and writes the
/// SAME `Goal` models as iOS, so adds/edits/imports round-trip via CloudKit.
struct MacGoalsView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var context

    @Query(sort: \Goal.priority) private var goals: [Goal]
    @Query private var profiles: [UserProfile]

    @State private var selection: Goal?
    @State private var showingAdd = false
    @State private var groupByPillar = true
    @State private var showImporter = false
    @State private var importMessage: String?

    private var profile: UserProfile? { profiles.first }

    /// Goals grouped by their life dimension (pillar), only pillars with goals.
    private var byPillar: [(LifeDimension, [Goal])] {
        LifeDimension.allCases.compactMap { dim in
            let g = goals.filter { $0.domain.dimension == dim }
            return g.isEmpty ? nil : (dim, g)
        }
    }

    var body: some View {
        let theme = tm.resolved
        MacScreen("Goals", subtitle: "\(goals.count) tracked") {
            HStack(spacing: 10) {
                Toggle("By pillar", isOn: $groupByPillar)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Button {
                    showImporter = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Goal", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        } content: {
            if let importMessage {
                MacCard {
                    Text(importMessage)
                        .font(theme.body(13))
                        .foregroundStyle(theme.accent)
                }
            }

            if goals.isEmpty {
                MacCard {
                    Text("No goals yet. Add your first goal or import a JSON file to start tracking.")
                        .font(theme.body(14))
                        .foregroundStyle(theme.muted)
                }
            } else if groupByPillar {
                ForEach(byPillar, id: \.0) { dim, dimGoals in
                    HStack(spacing: 8) {
                        Circle().fill(AmbidashTheme.dimensionColor(for: dim)).frame(width: 9, height: 9)
                        Text(dim.fullName.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.muted)
                            .tracking(0.5)
                    }
                    .padding(.top, 4)
                    ForEach(dimGoals) { goal in goalEntry(goal) }
                }
            } else {
                ForEach(goals) { goal in goalEntry(goal) }
            }
        }
        .sheet(isPresented: $showingAdd) {
            MacAddGoalView()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    @ViewBuilder
    private func goalEntry(_ goal: Goal) -> some View {
        Button {
            selection = (selection?.id == goal.id) ? nil : goal
        } label: {
            goalRow(goal)
        }
        .buttonStyle(.plain)

        if selection?.id == goal.id {
            MacGoalDetailView(goal: goal)
                .padding(.bottom, 6)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "Couldn't read that file."
                return
            }
            let summary = GoalImportService.importGoals(from: data, context: context, profile: profile)
            if let err = summary.error {
                importMessage = err
            } else {
                let skip = summary.skipped > 0 ? " · skipped \(summary.skipped) already there/empty" : ""
                importMessage = "Imported \(summary.imported) goal\(summary.imported == 1 ? "" : "s")\(skip)."
            }
        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        let theme = tm.resolved
        HStack(spacing: 12) {
            Image(systemName: goal.domain.icon)
                .foregroundStyle(AmbidashTheme.dimensionColor(for: goal.domain.dimension))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                    .font(theme.body(15))
                    .foregroundStyle(theme.ink)
                Text(goal.domain.displayName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.muted)
            }
            Spacer()
            if goal.hasTarget {
                Text("\(Int(goal.percentComplete * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.accent)
            }
            Circle()
                .fill(goal.computedStatus.color)
                .frame(width: 8, height: 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selection?.id == goal.id ? theme.accent : theme.hair, lineWidth: 1)
        )
    }
}

/// Inline detail + lightweight editor for one goal.
struct MacGoalDetailView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var context
    @Bindable var goal: Goal

    var body: some View {
        let theme = tm.resolved
        MacCard("Details") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledField("Title") {
                    TextField("Title", text: $goal.title)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledField("Subtitle") {
                    TextField("Subtitle", text: $goal.subtitle)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledField("Domain") {
                    Picker("Domain", selection: domainBinding) {
                        ForEach(GoalDomain.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .labelsHidden()
                }
                LabeledField("Details") {
                    TextEditor(text: $goal.details)
                        .font(theme.body(13))
                        .frame(minHeight: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(theme.hair, lineWidth: 1)
                        )
                }

                Toggle("Active", isOn: $goal.isActive)
                    .toggleStyle(.switch)

                if goal.metricEnabled {
                    LabeledField("Current Value") {
                        TextField("Current", value: $goal.currentValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                }

                HStack {
                    Spacer()
                    Button("Save") { try? context.save() }
                        .buttonStyle(.borderedProminent)
                    Button(role: .destructive) {
                        context.delete(goal)
                        try? context.save()
                    } label: {
                        Text("Delete")
                    }
                }
            }
        }
    }

    private var domainBinding: Binding<GoalDomain> {
        Binding(
            get: { goal.domain },
            set: { goal.domainRaw = $0.rawValue }
        )
    }
}

/// Sheet to create a new goal.
struct MacAddGoalView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var domain: GoalDomain = .craft

    var body: some View {
        let theme = tm.resolved
        VStack(alignment: .leading, spacing: 16) {
            Text("New Goal")
                .font(theme.heading(22))
                .foregroundStyle(theme.ink)

            LabeledField("Title") {
                TextField("e.g. Run a half marathon", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField("Domain") {
                Picker("Domain", selection: $domain) {
                    ForEach(GoalDomain.allCases, id: \.self) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let goal = Goal(title: title, domain: domain, priority: 0)
                    goal.isActive = true
                    context.insert(goal)
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(theme.bg)
    }
}

/// A small label-above-control row used by the mac forms.
struct LabeledField<Content: View>: View {
    @Environment(ThemeManager.self) private var tm
    let label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        let theme = tm.resolved
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.muted)
            content
        }
    }
}
