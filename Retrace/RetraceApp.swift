import SwiftUI
import SwiftData

@main
struct RetraceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            JourneyListView()
        }
        .modelContainer(AppContainer.shared)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        LocationRecordingService.shared.resumeIfNeeded()
        return true
    }
}
