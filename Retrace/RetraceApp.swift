import SwiftUI
import SwiftData

@main
struct RetraceApp: App {
    var body: some Scene {
        WindowGroup {
            JourneyListView()
        }
        .modelContainer(for: Journey.self)
    }
}
