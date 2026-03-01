import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var navigationPath: [UUID] = []
    @State private var showImportSheet = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    workspaceSection
                    resumeSection
                    sessionsSection
                }
            }
            .listStyle(.plain)
            .navigationTitle("LearningLanguage")
            .safeAreaInset(edge: .bottom) {
                newSessionButton
            }
            .navigationDestination(for: UUID.self) { sessionID in
                PracticeView(viewModel: viewModel, sessionID: sessionID)
                    .onAppear { viewModel.setLastOpenedSession(sessionID) }
            }
        }
        .fullScreenCover(isPresented: $showImportSheet) {
            ImportTranscribeView(viewModel: viewModel) { newSessionID in
                showImportSheet = false
                openSession(newSessionID)
            }
        }
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
        } else {
            Text("Workspace: \(viewModel.selectedWorkspace.displayName)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.themeTextSecondary)
                .accessibilityIdentifier("workspaceSingleLabel")
                .listRowSeparator(.hidden)
        }
    }

    // MARK: - Resume

    @ViewBuilder
    private var resumeSection: some View {
        if let lastSession = viewModel.lastOpenedSession {
            Button {
                openSession(lastSession.id)
            } label: {
                Label("Resume: \(lastSession.title)", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.themePrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumeLastSessionButton")
            .listRowSeparator(.hidden)
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
            }
        } header: {
            Text("Sessions in \(viewModel.selectedWorkspace.displayName)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.themeTextPrimary)
        }
    }

    // MARK: - New Session Button

    private var newSessionButton: some View {
        Button {
            showImportSheet = true
        } label: {
            Label("New Session", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Color.themePrimaryGradient, in: Capsule())
        .padding(.horizontal)
        .padding(.vertical, 6)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.headline)
                .foregroundStyle(Color.themeTextPrimary)

            Text("Last active \(RelativeTimeFormatter.string(from: session.updatedAt))")
                .font(.caption)
                .foregroundStyle(Color.themeTextSecondary)

            StyledProgressBar(
                progress: session.progress,
                completed: session.completedSentenceIDs.count,
                total: session.sentences.count
            )

            HStack(spacing: 8) {
                progressChip
                actionChip
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var progressChip: some View {
        let pct = Int(session.progress * 100)
        if pct >= 10 {
            Text("\(pct)% done")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.themeSuccess)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.themeSuccess.opacity(0.15), in: Capsule())
        } else {
            Text("Just started")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.themeTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.themeTextTertiary.opacity(0.15), in: Capsule())
        }
    }

    private var actionChip: some View {
        Text(session.progress > 0 ? "Resume" : "Continue")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.themePrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.themePrimary.opacity(0.1), in: Capsule())
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
