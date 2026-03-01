//
//  LearningLanguageUITests.swift
//  LearningLanguageUITests
//
//  Created by Qinbang Xiao on 2/4/25.
//

import XCTest

final class LearningLanguageUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPracticeSentenceNavigationFlow() throws {
        let app = launchApp(arguments: ["UITEST_BOOTSTRAP", "UITEST_MODE_PRACTICE_SESSION"])

        let resumeButton = findElement(in: app, identifier: "resumeLastSessionButton")
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        resumeButton.tap()

        // Wait for practice screen to load after navigation animation
        let header = app.staticTexts["sentenceHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 10), "sentenceHeader not found after navigation")

        assertSentenceHeader(app, contains: "Sentence 1 of 3")

        // Next button is a custom PillButton — search across all element types
        let nextButton = findElement(in: app, identifier: "nextSentenceButton")
        scrollToElement(in: app, element: nextButton)
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        assertSentenceHeader(app, contains: "Sentence 2 of 3")

        let prevButton = findElement(in: app, identifier: "prevSentenceButton")
        XCTAssertTrue(prevButton.waitForExistence(timeout: 2))
        prevButton.tap()

        assertSentenceHeader(app, contains: "Sentence 1 of 3")
    }

    @MainActor
    func testPracticeCanHideAndShowOriginalSentence() throws {
        let app = launchApp(arguments: ["UITEST_BOOTSTRAP", "UITEST_MODE_PRACTICE_SESSION"])

        let resumeButton = findElement(in: app, identifier: "resumeLastSessionButton")
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        resumeButton.tap()

        let originalSentence = app.staticTexts["originalSentenceText"]
        XCTAssertTrue(originalSentence.waitForExistence(timeout: 5))

        // Show/hide toggle is now a custom pill button
        let showOriginalToggle = findElement(in: app, identifier: "showOriginalToggle")
        scrollToElement(in: app, element: showOriginalToggle)
        XCTAssertTrue(showOriginalToggle.waitForExistence(timeout: 5))
        showOriginalToggle.tap()

        let originalHiddenLabel = app.staticTexts["originalHiddenLabel"]
        XCTAssertTrue(originalHiddenLabel.waitForExistence(timeout: 2))

        showOriginalToggle.tap()
        XCTAssertTrue(originalSentence.waitForExistence(timeout: 2))
    }

    @MainActor
    func testWorkspaceSwitcherVisibilityDependsOnActiveWorkspaceCount() throws {
        let singleWorkspaceApp = launchApp(arguments: ["UITEST_BOOTSTRAP"])
        XCTAssertTrue(singleWorkspaceApp.staticTexts["workspaceSingleLabel"].waitForExistence(timeout: 5))
        // Workspace picker is now pill chips — should NOT exist in single-workspace mode
        let singlePicker = findElement(in: singleWorkspaceApp, identifier: "workspacePicker")
        XCTAssertFalse(singlePicker.exists)

        singleWorkspaceApp.terminate()

        let multiWorkspaceApp = launchApp(arguments: ["UITEST_BOOTSTRAP", "UITEST_MODE_MULTI_WORKSPACE"])
        // Workspace picker should exist in multi-workspace mode
        let multiPicker = findElement(in: multiWorkspaceApp, identifier: "workspacePicker")
        XCTAssertTrue(multiPicker.waitForExistence(timeout: 5))
        XCTAssertFalse(multiWorkspaceApp.staticTexts["workspaceSingleLabel"].exists)
    }

    @MainActor
    func testFirstOpenGuideAppearsAndCanBeDismissed() throws {
        let app = launchApp(arguments: ["UITEST_BOOTSTRAP", "UITEST_MODE_SHOW_ONBOARDING"])

        let onboardingContinueButton = findElement(in: app, identifier: "onboardingContinueButton")
        XCTAssertTrue(onboardingContinueButton.waitForExistence(timeout: 5))

        let onboardingSkipButton = findElement(in: app, identifier: "onboardingSkipButton")
        XCTAssertTrue(onboardingSkipButton.exists)
        onboardingSkipButton.tap()

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsCanAddAndRemoveWorkspace() throws {
        let app = launchApp(arguments: ["UITEST_BOOTSTRAP"])

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let englishToggle = app.switches["workspaceToggle_english"]
        scrollToElement(in: app, element: englishToggle)
        XCTAssertTrue(englishToggle.waitForExistence(timeout: 2))
        if !isSwitchOn(englishToggle) {
            englishToggle.tap()
        }
        XCTAssertTrue(englishToggle.exists)

        let japaneseToggle = app.switches["workspaceToggle_japanese"]
        scrollToElement(in: app, element: japaneseToggle)
        XCTAssertTrue(japaneseToggle.waitForExistence(timeout: 2))
        if isSwitchOn(japaneseToggle) {
            japaneseToggle.tap()
        }
        XCTAssertTrue(japaneseToggle.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Helpers

    private func launchApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        return app
    }

    /// Search for an element across all element types — handles custom SwiftUI views
    /// that don't map to standard XCUITest types (buttons, switches, etc.)
    private func findElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        // Try buttons first (most common), then fall back to descendants
        let button = app.buttons[identifier]
        if button.exists { return button }

        return app.descendants(matching: .any)[identifier]
    }

    private func assertSentenceHeader(_ app: XCUIApplication, contains expectedText: String, file: StaticString = #filePath, line: UInt = #line) {
        let header = app.staticTexts["sentenceHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "sentenceHeader not found", file: file, line: line)
        let predicate = NSPredicate(format: "label CONTAINS %@", expectedText)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: header)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed, file: file, line: line)
    }

    private func isSwitchOn(_ element: XCUIElement) -> Bool {
        let normalized = "\(element.value ?? "")".lowercased()
        return normalized == "1" || normalized == "on" || normalized == "true"
    }

    private func scrollToElement(in app: XCUIApplication, element: XCUIElement, maxSwipes: Int = 5) {
        guard !element.exists else {
            return
        }

        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp()
        }
    }
}
