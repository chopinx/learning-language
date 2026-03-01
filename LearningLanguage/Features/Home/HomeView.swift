import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel
    var body: some View {
        NavigationStack { Text("Home - TODO").navigationTitle("Home") }
    }
}
