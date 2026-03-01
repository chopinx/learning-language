import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var apiKeyManager: APIKeyManager
    @State private var apiKeyDraft: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Settings")
                                .font(.largeTitle.weight(.bold))
                            Text("API key and workspace preferences")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 2)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deepgram API Key")
                                .font(.headline)

                            SecureField("Enter API key", text: $apiKeyDraft)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("deepgramAPIKeyField")

                            HStack(spacing: 8) {
                                Button {
                                    let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                    apiKeyManager.saveKey(trimmedKey)

                                    // Keep draft visible so the user can retry if save/validation fails.
                                    if !trimmedKey.isEmpty {
                                        apiKeyDraft = trimmedKey
                                    }
                                } label: {
                                    Text("Save Key")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("saveAPIKeyButton")

                                Button {
                                    Task { @MainActor in
                                        await apiKeyManager.validateKey(apiKeyDraft)
                                    }
                                } label: {
                                    Text("Validate Key")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(apiKeyManager.isValidating)
                                .accessibilityIdentifier("validateAPIKeyButton")

                                Button(role: .destructive) {
                                    apiKeyManager.clearKey()
                                    apiKeyDraft = ""
                                } label: {
                                    Text("Clear")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("clearAPIKeyButton")
                            }
                            .controlSize(.large)

                            if apiKeyManager.isValidating {
                                ProgressView("Validating key...")
                            }

                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(validationColor)
                        }
                        .appCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Workspace")
                                .font(.headline)

                            Text("Current workspace: \(viewModel.selectedWorkspace.displayName)")

                            Picker("Default workspace", selection: defaultWorkspaceBinding) {
                                ForEach(viewModel.activeWorkspaces) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("defaultWorkspacePicker")

                            if viewModel.activeWorkspaces.count == 1 {
                                Text("Only one workspace is active, so workspace switching is hidden on Home.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(WorkspaceLanguage.allCases) { language in
                                Toggle(
                                    language.displayName,
                                    isOn: workspaceActiveBinding(for: language)
                                )
                                .accessibilityIdentifier("workspaceToggle_\(language.rawValue)")
                                .disabled(
                                    viewModel.isWorkspaceActive(language) &&
                                        !viewModel.canDeactivateWorkspace(language)
                                )
                            }

                            Text("At least one language workspace must stay active.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Toggle("Show original sentence by default", isOn: showOriginalBinding)
                        }
                        .appCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy")
                                .font(.headline)
                            Text("API key is stored in Keychain.")
                        }
                        .appCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                apiKeyDraft = apiKeyManager.savedKey ?? ""
            }
        }
    }

    private var showOriginalBinding: Binding<Bool> {
        Binding {
            viewModel.workspaceState.showOriginalByDefault
        } set: { newValue in
            viewModel.setShowOriginalByDefault(newValue)
        }
    }

    private var defaultWorkspaceBinding: Binding<WorkspaceLanguage> {
        Binding {
            viewModel.workspaceConfig.defaultWorkspace
        } set: { newValue in
            viewModel.setDefaultWorkspace(newValue)
        }
    }

    private func workspaceActiveBinding(for language: WorkspaceLanguage) -> Binding<Bool> {
        Binding {
            viewModel.isWorkspaceActive(language)
        } set: { isActive in
            viewModel.setWorkspaceActive(language, isActive: isActive)
        }
    }

    private var validationMessage: String {
        switch apiKeyManager.validationState {
        case .unknown:
            return "No validation yet"
        case let .valid(message), let .invalid(message):
            return message
        }
    }

    private var validationColor: Color {
        switch apiKeyManager.validationState {
        case .unknown:
            return .secondary
        case .valid:
            return .green
        case .invalid:
            return .red
        }
    }
}
