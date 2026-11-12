import SwiftData
import SwiftUI

@main
struct NoiseDiaryApp: App {
    @StateObject private var lock = AppLock()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(lock)
        }
        .modelContainer(for: NoiseEntry.self)
    }
}
