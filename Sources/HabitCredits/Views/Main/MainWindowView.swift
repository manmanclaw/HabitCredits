import SwiftUI
import AppKit

enum MainSection: Hashable {
    case today
    case stats
    case manage
    case settings
}

struct MainWindowView: View {
    @EnvironmentObject private var navigationStore: AppNavigationStore
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var menuBarDismissStore: MenuBarDismissStore

    var body: some View {
        // 用一个全局背景铺满（忽略 safe area），确保标题栏/状态栏区域与内容区颜色一致。
        ZStack(alignment: .topLeading) {
            AppColors.bg
                .ignoresSafeArea()
            HStack(spacing: 0) {
                SidebarView(selection: selectionBinding)
                    .frame(minWidth: 175, idealWidth: 175, maxWidth: 175)
                    .background(AppColors.bg)

                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 1)

                ZStack(alignment: .topLeading) {
                    switch navigationStore.mainSection {
                    case .today:
                        TodayView()
                    case .stats:
                        StatsView()
                    case .manage:
                        HabitManageView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.bg)
            }
        }
        .background(TextEditingDismissBridge())
        .alert(
            "提示",
            isPresented: Binding(
                get: { appStore.persistenceErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { appStore.persistenceErrorMessage = nil }
                }
            )
        ) {
            Button("好") {
                appStore.persistenceErrorMessage = nil
            }
        } message: {
            Text(appStore.persistenceErrorMessage ?? "")
        }
        // 强制主窗口在每次启动时使用目标尺寸，避免系统窗口尺寸恢复/内容自适应导致的“看起来没变”
        .background(WindowFrameAutosaveApplier())
    }

    private var selectionBinding: Binding<MainSection?> {
        Binding<MainSection?>(
            get: { navigationStore.mainSection },
            set: { newValue in
                if let newValue {
                    navigationStore.mainSection = newValue
                }
            }
        )
    }
}

/// 当主窗口发生文本编辑（开始输入）时，关闭菜单栏弹窗，避免抢焦点/打断输入。
private struct TextEditingDismissBridge: NSViewRepresentable {
    @EnvironmentObject private var menuBarDismissStore: MenuBarDismissStore

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.startObserving(store: menuBarDismissStore)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var observers: [NSObjectProtocol] = []
        private weak var store: MenuBarDismissStore?

        func startObserving(store: MenuBarDismissStore) {
            self.store = store
            guard observers.isEmpty else { return }

            let center = NotificationCenter.default
            let begin = center.addObserver(forName: NSText.didBeginEditingNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.requestDismissIfTextFirstResponder()
            }
            observers.append(begin)

            let end = center.addObserver(forName: NSText.didEndEditingNotification, object: nil, queue: .main) { _ in
                // 结束编辑不需要额外处理；只在开始编辑触发一次即可。
            }
            observers.append(end)
        }

        private func requestDismissIfTextFirstResponder() {
            guard let responder = NSApp.keyWindow?.firstResponder else { return }
            guard responder is NSTextField || responder is NSTextView else { return }
            guard let store else { return }
            // 在 MainActor 上调用 `@MainActor` 的 store；Task 内只捕获 `store`，避免发送 `Coordinator`。
            Task { @MainActor in
                store.requestDismiss()
            }
        }

        deinit {
            for o in observers {
                NotificationCenter.default.removeObserver(o)
            }
        }
    }
}

