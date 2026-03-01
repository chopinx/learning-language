import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var navigationPath: [UUID] = []
    @State private var showImportSheet = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LearningLanguage")
                                .font(.largeTitle.weight(.bold))
                            Text("Workspace overview")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 6)

                        Text("Shadowing workspace dashboard")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.18, green: 0.34, blue: 0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.9, green: 0.96, blue: 0.98), in: Capsule())

                        if viewModel.shouldShowWorkspaceSwitcher {
                            Picker("Workspace", selection: workspaceBinding) {
                                ForEach(viewModel.activeWorkspaces) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("workspacePicker")
                            .appCard()
                        } else {
                            Text("Workspace: \(viewModel.selectedWorkspace.displayName)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("workspaceSingleLabel")
                                .appCard()
                        }

                        if let lastOpenedSession = viewModel.lastOpenedSession {
                            Button {
                                openSession(lastOpenedSession.id)
                            } label: {
                                Label(
                                    "Resume: \(lastOpenedSession.title)",
                                    systemImage: "play.fill"
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 2)
                            .appCard()
                            .accessibilityIdentifier("resumeLastSessionButton")
                        }

                        if viewModel.sessions.isEmpty {
                            ContentUnavailableView(
                                "No sessions yet",
                                systemImage: "waveform.badge.plus",
                                description: Text("Create a session by importing audio or generating audio from text.")
                            )
                            .padding(.top, 20)
                        } else {
                            Text("Sessions in \(viewModel.selectedWorkspace.displayName)")
                                .font(.headline)
                                .padding(.top, 2)

                            LazyVStack(spacing: 12) {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    showImportSheet = true
                } label: {
                    Label("New Session", systemImage: "plus.circle.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.primaryButton)
                )
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .navigationDestination(for: UUID.self) { sessionID in
                PracticeView(viewModel: viewModel, sessionID: sessionID)
                    .onAppear {
                        viewModel.setLastOpenedSession(sessionID)
                    }
            }
        }
        .fullScreenCover(isPresented: $showImportSheet) {
            ImportTranscribeView(viewModel: viewModel) { newSessionID in
                showImportSheet = false
                openSession(newSessionID)
            }
        }
    }

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

private struct SessionRowView: View {
    let session: LearningSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("\(session.completedSentenceIDs.count) / \(session.sentences.count) sentences")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: session.progress)
                .tint(.teal)

            Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}
