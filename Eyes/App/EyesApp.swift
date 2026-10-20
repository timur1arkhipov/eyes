import SwiftUI

@main
struct EyesApp: App {
    @StateObject private var store = ProjectStore()

    var body: some Scene {
        WindowGroup {
            ProjectListView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
