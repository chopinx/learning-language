import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var apiKeyManager: APIKeyManager
    @State private var apiKeyDraft: String = ""

    var body: some View {
        NavigationStack {
            List {
                apiKeySection
                workspaceSection
                showOriginalSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                apiKeyDraft = apiKeyManager.savedKey ?? ""
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        Section {
            SecureField("Enter Deepgram API key", text: $apiKeyDraft)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("deepgramAPIKeyField")

            HStack(spacing: 12) {
                Button("Save") {
                    apiKeyManager.saveKey(apiKeyDraft)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.themePrimary)
                .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("saveAPIKeyButton")

                Button("Validate") {
                    Task { await apiKeyManager.validateKey(apiKeyDraft) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.themePrimaryDark)
                .disabled(apiKeyManager.isValidating)
                .accessibilityIdentifier("validateAPIKeyButton")

                Button("Clear", role: .destructive) {
                    apiKeyManager.clearKey()
                    apiKeyDraft = ""
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("clearAPIKeyButton")
            }

            if apiKeyManager.isValidating {
                ProgressView("Validating...")
                    .font(.caption)
            }

            validationStatusView
        } header: {
            Text("Deepgram API Key")
        } footer: {
            Text("Used for source and recording transcription")
        }
    }

    @ViewBuilder
    private var validationStatusView: some View {
        switch apiKeyManager.validationState {
        case .valid(let message):
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                    if let lastChecked = apiKeyManager.lastValidatedAt {
                        Text("Last checked: \(lastChecked.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                    }
                    Text("Transcription actions are enabled")
                        .font(.caption)
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundStyle(Color.themeSuccess)

        case .invalid(let message):
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                    if let lastChecked = apiKeyManager.lastValidatedAt {
                        Text("Last checked: \(lastChecked.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                    }
                }
            } icon: {
                Image(systemName: "xmark.circle.fill")
            }
            .foregroundStyle(Color.themeError)

        case .unknown:
            EmptyView()
        }
    }

    // MARK: - Workspace Section

    private var workspaceSection: some View {
        Section {
            ForEach(WorkspaceLanguage.allCases) { language in
                Toggle(
                    language.displayName,
                    isOn: workspaceActiveBinding(for: language)
                )
                .tint(Color.themePrimary)
                .accessibilityIdentifier("workspaceToggle_\(language.rawValue)")
                .disabled(
                    viewModel.isWorkspaceActive(language)
                        && !viewModel.canDeactivateWorkspace(language)
                )
            }

            Picker("Default Workspace", selection: defaultWorkspaceBinding) {
                ForEach(viewModel.activeWorkspaces) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .accessibilityIdentifier("defaultWorkspacePicker")
        } header: {
            Text("Language Workspaces")
        } footer: {
            Text("Data is isolated per language (sessions, progress, attempts). At least one workspace must stay active.")
        }
    }

    // MARK: - Show Original Section

    private var showOriginalSection: some View {
        Section {
            Toggle("Show original transcript by default", isOn: showOriginalBinding)
                .tint(Color.themePrimary)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0 demo")
            LabeledContent("Privacy", value: "API key in Keychain")
        }
    }

    // MARK: - Bindings

    private var showOriginalBinding: Binding<Bool> {
        Binding {
            viewModel.workspaceState.showOriginalByDefault
        } set: { newValue in
            viewModel.setShowOriginalByDefault(newValue)
        }
    }

    private var defaultWorkspaceBinding: Binding<WorkspaceLanguage> {
        Binding {
            viewModel.selectedWorkspace
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
}
