import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var apiKeyManager: APIKeyManager
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyDraft: String = ""
    @State private var isEditing: Bool = false

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themePrimary)
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
            .onAppear {
                apiKeyDraft = apiKeyManager.savedKey ?? ""
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        Section {
            if isEditing || !apiKeyManager.hasSavedKey {
                SecureField("Enter Deepgram API key", text: $apiKeyDraft)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("deepgramAPIKeyField")
            } else if let masked = apiKeyManager.maskedKey {
                Button {
                    isEditing = true
                } label: {
                    HStack {
                        Text(masked)
                            .font(.body.monospaced())
                            .foregroundStyle(Color.themeTextPrimary)
                        Spacer()
                        Text("Edit")
                            .font(.subheadline)
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .accessibilityIdentifier("deepgramAPIKeyField")
            }

            HStack(spacing: 12) {
                Button("Save") {
                    apiKeyManager.saveKey(apiKeyDraft)
                    isEditing = false
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
                    isEditing = false
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("clearAPIKeyButton")
            }

            if apiKeyManager.isValidating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Validating...")
                        .font(.subheadline)
                        .foregroundStyle(Color.themeTextSecondary)
                }
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
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                    if let lastChecked = apiKeyManager.lastValidatedAt {
                        Text("Last validated \(RelativeTimeFormatter.string(from: lastChecked).lowercased())")
                            .font(.caption)
                    }
                    Text("Transcription actions are enabled")
                        .font(.caption)
                }
                Spacer()
            }
            .foregroundStyle(Color.themeSuccess)
            .padding(10)
            .background(Color.themeSuccess.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

        case .invalid(let message):
            HStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                    if let lastChecked = apiKeyManager.lastValidatedAt {
                        Text("Last checked \(RelativeTimeFormatter.string(from: lastChecked).lowercased())")
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .foregroundStyle(Color.themeError)
            .padding(10)
            .background(Color.themeError.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

        case .unknown:
            EmptyView()
        }
    }

    // MARK: - Workspace Section

    private var workspaceSection: some View {
        Section {
            ForEach(WorkspaceLanguage.allCases) { language in
                HStack {
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

                    if viewModel.isWorkspaceActive(language) {
                        let count = viewModel.sessionCount(for: language)
                        Text("\(count) \(count == 1 ? "session" : "sessions")")
                            .font(.caption)
                            .foregroundStyle(Color.themeTextTertiary)
                    }
                }
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
            Text("Data is fully isolated per language — sessions, progress, and attempts are separate. At least one workspace must stay active.")
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
