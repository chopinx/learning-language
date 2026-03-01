import SwiftUI

struct ImportTranscribeView: View {
    @ObservedObject var viewModel: AppViewModel
    let onSessionCreated: (UUID) -> Void
    var body: some View {
        NavigationStack { Text("Import - TODO").navigationTitle("New Session") }
    }
}
