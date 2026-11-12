import SwiftUI

/// Root: the tabs, covered by the lock screen when the optional lock is on.
struct ContentView: View {
    @EnvironmentObject private var lock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    @State private var returningFromBackground = false

    var body: some View {
        MainTabView()
            .lockCover()
            .task {
                await lock.unlock()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    lock.lockIfEnabled()
                    returningFromBackground = true
                case .active:
                    // Only prompt automatically after a real trip to the background;
                    // the Face ID sheet itself makes the app briefly inactive.
                    if returningFromBackground {
                        returningFromBackground = false
                        Task { await lock.unlock() }
                    }
                default:
                    break
                }
            }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DiaryListView()
                .tabItem { Label("Diary", systemImage: "list.bullet.rectangle") }
            CalendarScreen()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            TotalsView()
                .tabItem { Label("Totals", systemImage: "chart.bar") }
            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

/// Covers a screen with the lock view while the app is locked. Applied to the
/// root and to every sheet, because sheets are drawn above the root view.
struct LockCover: ViewModifier {
    @EnvironmentObject private var lock: AppLock
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        ZStack {
            content
            // Also hides the diary in the app-switcher snapshot when the lock is on.
            if lock.isLocked || (lock.isEnabled && scenePhase != .active) {
                LockView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: lock.isLocked)
    }
}

extension View {
    func lockCover() -> some View {
        modifier(LockCover())
    }
}

struct LockView: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Noise Diary is locked")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                if let message = lock.errorMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with \(AppLock.methodName)", systemImage: "faceid")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(32)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppLock())
        .modelContainer(for: NoiseEntry.self, inMemory: true)
}
