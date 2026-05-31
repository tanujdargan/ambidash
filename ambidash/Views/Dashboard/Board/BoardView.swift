import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Renders the single active `Board` as ordered section bands (top → body → focus),
/// each a `LazyVStack` of components produced by `ComponentRegistry`, reading a
/// pre-computed `BoardData` value struct (compute-once at the dashboard level).
///
/// Build B: the component set is now DB-BACKED. On first appearance `BoardSeeder`
/// guarantees an active board (seeding the balanced template once if none exists).
/// An explicit, labeled EDIT MODE lets the user reorder (drag → rewrite gapped
/// `sortIndex`), move across sections (drag → update `sectionRaw`), remove
/// (`isVisible = false`, reversible), and resize (segmented control, multi-size
/// kinds). A summoned "+" opens `AddComponentSheet`. Every mutation autosaves to
/// SwiftData. `MotionPreference` + `Haptics` are respected throughout.
struct BoardView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    let boardData: BoardData
    let onTapScore: (ScoreBreakdownTarget) -> Void

    /// All components belonging to the active board. We query every board's
    /// components and resolve to the active board's set in `boardComponents`
    /// (CloudKit + #Predicate can't traverse the optional relationship to
    /// `board.isActive` reliably, so we filter in-memory off the resolved board).
    @Query private var allComponents: [BoardComponent]

    @State private var editing = false
    @State private var showAddSheet = false
    /// The component id currently being dragged in edit mode (for drop math + a
    /// subtle visual treatment).
    @State private var draggingID: UUID?
    /// The component whose config sheet is open (tap "configure" in edit mode).
    @State private var configuringComponent: BoardComponent?
    /// True on first dashboard load when no board exists yet — drives the
    /// board-setup template picker (default Calm) instead of an auto-seed.
    @State private var showTemplatePicker = false
    /// Guards the first-load decision so we only evaluate "has a board?" once.
    @State private var didCheckForBoard = false
    /// The always-accessible <2s quick-capture sheet (design principle #4). Lives in
    /// the board control bar so a thought can be dumped from the main dashboard with
    /// one tap, no matter which components are on the board.
    @State private var showQuickCapture = false
    /// Shows the kind confirmation after spending a banked rest day.
    @State private var restSpentConfirmation = false

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.section) {
            controlBar(t)

            // "TODAY IS HARD" — a gentle banner + rest-bank chip when today is marked
            // hard (or whenever a banked rest day is available to spend). Shown above the
            // (transiently minimal) board; never present in edit mode.
            if !editing {
                hardModeArea(t)
            }

            if components.isEmpty {
                emptyBoardState(t)
            } else {
                ForEach(orderedSections, id: \.self) { section in
                    sectionBand(section, t)
                }
            }
        }
        .animation(MotionPreference.animation(.ambidashSpring), value: editing)
        .onAppear { evaluateFirstLoad() }
        .sheet(isPresented: $showAddSheet) {
            AddComponentSheet(presentKinds: presentKinds) { kind in
                addComponent(kind)
                showAddSheet = false
            }
            .environment(tm)
        }
        .sheet(item: $configuringComponent) { component in
            ComponentConfigSheet(component: component, boardData: boardData) { newConfig in
                applyConfig(newConfig, to: component)
            }
            .environment(tm)
        }
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureSheet().environment(tm)
        }
        .sheet(isPresented: $showTemplatePicker) {
            BoardSetupView(mode: .firstRun) { template in
                BoardSeeder.seed(template: template, in: modelContext)
                showTemplatePicker = false
            }
            .environment(tm)
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Control bar (explicit add + edit affordances)

    @ViewBuilder
    private func controlBar(_ t: ResolvedTheme) -> some View {
        HStack(spacing: 12) {
            if editing {
                Text("Editing board")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(t.accent)
            } else {
                // Always-accessible <2s capture affordance (design principle #4). A
                // labeled pill so it reads as "dump a thought", distinct from the
                // "+" that adds a board component.
                Button {
                    Haptics.light()
                    showQuickCapture = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Capture")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .tracking(0.6)
                    }
                    .foregroundStyle(t.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(t.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(t.hair, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .accessibilityLabel("Capture a thought")
            }
            Spacer()
            Button {
                Haptics.light()
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(t.accent)
                    .frame(width: 30, height: 30)
                    .background(t.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(t.hair, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel("Add component")

            Button {
                Haptics.selection()
                withAnimation(MotionPreference.animation(.ambidashSpring)) {
                    editing.toggle()
                }
            } label: {
                Text(editing ? "Done" : "Edit")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(editing ? t.bg : t.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(editing ? AnyShapeStyle(t.accent) : AnyShapeStyle(t.surface))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(t.hair, lineWidth: editing ? 0 : 0.5))
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel(editing ? "Done editing board" : "Edit board")
        }
    }

    // MARK: - "Today is hard" mode + rest-day bank

    /// The resolved UserPreferences for the signed-in profile (where the per-day hard
    /// flag + the rest-day bank live). Reached through the boardData snapshot.
    private var prefs: UserPreferences? { boardData.profile?.userPreferences }

    /// Banner (when today is hard) + the toggle / rest-bank chip row. Renders nothing
    /// when there's no profile/prefs to mutate.
    @ViewBuilder
    private func hardModeArea(_ t: ResolvedTheme) -> some View {
        if let prefs {
            VStack(alignment: .leading, spacing: t.space.component) {
                if boardData.isHardDay {
                    hardModeBanner(t)
                }
                hardModeControls(prefs, t)
            }
            .animation(MotionPreference.animation(.ambidashSpring), value: boardData.isHardDay)
        }
    }

    /// The calm "today, just one thing" banner shown when the board is in hard mode.
    @ViewBuilder
    private func hardModeBanner(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(t.deferred)
                Text(HardModeService.headline)
                    .font(.system(size: 16, weight: tm.typography.serifWeight, design: .serif))
                    .foregroundStyle(t.ink)
                Spacer(minLength: 0)
            }
            Text(HardModeService.subhead)
                .font(.system(size: 12))
                .foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.deferred.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            t.deferred.frame(width: 2).clipShape(RoundedRectangle(cornerRadius: 1)).padding(.vertical, 1)
        }
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(HardModeService.headline) \(HardModeService.subhead)")
    }

    /// The hard-mode toggle chip + (when a rest day is available) the spend-a-rest-day
    /// chip. Both framed as permission, never obligation.
    @ViewBuilder
    private func hardModeControls(_ prefs: UserPreferences, _ t: ResolvedTheme) -> some View {
        let isHard = boardData.isHardDay
        HStack(spacing: 8) {
            // Today-is-hard toggle.
            Button {
                toggleHardMode(prefs)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isHard ? "heart.circle.fill" : "heart.circle")
                        .font(.system(size: 12))
                    Text(isHard ? "Hard day on" : "Today is hard")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(isHard ? t.accent : t.muted)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(isHard ? t.accentSoft : t.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isHard ? t.accent.opacity(0.4) : t.hair, lineWidth: isHard ? 1 : 0.5))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel(isHard ? "Turn off hard day" : "Mark today as hard")

            // Rest-day bank chip (only when there's a day available to spend today).
            if RestBankService.canSpend(prefs) {
                Button {
                    spendRestDay(prefs)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 12))
                        Text(prefs.bankedRestDays == 1 ? "Use a rest day" : "Use a rest day · \(prefs.bankedRestDays)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(t.deferred)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(t.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(t.hair, lineWidth: 0.5))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .accessibilityLabel(RestBankService.chipLabel(prefs))
            }
            Spacer(minLength: 0)
        }
        .alert("Rest day, on the house.", isPresented: $restSpentConfirmation) {
            Button("Thanks") { restSpentConfirmation = false }
        } message: {
            Text("Today's a rest day — you earned it. Your streaks are safe, and nothing carries any guilt. Be kind to yourself.")
        }
    }

    /// Toggle the per-day hard flag and persist. The board re-derives `isHardDay` from
    /// the freshly-saved prefs on the next render (DashboardView rebuilds BoardData).
    private func toggleHardMode(_ prefs: UserPreferences) {
        Haptics.selection()
        withAnimation(MotionPreference.animation(.ambidashSpring)) {
            HardModeService.toggle(prefs)
        }
        save()
    }

    /// Spend a banked rest day: decrement the bank, mark today hard (so the board goes
    /// minimal), and show the kind confirmation. Idempotent per day via the service.
    private func spendRestDay(_ prefs: UserPreferences) {
        guard RestBankService.spend(prefs) else { return }
        // Spending a rest day auto-enables the minimal/hard board for the day — the
        // whole point is a guilt-free soft day.
        HardModeService.markHard(prefs)
        save()
        Haptics.success()
        withAnimation(MotionPreference.animation(.ambidashSpring)) {
            restSpentConfirmation = true
        }
    }

    // MARK: - Section bands

    @ViewBuilder
    private func sectionBand(_ section: BoardSection, _ t: ResolvedTheme) -> some View {
        let inSection = components(in: section)
        if !inSection.isEmpty || editing {
            VStack(alignment: .leading, spacing: t.space.component) {
                if editing {
                    sectionHeader(section, t)
                }
                LazyVStack(alignment: .leading, spacing: t.space.section) {
                    ForEach(inSection, id: \.id) { component in
                        componentSlot(component, in: section, t)
                            .id(component.id)
                    }
                    if editing && inSection.isEmpty {
                        emptySectionDrop(section, t)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ section: BoardSection, _ t: ResolvedTheme) -> some View {
        SectionLabel(title: sectionTitle(section))
            .opacity(0.8)
    }

    private func sectionTitle(_ section: BoardSection) -> String {
        switch section {
        case .top: "Top"
        case .body: "Body"
        case .focus: "Focus"
        }
    }

    /// One component slot. In normal mode it's the plain renderer; in edit mode it's
    /// wrapped with remove / resize controls and is draggable + a drop target.
    @ViewBuilder
    private func componentSlot(_ component: BoardComponent, in section: BoardSection, _ t: ResolvedTheme) -> some View {
        if editing {
            EditableComponentRow(
                component: component,
                boardData: boardData,
                isDragging: draggingID == component.id,
                onRemove: { remove(component) },
                onResize: { newSize in resize(component, to: newSize) },
                onConfigure: { configuringComponent = component }
            )
            .opacity(draggingID == component.id ? 0.4 : 1)
            .onDrag {
                draggingID = component.id
                return NSItemProvider(object: component.id.uuidString as NSString)
            }
            .onDrop(
                of: [UTType.text],
                delegate: ComponentDropDelegate(
                    target: component,
                    section: section,
                    move: { id in move(componentID: id, before: component, in: section) },
                    end: { draggingID = nil }
                )
            )
        } else {
            ComponentRegistry.render(
                component,
                boardData: boardData,
                onTapScore: onTapScore
            )
        }
    }

    /// A drop target shown for an empty section in edit mode so a component can be
    /// dragged into a section that currently has nothing in it.
    @ViewBuilder
    private func emptySectionDrop(_ section: BoardSection, _ t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 12))
            Text("Drag a component here")
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundStyle(t.faint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(t.sunken.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(t.hair)
        )
        .onDrop(
            of: [UTType.text],
            delegate: ComponentDropDelegate(
                target: nil,
                section: section,
                move: { id in moveToEnd(componentID: id, in: section) },
                end: { draggingID = nil }
            )
        )
    }

    @ViewBuilder
    private func emptyBoardState(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .font(.system(size: 26))
                .foregroundStyle(t.faint)
            Text("Your board is empty")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(t.ink)
            Text("Tap + to add components.")
                .font(.system(size: 12))
                .foregroundStyle(t.muted)
            Button {
                Haptics.light()
                showAddSheet = true
            } label: {
                Text("Add component")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(t.bg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(t.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Resolved board / components

    /// The active board resolved from the queried components. Build B has a single
    /// active board (seeded once); if duplicates ever arise, the seeder collapses
    /// them on the next `ensureActiveBoard`.
    private var activeBoard: Board? {
        allComponents.compactMap(\.board).first { $0.isActive }
    }

    /// Visible components of the active board (hidden ones are filtered out of the
    /// render tree in both modes — edit mode toggles visibility, it doesn't show
    /// hidden rows inline).
    ///
    /// "TODAY IS HARD" — when today is marked hard AND we're not editing, the set is
    /// TRANSIENTLY narrowed to `HardModeService.minimalAllowList`. This is a view-level
    /// filter only: the persisted board (sortIndex/section/visibility) is untouched, so
    /// the user's real layout returns intact the moment the flag clears or the day rolls
    /// over. In edit mode the full board always shows so the user can still configure it.
    private var components: [BoardComponent] {
        guard let board = activeBoard else { return [] }
        let visible = allComponents.filter { $0.board?.id == board.id && $0.isVisible }
        if boardData.isHardDay && !editing {
            return visible.filter { HardModeService.allowsOnHardDay($0.kind) }
        }
        return visible
    }

    /// Kinds present on the board (visible OR hidden) — drives singleton "Added"
    /// state in the add-menu so a hidden singleton can't be re-added as a duplicate.
    private var presentKinds: Set<ComponentKind> {
        guard let board = activeBoard else { return [] }
        return Set(allComponents.filter { $0.board?.id == board.id }.map(\.kind))
    }

    /// Sections present (in render order). In edit mode we always show all sections
    /// so empty ones are available as drop targets.
    private var orderedSections: [BoardSection] {
        if editing {
            return BoardSection.allCases.sorted { $0.order < $1.order }
        }
        return Array(Set(components.map(\.section))).sorted { $0.order < $1.order }
    }

    private func components(in section: BoardSection) -> [BoardComponent] {
        components
            .filter { $0.section == section }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    // MARK: - First-load / seeding

    /// On first appearance, decide between the board-setup template picker (no
    /// board exists yet → let the user choose, default Calm) and rendering the
    /// existing board. Runs once. A board is only auto-seeded as a safety net if a
    /// component query already shows rows but no picker has run (e.g. a board synced
    /// in from another device), so the user is never left blank.
    private func evaluateFirstLoad() {
        guard !didCheckForBoard else { return }
        didCheckForBoard = true
        if BoardSeeder.hasActiveBoard(in: modelContext) {
            return
        }
        showTemplatePicker = true
    }

    /// Persist a new config JSON onto a component (the config sheet calls this on
    /// each option change).
    private func applyConfig(_ json: String, to component: BoardComponent) {
        guard component.configJSON != json else { return }
        component.configJSON = json
        save()
    }

    // MARK: - Mutations (all autosave)

    /// Insert a new component for `kind` into its default section at `maxSort + 10`
    /// with its default config.
    private func addComponent(_ kind: ComponentKind) {
        let board = BoardSeeder.ensureActiveBoard(in: modelContext)
        guard let descriptor = ComponentRegistry.descriptor(for: kind) else { return }

        // If a hidden instance exists, un-hide it instead of inserting a duplicate
        // (keeps singletons singular and is the natural "re-add" path).
        if let hidden = allComponents.first(where: { $0.board?.id == board.id && $0.kind == kind && !$0.isVisible }) {
            hidden.isVisible = true
            save()
            return
        }

        let section = descriptor.defaultSection
        let maxSort = allComponents
            .filter { $0.board?.id == board.id && $0.section == section }
            .map(\.sortIndex)
            .max() ?? -10
        let size = descriptor.supportedSizes.first ?? .medium

        let component = BoardComponent(
            kindRaw: kind.rawValue,
            sectionRaw: section.rawValue,
            sortIndex: maxSort + 10,
            isVisible: true,
            sizeRaw: size.rawValue,
            configJSON: descriptor.defaultConfig
        )
        component.board = board
        modelContext.insert(component)
        save()
    }

    /// Soft-remove (reversible): hide the component instead of deleting it.
    private func remove(_ component: BoardComponent) {
        Haptics.light()
        withAnimation(MotionPreference.animation(.ambidashSpring)) {
            component.isVisible = false
        }
        save()
    }

    private func resize(_ component: BoardComponent, to size: CardSize) {
        guard component.size != size else { return }
        Haptics.selection()
        component.sizeRaw = size.rawValue
        save()
    }

    /// Move the dragged component to sit just before `target` in `section`,
    /// rewriting that section's `sortIndex` to a fresh gapped sequence and updating
    /// `sectionRaw` for a cross-section move.
    private func move(componentID: UUID, before target: BoardComponent, in section: BoardSection) {
        guard
            let board = activeBoard,
            let dragged = allComponents.first(where: { $0.id == componentID }),
            dragged.id != target.id
        else { return }

        // Build the target section's ordered, visible list WITHOUT the dragged one,
        // then splice the dragged component in just before the target.
        var ordered = allComponents
            .filter { $0.board?.id == board.id && $0.isVisible && $0.section == section && $0.id != componentID }
            .sorted { $0.sortIndex < $1.sortIndex }

        let insertAt = ordered.firstIndex(where: { $0.id == target.id }) ?? ordered.count
        dragged.sectionRaw = section.rawValue
        ordered.insert(dragged, at: insertAt)

        renumber(ordered)
        Haptics.light()
        save()
    }

    /// Move the dragged component to the END of `section` (used when dropping into
    /// an empty section).
    private func moveToEnd(componentID: UUID, in section: BoardSection) {
        guard
            let board = activeBoard,
            let dragged = allComponents.first(where: { $0.id == componentID })
        else { return }

        var ordered = allComponents
            .filter { $0.board?.id == board.id && $0.isVisible && $0.section == section && $0.id != componentID }
            .sorted { $0.sortIndex < $1.sortIndex }

        dragged.sectionRaw = section.rawValue
        ordered.append(dragged)

        renumber(ordered)
        Haptics.light()
        save()
    }

    /// Rewrite a section's components to a fresh gapped (0,10,20…) `sortIndex`.
    private func renumber(_ ordered: [BoardComponent]) {
        for (offset, component) in ordered.enumerated() {
            component.sortIndex = offset * 10
        }
    }

    private func save() {
        try? modelContext.save()
    }
}

// MARK: - Drop delegate

/// Routes a dragged component id onto a target slot (or an empty section). Calls
/// `move` once when the drop is performed and `end` to clear drag state.
private struct ComponentDropDelegate: DropDelegate {
    /// The component this slot represents (nil for an empty-section drop zone).
    let target: BoardComponent?
    let section: BoardSection
    let move: (UUID) -> Void
    let end: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else {
            end()
            return false
        }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String, let id = UUID(uuidString: string) else {
                Task { @MainActor in end() }
                return
            }
            Task { @MainActor in
                move(id)
                end()
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {}

    func dropExited(info: DropInfo) {}

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }
}
