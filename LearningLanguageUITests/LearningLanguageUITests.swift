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
    func testPracticeSentenceSliderAndDoneNextFlow() throws {
        let app = launchApp(arguments: ["UITEST_BOOTSTRAP", "UITEST_MODE_PRACTICE_SESSION"])

        let resumeButton = app.buttons["resumeLastSessionButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        resumeButton.tap()

        assertSentenceHeader(app, contains: "Sentence 1 of 3")

        let transcriptField = app.textFields["userTranscriptField"]
        XCTAssertTrue(transcriptField.waitForExistence(timeout: 5))
        transcriptField.tap()
        transcriptField.typeText("hello world")

        let compareButton = app.buttons["compareButton"]
        XCTAssertTrue(compareButton.waitForExistence(timeout: 2))
        compareButton.tap()

        let doneAndNextButton = app.buttons["doneAndNextButton"]
        XCTAssertTrue(doneAndNextButton.waitForExistence(timeout: 2))
        doneAndNextButton.tap()

        assertSentenceHeader(app, contains: "Sentence 2 of 3")

        let sentenceSlider = app.sliders["sentenceSlider"]
        XCTAssertTrue(sentenceSlider.waitForExistence(timeout: 2))
        sentenceSlider.adjust(toNormalizedSliderPosition: 0.0)
    }

    @MainActor
    func testPracticeCanHideAndShowOriginalSentence() throws {
        let app = launchApp(arguments: ["UITEST_BOOTSTRAP", "UITEST_MODE_PRACTICE_SESSION"])

        let resumeButton = app.buttons["resumeLastSessionButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        resumeButton.tap()

        let originalSentence = app.staticTexts["originalSentenceText"]
        XCTAssertTrue(originalSentence.waitForExistence(timeout: 5))

        let showOriginalToggle = app.switches["showOriginalToggle"]
        XCTAssertTrue(showOriginalToggle.waitForExistence(timeout: 2))
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
        XCTAssertFalse(singleWorkspaceApp.segmentedControls["workspacePicker"].exists)

        singleWorkspaceApp.terminate()

        let multiWorkspaceApp = launchApp(arguments: ["UITEST_BOOTSTRAP", "UITEST_MODE_MULTI_WORKSPACE"])
        XCTAssertTrue(multiWorkspaceApp.segmentedControls["workspacePicker"].waitForExistence(timeout: 5))
        XCTAssertFalse(multiWorkspaceApp.staticTexts["workspaceSingleLabel"].exists)
    }

    @MainActor
    func testFirstOpenGuideAppearsAndCanBeDismissed() throws {
        let app = launchApp(arguments: ["UITEST_BOOTSTRAP", "UITEST_MODE_SHOW_ONBOARDING"])

        let onboardingContinueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(onboardingContinueButton.waitForExistence(timeout: 5))

        let onboardingSkipButton = app.buttons["onboardingSkipButton"]
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

    private func launchApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        return app
    }

    private func assertSentenceHeader(_ app: XCUIApplication, contains expectedText: String, file: StaticString = #filePath, line: UInt = #line) {
        let header = app.staticTexts["sentenceHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), file: file, line: line)
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
