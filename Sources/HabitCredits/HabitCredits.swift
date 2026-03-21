import SwiftUI
import Foundation

@MainActor
final class AppNavigationStore: ObservableObject {
    @Published var mainSection: MainSection = .today
    @Published var habitEditorTarget: HabitEditorTarget? = nil
}

@MainActor
final class MenuBarDismissStore: ObservableObject {
    @Published var dismissRequested: Bool = false

    func requestDismiss() {
        dismissRequested = true
    }

    func didDismiss() {
        dismissRequested = false
    }
}

enum HabitEditorTarget: Equatable {
    case create
    case edit(UUID)
}

@main
struct HabitCreditsApp: App {
    @StateObject private var appStore = AppStore()
    @StateObject private var navigationStore = AppNavigationStore()
    @StateObject private var menuBarDismissStore = MenuBarDismissStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(appStore)
                .environmentObject(navigationStore)
                .environmentObject(menuBarDismissStore)
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.window)

        // 使用按需创建的 `Window`：避免应用启动时默认弹出主窗口。
        Window("事项积分", id: "mainWindow") {
            MainWindowView()
                .environmentObject(appStore)
                .environmentObject(navigationStore)
                .environmentObject(menuBarDismissStore)
        }
        // 与 WindowSizeApplier 保持一致，减少系统恢复窗口尺寸的干扰
        .defaultSize(width: 780, height: 440)
    }
}
