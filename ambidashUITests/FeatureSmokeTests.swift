import XCTest

/// Runtime feature-smoke harness. These tests launch the REAL app on the
/// simulator with the `-uitesting` flag (which skips onboarding and seeds a
/// deterministic profile + sample goal) and then INTERACT with it to prove the
/// features actually work at runtime — "BUILD SUCCEEDED" is not enough.
///
/// Each test is defensive: it uses `waitForExistence(timeout:)`, never force-taps
/// a missing element in a way that aborts the whole suite, and attaches a
/// screenshot at every major step so a human (or a vision model) can confirm the
/// UI is correct, not just that the process stayed alive.
@MainActor
final class FeatureSmokeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Keep running after a soft failure so we still capture screenshots and
        // assert app-state rather than crashing the harness on the first miss.
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Attach a full-screen screenshot under a readable name (keeps it whether or
    /// not the test passes, so the comparison images are always available).
    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The custom tab bar buttons carry stable identifiers (tab.<name>).
    private func tab(_ id: String) -> XCUIElement { app.buttons[id] }

    /// Tap a tab if it exists; record (don't crash) if it's missing.
    @discardableResult
    private func tapTab(_ id: String, timeout: TimeInterval = 5) -> Bool {
        let el = tab(id)
        guard el.waitForExistence(timeout: timeout) else {
            XCTFail("Tab '\(id)' not found")
            return false
        }
        el.tap()
        return true
    }

    /// True once any known main-screen anchor is on screen (app got past onboarding).
    private func mainTabsAppeared(timeout: TimeInterval = 10) -> Bool {
        tab("tab.dashboard").waitForExistence(timeout: timeout)
            || tab("tab.today").waitForExistence(timeout: 1)
            || tab("tab.goals").waitForExistence(timeout: 1)
    }

    // MARK: - Tests

    /// The app skips onboarding under -uitesting and lands on MainTabView.
    func testAppLaunchesToMainTabs() throws {
        XCTAssertTrue(mainTabsAppeared(), "App did not reach MainTabView (still in onboarding?)")
        snap("01-launch-main-tabs")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Tap every tab; the app must stay in the foreground (no crash) on each.
    func testAllTabsNavigateWithoutCrash() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        let tabs = ["tab.dashboard", "tab.today", "tab.goals", "tab.reflect", "tab.mentor"]
        for id in tabs {
            tapTab(id)
            snap("tabs-\(id)")
            XCTAssertEqual(app.state, .runningForeground, "App left foreground after tapping \(id)")
        }
    }

    /// Dashboard scroll moves content (two screenshots so a human can compare).
    func testDashboardScrolls() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        tapTab("tab.dashboard")
        snap("dashboard-before-scroll")

        let scroll = app.scrollViews["dashboard.scroll"]
        if scroll.waitForExistence(timeout: 5) {
            scroll.swipeUp()
        } else {
            // Fall back to swiping the app window if the identifier didn't resolve.
            app.swipeUp()
        }
        snap("dashboard-after-scroll")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Switching typography in Settings should visibly change the rendered fonts.
    func testTypographySwitch() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        tapTab("tab.dashboard")

        // Open Settings via the gear (labelled "Settings") in the dashboard header.
        let gear = app.buttons["Settings"]
        if gear.waitForExistence(timeout: 5) {
            gear.tap()
        } else {
            XCTFail("Settings gear not found on dashboard")
        }
        snap("settings-opened")

        // Switch to Editorial, return to the dashboard, and screenshot it — the
        // DASHBOARD (not Settings, which uses system fonts) is where t.heading/t.body
        // render, so this is where the font change is actually visible.
        let editorial = app.buttons["typography.editorial"]
        guard editorial.waitForExistence(timeout: 5) else {
            XCTFail("typography.editorial option not found"); return
        }
        editorial.tap()
        snap("typography-editorial-settings")
        app.buttons["Done"].firstMatch.tap()
        snap("dashboard-typography-editorial")

        // Now switch to Technical and screenshot the dashboard again, so the two
        // dashboard shots can be compared to PROVE the heading font actually changes.
        app.buttons["Settings"].firstMatch.tap()
        let technical = app.buttons["typography.technical"]
        guard technical.waitForExistence(timeout: 3) else {
            XCTFail("typography.technical option not found"); return
        }
        technical.tap()
        snap("typography-technical-settings")
        app.buttons["Done"].firstMatch.tap()
        snap("dashboard-typography-technical")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Tapping the voice/mic control on Reflect must NOT crash (the reported bug).
    func testVoiceReflectionDoesNotCrash() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        tapTab("tab.reflect")
        snap("reflect-opened")

        // .firstMatch — ReflectView has three reflection questions, each with its
        // own mic, so the identifier resolves to multiple elements.
        let mic = app.buttons["reflect.voiceMic"].firstMatch
        if mic.waitForExistence(timeout: 5) {
            mic.tap()
        } else {
            XCTFail("reflect.voiceMic control not found")
        }

        // Give any permission prompt / audio-session setup a moment to (mis)fire.
        Thread.sleep(forTimeInterval: 2)
        snap("reflect-after-mic-tap")
        XCTAssertEqual(app.state, .runningForeground, "App crashed/backgrounded after mic tap")
    }

    /// The add-goal "+" presents the add-goal sheet.
    func testAddGoal() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        tapTab("tab.goals")
        snap("goals-opened")

        // Try the identifier first; fall back to label/nav-bar queries since toolbar
        // "+" buttons can surface under different element collections.
        let add = app.buttons["goals.add"].firstMatch
        let addByLabel = app.buttons["Add goal"].firstMatch
        let navAdd = app.navigationBars.buttons["goals.add"].firstMatch
        if add.waitForExistence(timeout: 5) {
            add.tap()
        } else if addByLabel.exists {
            addByLabel.tap()
        } else if navAdd.exists {
            navAdd.tap()
        } else {
            XCTFail("goals add button not found (tried goals.add / 'Add goal' / nav bar)")
        }
        snap("goals-add-sheet")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// v4 completion/progress: the Today's Progress component (seeded into the
    /// .balanced board) renders its done-count + progress ring on the dashboard.
    func testTodayProgressComponent() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        tapTab("tab.dashboard")

        let progress = app.otherElements["component.todayProgress"]
        var scrolls = 0
        while !progress.exists && scrolls < 6 {
            app.swipeUp()
            scrolls += 1
        }
        snap("today-progress-component")
        XCTAssertTrue(progress.exists, "Today's Progress component not found on the board")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// v4 sticky secondary goals: the Sticky Notes component (placed high in the
    /// .balanced board) shows the seeded pinned goal as a glanceable note card.
    func testStickyGoalsComponent() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        tapTab("tab.dashboard")

        let sticky = app.otherElements["component.stickyGoals"]
        let scrollView = app.scrollViews["dashboard.scroll"].exists
            ? app.scrollViews["dashboard.scroll"] : app.scrollViews.firstMatch
        var scrolls = 0
        while !sticky.exists && scrolls < 6 {
            scrollView.swipeUp(velocity: .fast)
            scrolls += 1
        }
        Thread.sleep(forTimeInterval: 0.5)
        snap("sticky-goals-component")
        XCTAssertTrue(sticky.exists, "Sticky Notes component not found on the board")
        XCTAssertTrue(app.staticTexts["Run a 5K"].exists, "Seeded pinned goal not shown in Sticky Notes")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// v4 1–7 day view: the Week Ahead component (seeded into the .balanced board)
    /// renders the next-7-days look-ahead with the seeded "Midterm" deadline.
    func testWeekAheadComponent() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        tapTab("tab.dashboard")

        let weekAhead = app.otherElements["component.weekAhead"]
        // Scroll until the seeded "Midterm" deadline is actually hittable (fully
        // on-screen) so the proof screenshot clearly shows the look-ahead with data.
        let midterm = app.staticTexts["Midterm"]
        let scrollView = app.scrollViews.firstMatch
        var scrolls = 0
        while !midterm.isHittable && scrolls < 10 {
            if scrollView.exists { scrollView.swipeUp(velocity: .fast) } else { app.swipeUp(velocity: .fast) }
            scrolls += 1
        }
        Thread.sleep(forTimeInterval: 0.6)   // let the scroll settle before capturing
        snap("week-ahead-component")
        XCTAssertTrue(weekAhead.exists, "Week Ahead component not found on the board")
        XCTAssertTrue(midterm.exists, "Seeded 'Midterm' deadline not shown in Week Ahead")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// v4 calendar integration: the "Add goals to Calendar" toggle exists, flips,
    /// and adding a goal with it on does not crash (Reminders access is skipped in
    /// -uitesting, so this verifies the UI + the no-crash path; the actual EventKit
    /// write needs an on-device check).
    func testCalendarSyncToggle() throws {
        XCTAssertTrue(mainTabsAppeared(), "Main tabs never appeared")
        tapTab("tab.dashboard")
        app.buttons["Settings"].firstMatch.tap()

        // Settings is a long Form — the Integrations toggle is below the fold, so
        // scroll it into view (XCUITest doesn't auto-scroll to a queried element).
        let toggle = app.switches["settings.calendarSync"]
        var scrolls = 0
        while !toggle.exists && scrolls < 6 {
            app.swipeUp()
            scrolls += 1
        }
        guard toggle.waitForExistence(timeout: 3) else {
            XCTFail("settings.calendarSync toggle not found after scrolling"); return
        }
        snap("calendar-sync-before")
        toggle.tap()
        snap("calendar-sync-after")
        XCTAssertEqual(app.state, .runningForeground, "App crashed toggling calendar sync")

        // Add a goal with sync ON — must not crash.
        app.buttons["Done"].firstMatch.tap()
        if tapTab("tab.goals") {
            let add = app.buttons["goals.add"].firstMatch
            if add.waitForExistence(timeout: 5) {
                add.tap()
                snap("calendar-sync-add-goal")
            }
        }
        XCTAssertEqual(app.state, .runningForeground)
    }
}
