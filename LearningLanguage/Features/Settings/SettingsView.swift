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
                        apiKeySection
                        workspaceSection
                        aboutSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                apiKeyDraft = apiKeyManager.savedKey ?? ""
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deepgram API Key")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            Text("Used for source and recording transcription")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)

            apiKeyInputField

            HStack(spacing: 8) {
                PillButton("Save", style: .primary) {
                    let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    apiKeyManager.saveKey(trimmedKey)
                    if !trimmedKey.isEmpty {
                        apiKeyDraft = trimmedKey
                    }
                }
                .accessibilityIdentifier("saveAPIKeyButton")

                PillButton("Validate", style: .primary) {
                    Task { @MainActor in
                        await apiKeyManager.validateKey(apiKeyDraft)
                    }
                }
                .disabled(apiKeyManager.isValidating)
                .accessibilityIdentifier("validateAPIKeyButton")

                PillButton("Clear", style: .secondary) {
                    apiKeyManager.clearKey()
                    apiKeyDraft = ""
                }
                .accessibilityIdentifier("clearAPIKeyButton")
            }

            if apiKeyManager.isValidating {
                ProgressView("Validating key...")
                    .font(.caption)
            }

            validationStatusCard
        }
        .appCard()
    }

    private var apiKeyInputField: some View {
        VStack(alignment: .leading, spacing: 0) {
            if apiKeyDraft.isEmpty {
                SecureField("Enter API key", text: $apiKeyDraft)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("deepgramAPIKeyField")
            } else {
                TextField("API Key", text: $apiKeyDraft)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("deepgramAPIKeyField")
                    .onAppear {
                        apiKeyDraft = maskedKey(apiKeyDraft)
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.inputBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.inputBorder, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var validationStatusCard: some View {
        switch apiKeyManager.validationState {
        case .valid:
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.validSuccessIcon)
                        .frame(width: 20, height: 20)

                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Key validated successfully")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.validSuccessText)

                    if let lastChecked = apiKeyManager.lastValidatedAt {
                        Text("Last checked: \(lastChecked.formatted(date: .omitted, time: .shortened))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(red: 0.235, green: 0.478, blue: 0.349))
                    }

                    Text("Transcription actions are enabled")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: 0.235, green: 0.478, blue: 0.349))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.validSuccessBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(red: 0.812, green: 0.902, blue: 0.839), lineWidth: 1)
                    )
            )

        case .invalid(let message):
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.diffMissingText)
                        .frame(width: 20, height: 20)

                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.diffMissingText)

                    if let lastChecked = apiKeyManager.lastValidatedAt {
                        Text("Last checked: \(lastChecked.formatted(date: .omitted, time: .shortened))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.diffMissingText.opacity(0.8))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.diffMissingBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.diffMissingText.opacity(0.3), lineWidth: 1)
                    )
            )

        case .unknown:
            Text("No validation yet")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Workspace Section

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language Workspace")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            Text("Data is isolated per language (sessions, progress, attempts)")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)

            workspaceChipsWithAdd

            showOriginalToggleRow

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
                .tint(AppColors.deepTeal)
            }

            Text("At least one language workspace must stay active.")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .appCard()
    }

    private var workspaceChipsWithAdd: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.activeWorkspaces) { language in
                    Button {
                        viewModel.switchWorkspace(to: language)
                    } label: {
                        Text(language.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(language == viewModel.selectedWorkspace ? .white : AppColors.chipInactiveText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(language == viewModel.selectedWorkspace ? AppColors.chipActive : AppColors.chipInactiveBg)
                            )
                    }
                    .buttonStyle(.plain)
                }

                addWorkspaceButton
            }
        }
        .accessibilityIdentifier("defaultWorkspacePicker")
    }

    @ViewBuilder
    private var addWorkspaceButton: some View {
        let inactiveLanguages = WorkspaceLanguage.allCases.filter { !viewModel.activeWorkspaces.contains($0) }

        if !inactiveLanguages.isEmpty {
            Menu {
                ForEach(inactiveLanguages) { language in
                    Button(language.displayName) {
                        viewModel.setWorkspaceActive(language, isActive: true)
                    }
                }
            } label: {
                Text("+")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.chipInactiveBg, in: Capsule())
            }
        }
    }

    private var showOriginalToggleRow: some View {
        HStack {
            Text("Show original transcript by default")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            Spacer()

            Toggle("", isOn: showOriginalBinding)
                .labelsHidden()
                .tint(AppColors.deepTeal)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.inputBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.inputBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            Text("Version 1.0 demo")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.chipInactiveText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.inputBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.inputBorder, lineWidth: 1)
                        )
                )

            HStack {
                Spacer()
                Text("Privacy: API key in Keychain")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textHeading)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(AppColors.chipInactiveBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .appCard()
    }

    // MARK: - Bindings

    private var showOriginalBinding: Binding<Bool> {
        Binding {
            viewModel.workspaceState.showOriginalByDefault
        } set: { newValue in
            viewModel.setShowOriginalByDefault(newValue)
        }
    }

    private func workspaceActiveBinding(for language: WorkspaceLanguage) -> Binding<Bool> {
        Binding {
            viewModel.isWorkspaceActive(language)
        } set: { isActive in
            viewModel.setWorkspaceActive(language, isActive: isActive)
        }
    }

    private func maskedKey(_ key: String) -> String {
        guard key.count > 12 else { return key }
        let prefix = String(key.prefix(8))
        let suffix = String(key.suffix(4))
        let dotsCount = max(key.count - 12, 4)
        let dots = String(repeating: "\u{2022}", count: dotsCount)
        return prefix + dots + suffix
    }
}
