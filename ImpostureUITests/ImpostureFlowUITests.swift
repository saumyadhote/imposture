import XCTest

/// Walks the main journeys through real taps. Screenshots are attached to the
/// test results, and also written to `IMPOSTURE_SCREENSHOT_DIR` when that is set.
@MainActor
final class ImpostureFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset"]
        app.launch()
    }

    func testRecommendedCarouselLeadsWithTodayAndSwipesOneCardAtATime() throws {
        completeOnboarding(selecting: ["neck"])
        XCTAssertTrue(app.staticTexts["Hello, Saumya"].waitForExistence(timeout: 5), "Home greets with the onboarding name")
        let first = app.otherElements["home.recommended.day-1"]
        let second = app.otherElements["home.recommended.gentle-mobility"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let centre = app.windows.firstMatch.frame.midX
        XCTAssertEqual(first.frame.midX, centre, accuracy: 2, "A new programme leads with Day 1")
        snapshot("30-home")

        first.swipeLeft(velocity: .slow)
        let settled = NSPredicate { _, _ in abs(second.frame.midX - centre) < 2 }
        wait(for: [expectation(for: settled, evaluatedWith: nil)], timeout: 5)
        XCTAssertFalse(app.buttons["home.catalogue"].exists, "Browse all is no longer on Home")
    }

    func testHomeSectionsLeadToTheirOwnScreens() throws {
        completeOnboarding(selecting: ["neck"])

        let session = app.buttons["home.session.desk-reset"]
        for _ in 0..<8 where !session.isHittable { app.swipeUp() }
        snapshot("31-home-sessions")
        session.tap()
        XCTAssertTrue(app.buttons["routine.start"].waitForExistence(timeout: 5), "A session card opens the routine")
        XCTAssertTrue(app.staticTexts["Desk Reset"].exists)
        snapshot("32-routine-detail")
        app.navigationBars.buttons.firstMatch.tap()

        let concern = app.buttons["home.concern.neck"]
        for _ in 0..<8 where !concern.isHittable { app.swipeUp() }
        snapshot("33-home-concerns")
        concern.tap()
        XCTAssertTrue(app.navigationBars["Tech Neck"].waitForExistence(timeout: 5), "A concern opens its exercises, not a routine")
        XCTAssertFalse(app.buttons["routine.start"].exists)
        snapshot("34-concern")
    }

    func testProgressShowsMetricsAndOpensPostureReport() throws {
        app.terminate()
        app.launchArguments = ["-previewData"]
        app.launch()

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.tabBars.buttons["Progress"].isSelected)
        let posture = app.buttons["progress.posture"]
        XCTAssertTrue(posture.waitForExistence(timeout: 5), "The latest posture check should be on the card")
        for metric in ["Sessions", "Exercise Time", "Consistency", "Tracking Days"] {
            XCTAssertTrue(app.staticTexts[metric].exists, "\(metric) should be shown")
        }
        snapshot("20-progress-week")

        app.segmentedControls["progress.period"].buttons["Last 30 Days"].tap()
        snapshot("21-progress-30-days")
        app.segmentedControls["progress.period"].buttons["Today"].tap()
        snapshot("22-progress-today")

        posture.tap()
        XCTAssertTrue(app.navigationBars["Posture Score"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Posture Range"].exists)
        XCTAssertFalse(app.buttons["Next day"].isEnabled, "Today is the latest day")
        snapshot("23-posture-score")
        app.buttons["Previous day"].tap()
        XCTAssertTrue(app.buttons["Next day"].isEnabled)
        snapshot("24-posture-score-yesterday")
    }

    func testPostureCheckPreparationLeadsToTheCameraCheck() throws {
        completeOnboarding(selecting: ["neck"])
        app.tabBars.buttons["Posture"].tap()
        XCTAssertTrue(app.buttons["posture.begin"].waitForExistence(timeout: 5))
        snapshot("40-posture")
        app.buttons["posture.begin"].tap()

        let headings = [
            "Let's get comfortable.", "Set up your chair and screen.", "Relax your arms. Support your feet.",
            "There's no single perfect sitting posture.", "Position your phone.",
        ]
        for (index, heading) in headings.enumerated() {
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5), "Step \(index + 1) should show")
            snapshot("4\(index + 1)-prepare-\(index + 1)")
            app.buttons["prepare.next"].tap()
        }
        // The Simulator has no camera, so the existing check explains that instead.
        XCTAssertTrue(app.staticTexts["No camera available"].waitForExistence(timeout: 10))
        app.buttons["assessment.close"].tap()
        XCTAssertTrue(app.buttons["posture.begin"].waitForExistence(timeout: 5), "Preparation is cleared after the check")
    }

    func testOnboardingCanBeReplayedFromSettings() throws {
        completeOnboarding(selecting: ["neck"])
        app.tabBars.buttons["Progress"].tap()
        app.navigationBars.buttons["Settings"].tap()
        let replay = app.buttons["settings.replayOnboarding"]
        for _ in 0..<4 where !replay.isHittable { app.swipeUp() }
        replay.tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.start"].waitForExistence(timeout: 5), "Onboarding starts again")
    }

    func testProgressWithNoDataExplainsWhatToDo() throws {
        completeOnboarding(selecting: ["neck"])
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Your progress will appear here"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Consistency"].exists, "No empty metrics before anything is tracked")
        snapshot("25-progress-empty")
    }

    func testNavigationCatalogueAndSingleExercise() throws {
        completeOnboarding(selecting: ["neck", "upperBack"])

        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5), "Home should lead with the next session")
        snapshot("05-home")

        // Exactly three tabs; the catalogue lives on Home.
        XCTAssertEqual(app.tabBars.buttons.count, 3)
        XCTAssertFalse(app.tabBars.buttons["Exercises"].exists)

        // Exercises are reached through a concern.
        let concern = app.buttons["home.concern.shoulders"]
        for _ in 0..<8 where !concern.isHittable { app.swipeUp() }
        snapshot("06-home-concerns")
        concern.tap()
        XCTAssertTrue(app.navigationBars["Rounded Shoulders"].waitForExistence(timeout: 5))
        snapshot("07-concern")

        let shoulderRolls = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Shoulder Rolls'")).firstMatch
        for _ in 0..<6 where !shoulderRolls.isHittable { app.swipeUp() }
        XCTAssertTrue(shoulderRolls.waitForExistence(timeout: 5))
        shoulderRolls.tap()
        XCTAssertTrue(app.buttons["exercise.tryNow"].waitForExistence(timeout: 5))
        snapshot("08-exercise-detail")

        app.buttons["exercise.tryNow"].tap()
        XCTAssertTrue(app.buttons["session.pauseResume"].waitForExistence(timeout: 5))
        app.buttons["session.startNow"].tap()
        sleep(2)
        snapshot("09-session-active")

        app.buttons["session.pauseResume"].tap()
        XCTAssertEqual(app.buttons["session.pauseResume"].label, "Resume")
        app.buttons["session.pauseResume"].tap()
        XCTAssertEqual(app.buttons["session.pauseResume"].label, "Pause")

        // Let the exercise finish naturally.
        XCTAssertTrue(app.buttons["session.done"].waitForExistence(timeout: 90), "Session should complete")
        XCTAssertTrue(app.staticTexts["Session complete"].exists)
        snapshot("10-session-complete")
        app.buttons["session.done"].tap()

        // Progress uses the session that was just saved.
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Shoulder Rolls"].waitForExistence(timeout: 5))
        snapshot("11-progress")

    }

    func testCompletingADayThenStartingTheNextOffersRecovery() throws {
        completeOnboarding(selecting: [])
        let today = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Day 1'")).firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertTrue(app.buttons["routine.start"].waitForExistence(timeout: 5))
        snapshot("12-session-overview")
        app.buttons["routine.start"].tap()

        // Move for long enough to be saved, then step through to the end.
        XCTAssertTrue(app.buttons["session.startNow"].waitForExistence(timeout: 5))
        app.buttons["session.startNow"].tap()
        sleep(17)
        while !app.buttons["session.done"].exists, app.buttons["session.skip"].exists {
            app.buttons["session.skip"].tap()
        }
        XCTAssertTrue(app.staticTexts["Day 1 complete"].waitForExistence(timeout: 5))
        snapshot("13-day-complete")
        app.buttons["session.done"].tap()

        // Home now recommends Day 2; starting it suggests recovery first.
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.staticTexts["You've completed today's session."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["recovery.start"].exists)
        snapshot("14-recovery-sheet")
        app.buttons["recovery.continue"].tap()
        XCTAssertTrue(app.buttons["session.pauseResume"].waitForExistence(timeout: 5), "Continuing starts Day 2")

        // Ending early, with confirmation.
        app.buttons["session.close"].tap()
        let alert = app.alerts["End this session?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["End session"].tap()
        XCTAssertTrue(app.buttons["session.done"].waitForExistence(timeout: 5))
        app.buttons["session.done"].tap()

        // The suggestion isn't repeated the same day.
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["session.pauseResume"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["You've completed today's session."].exists)
    }

    func testInterruptedSessionCanBeResumed() throws {
        completeOnboarding(selecting: [])
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["session.startNow"].waitForExistence(timeout: 5))
        app.buttons["session.startNow"].tap()
        sleep(2)

        // Leave the app; the session pauses and saves.
        XCUIDevice.shared.press(.home)
        sleep(1)

        // Relaunch without resetting state.
        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.buttons["today.resume"].waitForExistence(timeout: 5), "Home should offer to resume")
        snapshot("18-today-resume")
        app.buttons["today.resume"].tap()
        XCTAssertTrue(app.buttons["session.pauseResume"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["session.pauseResume"].label, "Resume", "A resumed session starts paused")
        snapshot("19-session-resumed")
    }

    // MARK: - Helpers

    private func completeOnboarding(selecting areas: [String]) {
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.start"].waitForExistence(timeout: 10), "Onboarding should appear on first launch")
        snapshot("01-onboarding-splash")
        app.descendants(matching: .any)["onboarding.start"].tap()

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        next.tap()
        XCTAssertTrue(app.staticTexts["Ten days, one step at a time"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("01b-onboarding-slide-3")
        next.tap()

        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Saumya")
        snapshot("02-onboarding-name")
        app.buttons["onboarding.nameNext"].tap()

        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 5))
        // Tech neck and rounded shoulders start selected; set exactly the requested areas.
        for area in ["neck", "shoulders", "back", "upperBack"] {
            let card = app.buttons["onboarding.focus.\(area)"]
            if card.isSelected != areas.contains(area) { card.tap() }
        }
        snapshot("03-onboarding-focus")
        app.buttons[areas.isEmpty ? "onboarding.skipFocus" : "onboarding.continue"].tap()

        XCTAssertTrue(app.buttons["onboarding.skipScan"].waitForExistence(timeout: 5))
        snapshot("04-onboarding-scan-intro")
        app.buttons["onboarding.skipScan"].tap()
        XCTAssertTrue(app.buttons["onboarding.buildPlan"].waitForExistence(timeout: 5))
        snapshot("05-onboarding-results")
        app.buttons["onboarding.scanDetails"].tap()
        XCTAssertTrue(app.navigationBars["Scan details"].waitForExistence(timeout: 5))
        snapshot("06-onboarding-scan-details")
        app.navigationBars["Scan details"].buttons["Done"].tap()
        app.buttons["onboarding.buildPlan"].tap()
    }

    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let directory = ProcessInfo.processInfo.environment["IMPOSTURE_SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