private struct WindowFrameAutosaveApplier: NSViewRepresentable {
    private let autosaveName = "HabitCredits.mainWindow.frame"

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }

        if !context.coordinator.didApplyAutosave {
            // 让系统在用户拖拽/缩放后自动记住窗口尺寸，下次打开自动恢复。
            window.setFrameAutosaveName(autosaveName)
            context.coordinator.didApplyAutosave = true
        }

        // SwiftUI 可能会在窗口创建后多次触发更新；为了避免系统把标题栏样式“还原”，这里每次 update 都强制设置。
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        // 避免 `.fullSizeContentView` 在部分 macOS 版本上仍会在标题栏下方渲染出固定分割线。
        window.styleMask.remove(.fullSizeContentView)

        // 彻底隐藏导航栏：直接移除 toolbar（SwiftUI 可能会重建，因此每次 update 里都强制一次）。
        if let toolbar = window.toolbar {
            toolbar.showsBaselineSeparator = false
        }
        window.toolbar = nil

        window.backgroundColor = NSColor(AppColors.bg)
        window.isOpaque = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor(AppColors.bg).cgColor

        // 有些 macOS 版本上，titlebarSeparatorStyle=none 仍会渲染出 1px 左右的固定分割线。
        // 这里兜底：隐藏标题栏分隔视图（仅按“类名包含 separator 且高度很小”匹配）。
        hideTitlebarSeparatorIfNeeded(window)

        context.coordinator.didApplyTitlebar = true
    }

    private func hideTitlebarSeparatorIfNeeded(_ window: NSWindow) {
        guard let root = window.contentView else { return }
        let bg = NSColor(AppColors.bg)

        func walk(_ view: NSView) {
            let typeName = String(describing: type(of: view))
            let height = view.bounds.height

            let looksLikeSeparator =
                typeName.localizedCaseInsensitiveContains("separator")
                && height <= 2.5

            if looksLikeSeparator {
                view.isHidden = true
                view.layer?.backgroundColor = bg.cgColor
            }

            for sub in view.subviews {
                walk(sub)
            }
        }

        walk(root)
    }

    private func applySplitViewStyle(in root: NSView) {
        let bg = NSColor(AppColors.bg)
        for split in findSplitViews(in: root) {
            split.wantsLayer = true
            split.layer?.backgroundColor = bg.cgColor
            split.dividerStyle = .thin
            // 在部分 SDK 中 dividerColor 是只读；尝试用 selector 设置（存在则可抹平分割线颜色）。
            let sel = Selector(("setDividerColor:"))
            if split.responds(to: sel) {
                _ = split.perform(sel, with: bg)
            }

            for sub in split.subviews {
                sub.wantsLayer = true
                sub.layer?.backgroundColor = bg.cgColor
            }
        }
    }

    private func findSplitViews(in root: NSView) -> [NSSplitView] {
        var result: [NSSplitView] = []
        func walk(_ view: NSView) {
            if let split = view as? NSSplitView {
                result.append(split)
            }
            for sub in view.subviews {
                walk(sub)
            }
        }
        walk(root)
        return result
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var didApplyAutosave = false
        var didApplyTitlebar = false
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var importMode: AppStore.ImportMode = .merge
    @State private var isImportModeDialogPresented = false
    @State private var pendingImportUrl: URL? = nil
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isAlertPresented = false

    var body: some View {
        PageLayout {
            PageHeader(title: "系统设置", subtitle: "一期：基础设置入口与说明")

            Form {
                Section("基础设置") {
                    LabeledContent("语言") {
                        Text("简体中文")
                            .foregroundStyle(AppColors.slate700)
                    }
                    LabeledContent("启动") {
                        Text("二期支持开机自启")
                            .foregroundStyle(AppColors.slate500)
                    }
                }

                Section("数据管理") {
                    LabeledContent("导出") {
                        HStack(spacing: 10) {
                            Button("导出 JSON") { exportJson() }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColors.brandGreen)
                                .controlSize(.small)

                            Button("导出 CSV") { exportCsv() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }

                    LabeledContent("导入") {
                        HStack(spacing: 10) {
                            Button("导入 JSON") { pickImportJson() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                            Text("支持合并/覆盖")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.slate500)
                        }
                    }
                    LabeledContent("备份/加密") {
                        Text("二期实现")
                            .foregroundStyle(AppColors.slate500)
                    }
                }

                Section("关于") {
                    LabeledContent("版本") {
                        Text("1.0")
                            .foregroundStyle(AppColors.slate700)
                    }
                    LabeledContent("隐私") {
                        Text("本地存储，无网络请求")
                            .foregroundStyle(AppColors.slate700)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 720)
        }
        .confirmationDialog("导入方式", isPresented: $isImportModeDialogPresented, titleVisibility: .visible) {
            Button("合并导入（保留现有数据）") {
                importMode = .merge
                performPendingImport()
            }
            Button("覆盖导入（替换现有数据）", role: .destructive) {
                importMode = .overwrite
                performPendingImport()
            }
            Button("取消", role: .cancel) {
                pendingImportUrl = nil
            }
        } message: {
            Text("请选择导入方式。覆盖会清空当前数据。")
        }
        .alert(alertTitle, isPresented: $isAlertPresented) {
            Button("好") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func exportJson() {
        do {
            let data = try appStore.exportSnapshotJsonData()
            let url = try promptSaveUrl(suggestedFileName: "habitcredits-export.json", allowedFileTypes: ["json"])
            guard let url else { return }
            try data.write(to: url, options: [.atomic])
            presentAlert(title: "导出成功", message: "已导出 JSON 到：\(url.lastPathComponent)")
        } catch {
            presentAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func exportCsv() {
        do {
            let csv = appStore.exportRecordsCsvString()
            let url = try promptSaveUrl(suggestedFileName: "habitcredits-records.csv", allowedFileTypes: ["csv"])
            guard let url else { return }
            try csv.data(using: .utf8)?.write(to: url, options: [.atomic])
            presentAlert(title: "导出成功", message: "已导出 CSV 到：\(url.lastPathComponent)")
        } catch {
            presentAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func pickImportJson() {
        do {
            let url = try promptOpenUrl(allowedFileTypes: ["json"])
            guard let url else { return }
            pendingImportUrl = url
            isImportModeDialogPresented = true
        } catch {
            presentAlert(title: "打开失败", message: error.localizedDescription)
        }
    }

    private func performPendingImport() {
        guard let url = pendingImportUrl else { return }
        do {
            let data = try Data(contentsOf: url)
            try appStore.importSnapshotJsonData(data, mode: importMode)
            presentAlert(title: "导入成功", message: "已从 \(url.lastPathComponent) 导入（\(importMode == .merge ? "合并" : "覆盖")）。")
        } catch {
            presentAlert(title: "导入失败", message: error.localizedDescription)
        }
        pendingImportUrl = nil
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isAlertPresented = true
    }

    private func promptSaveUrl(suggestedFileName: String, allowedFileTypes: [String]) throws -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = suggestedFileName
        panel.allowedFileTypes = allowedFileTypes
        let resp = panel.runModal()
        return resp == .OK ? panel.url : nil
    }

    private func promptOpenUrl(allowedFileTypes: [String]) throws -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = allowedFileTypes
        let resp = panel.runModal()
        return resp == .OK ? panel.url : nil
    }
}

