//
//  LearningLanguageApp.swift
//  LearningLanguage
//
//  Created by Qinbang Xiao on 2/4/25.
//

import SwiftUI

@main
struct LearningLanguageApp: App {
    init() {
        UITestBootstrapper.bootstrapIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.themeBackground.ignoresSafeArea())
        }
    }
}
