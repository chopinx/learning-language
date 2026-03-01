import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var navigationPath: [UUID] = []
    @State private var showImportSheet = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    workspaceChipsSection
                    if !viewModel.sessions.isEmpty { todaySummaryCard }
                    resumeButton
                    sessionsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("LearningLanguage")
            .safeAreaInset(edge: .bottom) {
                Button {
                    showImportSheet = true
                } label: {
                    Label("New Session", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Capsule().fill(AppTheme.primaryButton))
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
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

    // MARK: - Workspace Chips

    private var workspaceChipsSection: some View {
        Group {
            if viewModel.shouldShowWorkspaceSwitcher {
                WorkspacePillChips(
                    workspaces: viewModel.activeWorkspaces,
                    selected: workspaceBinding
                )
                .accessibilityIdentifier("workspacePicker")
            } else {
                Text("Workspace: \(viewModel.selectedWorkspace.displayName)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityIdentifier("workspaceSingleLabel")
            }
        }
    }

    // MARK: - Today Summary Card

    private var todaySummaryCard: some View {
        let sessionCount = viewModel.sessions.count
        let totalSentences = viewModel.sessions.reduce(0) { $0 + $1.sentences.count }
        let plannedMinutes = max(1, totalSentences / 2)
        let totalCompleted = viewModel.sessions.reduce(0) { $0 + $1.completedSentenceIDs.count }
        let accuracy = totalSentences > 0
            ? Int(Double(totalCompleted) / Double(totalSentences) * 100)
            : 0

        return VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            Text("\(sessionCount) sessions active across \(plannedMinutes) min planned")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                Text("+\(accuracy)% streak")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.chipGreenText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.chipGreenBg, in: Capsule())

                Text("Sentence accuracy \(accuracy)%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.chipBlueBg, in: Capsule())
            }
        }
        .appCard()
    }

    // MARK: - Resume Button

    @ViewBuilder
    private var resumeButton: some View {
        if let lastOpenedSession = viewModel.lastOpenedSession {
            Button {
                openSession(lastOpenedSession.id)
            } label: {
                Label("Resume: \(lastOpenedSession.title)", systemImage: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.chipBlueBg, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumeLastSessionButton")
        }
    }

    // MARK: - Sessions

    @ViewBuilder
    private var sessionsSection: some View {
        if viewModel.sessions.isEmpty {
            ContentUnavailableView(
                "No sessions yet",
                systemImage: "waveform.badge.plus",
                description: Text("Create a session by importing audio or generating audio from text.")
            )
        } else {
            Text("Sessions in \(viewModel.selectedWorkspace.displayName)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textHeading)

            LazyVStack(spacing: 10) {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(value: session.id) {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            viewModel.setLastOpenedSession(session.id)
                        }
                    )
                }
            }
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

private struct SessionRowView: View {
    let session: LearningSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Last active \(RelativeTimeFormatter.string(from: session.updatedAt))")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            StyledProgressBar(
                progress: session.progress,
                completed: session.completedSentenceIDs.count,
                total: session.sentences.count
            )

            HStack(spacing: 8) {
                progressChip

                Text(session.progress > 0 ? "Resume" : "Continue")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppColors.chipBlueBg, in: Capsule())
            }
        }
        .appCard()
    }

    @ViewBuilder
    private var progressChip: some View {
        let pct = Int(session.progress * 100)
        if pct >= 10 {
            Text("\(pct)% done")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.chipGreenText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.chipGreenBg, in: Capsule())
        } else {
            Text("Just started")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.chipPurpleText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.chipPurpleBg, in: Capsule())
        }
    }
}
