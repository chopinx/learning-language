import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var navigationPath: [UUID] = []
    @State private var showImportSheet = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if viewModel.sessions.isEmpty && !viewModel.apiKeyManager.hasSavedKey {
                    apiKeySetupPrompt
                } else if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    workspaceSection
                    resumeSection
                    sessionsSection
                }
            }
            .listStyle(.plain)
            #if os(iOS)
            .listRowSpacing(4)
            #endif
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .navigationTitle("LearningLanguage")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .tint(Color.themeTextSecondary)
                }
                #elseif os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .tint(Color.themeTextSecondary)
                }
                #endif
            }
            .overlay(alignment: .bottomTrailing) {
                if viewModel.apiKeyManager.hasSavedKey || !viewModel.sessions.isEmpty {
                    Button { showImportSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.themePrimary, in: Circle())
                            .shadow(color: Color.themePrimary.opacity(0.4), radius: 8, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationDestination(for: UUID.self) { sessionID in
                PracticeView(viewModel: viewModel, sessionID: sessionID)
                    .onAppear { viewModel.setLastOpenedSession(sessionID) }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel, apiKeyManager: viewModel.apiKeyManager)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showImportSheet) {
            ImportTranscribeView(viewModel: viewModel) { newSessionID in
                showImportSheet = false
                openSession(newSessionID)
            }
        }
        #elseif os(macOS)
        .sheet(isPresented: $showImportSheet) {
            ImportTranscribeView(viewModel: viewModel) { newSessionID in
                showImportSheet = false
                openSession(newSessionID)
            }
        }
        #endif
    }

    // MARK: - API Key Setup Prompt

    @ViewBuilder
    private var apiKeySetupPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.themePrimary)

            Text("Set Up Your API Key")
                .font(.headline)
                .foregroundStyle(Color.themeTextPrimary)

            Text("A Deepgram API key is required to transcribe audio and generate practice sessions.")
                .font(.subheadline)
                .foregroundStyle(Color.themeTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                showSettings = true
            } label: {
                Label("Open Settings", systemImage: "gearshape.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.themePrimary)
            .accessibilityIdentifier("setupAPIKeyButton")
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        workspaceSection

        ContentUnavailableView(
            "No sessions yet",
            systemImage: "waveform.badge.plus",
            description: Text("Create a session by importing audio or generating from text.")
        )
        .listRowSeparator(.hidden)
    }

    // MARK: - Workspace

    @ViewBuilder
    private var workspaceSection: some View {
        if viewModel.shouldShowWorkspaceSwitcher {
            WorkspacePicker(
                workspaces: viewModel.activeWorkspaces,
                selected: workspaceBinding
            )
            .accessibilityIdentifier("workspacePicker")
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal)
        }
    }

    // MARK: - Resume

    @ViewBuilder
    private var resumeSection: some View {
        if let lastSession = viewModel.lastOpenedSession {
            Button {
                openSession(lastSession.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.themePrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Resume")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.themePrimary)
                            Spacer()
                        }

                        Text(lastSession.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.themeTextPrimary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            ProgressView(value: lastSession.progress)
                                .tint(Color.themePrimary)

                            Text("\(Int(lastSession.progress * 100))%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.themeTextTertiary)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.themeTextTertiary)
                }
                .padding()
                .background(Color.themePrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumeLastSessionButton")
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    // MARK: - Sessions List

    private var sessionsSection: some View {
        Section {
            ForEach(viewModel.sessions) { session in
                NavigationLink(value: session.id) {
                    SessionRow(session: session)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        viewModel.setLastOpenedSession(session.id)
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteSession(session.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("Sessions in \(viewModel.selectedWorkspace.displayName)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)
        }
    }

    // MARK: - Helpers

    private func openSession(_ sessionID: UUID) {
        viewModel.setLastOpenedSession(sessionID)
        navigationPath = [sessionID]
    }

    private var workspaceBinding: Binding<WorkspaceLanguage> {
        Binding {
            viewModel.selectedWorkspace
        } set: { newValue in
            viewModel.switchWorkspace(to: newValue)
            navigationPath.removeAll()
        }
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: LearningSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.title)
                .font(.headline)
                .foregroundStyle(Color.themeTextPrimary)

            HStack(spacing: 8) {
                ProgressView(value: session.progress)
                    .tint(Color.themePrimary)

                Text("\(Int(session.progress * 100))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.themeTextTertiary)
            }

            Text("Last active \(RelativeTimeFormatter.string(from: session.updatedAt))")
                .font(.caption)
                .foregroundStyle(Color.themeTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Workspace Picker

private struct WorkspacePicker: View {
    let workspaces: [WorkspaceLanguage]
    @Binding var selected: WorkspaceLanguage

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(workspaces) { language in
                    Button {
                        selected = language
                    } label: {
                        Text(language.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(language == selected ? .white : Color.themeTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    language == selected
                                        ? AnyShapeStyle(Color.themePrimary)
                                        : AnyShapeStyle(Color.themeBorder)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
