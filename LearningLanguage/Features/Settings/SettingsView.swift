import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var apiKeyManager: APIKeyManager
    var body: some View {
        NavigationStack { Text("Settings - TODO").navigationTitle("Settings") }
    }
}
