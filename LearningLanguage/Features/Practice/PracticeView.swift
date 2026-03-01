import SwiftUI

struct PracticeView: View {
    @ObservedObject var viewModel: AppViewModel
    let sessionID: UUID
    var body: some View {
        Text("Practice - TODO").navigationTitle("Practice")
    }
}
