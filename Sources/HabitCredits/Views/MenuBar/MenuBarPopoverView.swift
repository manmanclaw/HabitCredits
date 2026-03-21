import SwiftUI
import AppKit

struct MenuBarPopoverView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var navigationStore: AppNavigationStore
    @EnvironmentObject private var menuBarDismissStore: MenuBarDismissStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // 菜单栏里不弹出添加弹窗：添加/编辑由主窗口的“习惯管理页”完成

    struct Metrics {
        let scale: CGFloat
        let width: CGFloat
        let outerPadding: CGFloat
        let verticalSpacing: CGFloat
        let cardPadding: CGFloat
        let quickTitleFont: CGFloat
        let scoreSmallTitleFont: CGFloat
        let scoreValueFont: CGFloat
        let totalValueFont: CGFloat
        let rowTitleFont: CGFloat
        let rowPlusMinusFont: CGFloat
        let rowValueNumberFont: CGFloat
        let rowPadding: CGFloat
        let rowHeightRecorded: CGFloat
        let rowHeightDefault: CGFloat
        let bottomButtonHeight: CGFloat
        let bottomButtonIcon: CGFloat
    }

    private var metrics: Metrics {
        // 基于“常规菜单栏弹窗”做紧凑缩放：屏幕越宽越接近 0.9，Dynamic Type 越大则略放大，但仍做上限限制。
        let screenW = NSScreen.main?.visibleFrame.width ?? 1440
        let sScreen = max(0.85, min(1.0, screenW / 1440.0))

        let sType: CGFloat = {
            switch dynamicTypeSize {
            case .xSmall: 0.95
            case .small: 0.98
            case .medium: 1.0
            case .large: 1.05
            case .xLarge: 1.10
            default: 1.15
            }
        }()

        let scale = max(0.78, min(0.95, 0.90 * sScreen * sType))
        // 回退到“正常菜单栏弹窗”宽度区间（之前乘 2 是建立在样式未生效的前提下）
        let width = max(260, min(320, 320 * scale))

        return Metrics(
            scale: scale,
            width: width,
            // 更紧凑：减少 padding/间距/字体，保证能在同一高度显示更多选项。
            outerPadding: 12 * scale,
            verticalSpacing: 12 * scale,
            cardPadding: 10 * scale,
            quickTitleFont: 12 * scale,
            scoreSmallTitleFont: 11 * scale,
            scoreValueFont: 22 * scale,
            totalValueFont: 20 * scale,
            rowTitleFont: 12 * scale,
            rowPlusMinusFont: 10 * scale,
            rowValueNumberFont: 11 * scale,
            rowPadding: 8 * scale,
            rowHeightRecorded: 34 * scale,
            rowHeightDefault: 34 * scale,
            bottomButtonHeight: 28 * scale,
            bottomButtonIcon: 16 * scale
        )
    }

    var body: some View {
        ZStack {
            Color.white.opacity(0.0001)
            let rowSpacing = 6 * metrics.scale
            let minListHeight = metrics.rowHeightDefault * 5 + rowSpacing * 4
            let maxListHeight = metrics.rowHeightDefault * 8 + rowSpacing * 7
            // quickRecord 部分外的高度是固定-ish 的：用一个常量系数把整体高度钉住，
            // 这样“窗口高度”也满足 min/max，且列表超过时只滚动。
            let heightExtra = 150 * metrics.scale
            let minPopoverHeight = minListHeight + heightExtra
            let maxPopoverHeight = maxListHeight + heightExtra

            VStack(alignment: .leading, spacing: metrics.verticalSpacing) {
                scoreCard
                quickRecordSection
                bottomActions
            }
            .padding(metrics.outerPadding)
            .frame(width: metrics.width, alignment: .topLeading)
            .frame(minHeight: minPopoverHeight, maxHeight: maxPopoverHeight)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 243/255, green: 244/255, blue: 246/255), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.08), radius: 32, x: 0, y: 8)
        }
        .onChange(of: menuBarDismissStore.dismissRequested) { _, newValue in
            guard newValue else { return }
            menuBarDismissStore.didDismiss()
            dismiss()
        }
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 10 * metrics.scale) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(AppColors.brandGreen)
                    Text("今日积分")
                        .font(.system(size: metrics.scoreSmallTitleFont, weight: .medium))
                        .foregroundStyle(AppColors.brandGreen)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(AppColors.amber600)
                    Text("总积分")
                        .font(.system(size: metrics.scoreSmallTitleFont, weight: .medium))
                        .foregroundStyle(AppColors.amber600)
                }
            }

            HStack(alignment: .lastTextBaseline) {
                scoreValueView(
                    valueProvider: { appStore.todayScore() },
                    positiveColor: Color(red: 4/255, green: 120/255, blue: 87/255)
                )
                Spacer()
                totalValueView(valueProvider: { appStore.totalNetScore() })
            }
        }
        .padding(metrics.cardPadding)
        .background(
            LinearGradient(
                colors: [Color(red: 236/255, green: 253/255, blue: 245/255), Color(red: 240/255, green: 253/255, blue: 244/255)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func scoreValueView(valueProvider: () -> Int, positiveColor: Color) -> some View {
        let value = valueProvider()
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value >= 0 ? "+\(value)" : "\(value)")
                .font(.system(size: metrics.scoreValueFont, weight: .bold))
                .foregroundStyle(value >= 0 ? positiveColor : AppColors.red600)
            Text("分")
                .font(.system(size: 14 * metrics.scale, weight: .medium))
                .foregroundStyle(value >= 0 ? AppColors.brandGreen : AppColors.red600)
        }
    }

    @ViewBuilder
    private func totalValueView(valueProvider: () -> Int) -> some View {
        let value = valueProvider()
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value.formatted())
                .font(.system(size: metrics.totalValueFont, weight: .bold))
                .foregroundStyle(Color(red: 146/255, green: 64/255, blue: 14/255))
            Text("分")
                .font(.system(size: 14 * metrics.scale, weight: .medium))
                .foregroundStyle(Color(red: 180/255, green: 83/255, blue: 9/255))
        }
    }

    private var quickRecordSection: some View {
        VStack(alignment: .leading, spacing: 10 * metrics.scale) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundStyle(AppColors.slate700)
                    Text("快速记录")
                        .font(.system(size: metrics.quickTitleFont, weight: .semibold))
                        .foregroundStyle(AppColors.slate900)
                }

                Spacer()

                Button {
                    navigationStore.mainSection = .manage
                    navigationStore.habitEditorTarget = .create
                    showOrFocusMainWindow()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14 * metrics.scale, weight: .semibold))
                        .foregroundStyle(Color(red: 75/255, green: 85/255, blue: 99/255))
                        .frame(width: 28 * metrics.scale, height: 28 * metrics.scale)
                        .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if appStore.activeHabits.isEmpty {
                emptyHabitsView
            } else {
                // 让菜单栏弹窗在“快速记录”部分维持高度范围：
                // 最少显示 5 行、高度固定；超过 8 行后上下滚动。
                let rowSpacing = 6 * metrics.scale
                let minListHeight = metrics.rowHeightDefault * 5 + rowSpacing * 4
                let maxListHeight = metrics.rowHeightDefault * 8 + rowSpacing * 7
                ScrollView(.vertical) {
                    VStack(spacing: rowSpacing) {
                        ForEach(appStore.activeHabits) { habit in
                            MenuBarHabitRow(habit: habit, metrics: metrics)
                        }
                    }
                }
                .frame(minHeight: minListHeight, maxHeight: maxListHeight)
                .scrollIndicators(.hidden)
            }
        }
    }

    private var emptyHabitsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有习惯事项")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.slate900)
            Text("点击右上角 + 添加一个（分数可输入负数）")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.slate500)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 248/255, green: 250/255, blue: 252/255))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var bottomActions: some View {
        HStack(spacing: 8) {
            Button {
                navigationStore.mainSection = .today
                navigationStore.habitEditorTarget = nil
                showOrFocusMainWindow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 15 * metrics.scale, weight: .semibold))
                    Text("打开主窗口")
                        .font(.system(size: 13 * metrics.scale, weight: .medium))
                }
                .foregroundStyle(Color(red: 71/255, green: 85/255, blue: 105/255))
                .frame(maxWidth: .infinity)
                .frame(height: metrics.bottomButtonHeight)
                .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                navigationStore.mainSection = .stats
                navigationStore.habitEditorTarget = nil
                showOrFocusMainWindow()
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 16 * metrics.scale, weight: .semibold))
                    .frame(width: metrics.bottomButtonHeight, height: metrics.bottomButtonHeight)
                    .foregroundStyle(Color(red: 79/255, green: 70/255, blue: 229/255))
                    .background(Color(red: 238/255, green: 242/255, blue: 255/255))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("积分统计")

            Button {
                navigationStore.mainSection = .settings
                navigationStore.habitEditorTarget = nil
                showOrFocusMainWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16 * metrics.scale, weight: .semibold))
                    .frame(width: metrics.bottomButtonHeight, height: metrics.bottomButtonHeight)
                    .foregroundStyle(Color(red: 75/255, green: 85/255, blue: 99/255))
                    .background(Color(red: 249/255, green: 250/255, blue: 251/255))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("系统设置")
        }
    }
}

extension MenuBarPopoverView {
    private func showOrFocusMainWindow() {
        // 打开/聚焦主窗口时，同时关闭菜单栏弹窗，避免输入焦点被弹窗抢走。
        dismiss()

        // Window 的 title 为“事项积分”，用它判断是否已存在，避免重复 openWindow 导致多开。
        let mainWindowTitle = "事项积分"
        let existing = NSApplication.shared.windows.first(where: { $0.title == mainWindowTitle })
        if let existing {
            // 有可能窗口刚创建出来时不处在前台，需要强制一套顺序：定位 -> 置为 key -> orderFront。
            positionMainWindowBelowPopover(existing)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        openWindow(id: "mainWindow")

        // openWindow 后窗口创建/排序是异步的。用短轮询确保“最终一定置顶”，避免被遮挡。
        let deadline = DispatchTime.now() + 1.0
        func tryFocus() {
            if let window = NSApplication.shared.windows.first(where: { $0.title == mainWindowTitle }) {
                positionMainWindowBelowPopover(window)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApplication.shared.activate(ignoringOtherApps: true)
                window.makeKey()
                return
            }
            guard DispatchTime.now() < deadline else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                tryFocus()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            tryFocus()
        }
    }

    private func positionMainWindowBelowPopover(_ window: NSWindow) {
        guard let screenFrame = NSScreen.main?.visibleFrame ?? window.screen?.visibleFrame else { return }
        let currentSize = window.frame.size
        // 给顶部留一点空间，避免窗口顶部被菜单栏弹窗覆盖。
        let paddingTop: CGFloat = 90
        let targetY = max(screenFrame.minY, screenFrame.maxY - currentSize.height - paddingTop)
        let targetX = screenFrame.minX + (screenFrame.width - currentSize.width) / 2
        window.setFrame(NSRect(x: targetX, y: targetY, width: currentSize.width, height: currentSize.height), display: true)
    }
}

private struct MenuBarHabitRow: View {
    @EnvironmentObject private var appStore: AppStore
    let habit: Habit
    let metrics: MenuBarPopoverView.Metrics

    @State private var isRecordedToday = false
    @State private var isTimePickerPresented = false
    @State private var selectedTime = Date()

    var body: some View {
        Button {
            if isRecordedToday {
                appStore.toggleTodayRecord(for: habit)
                refreshRecordedState()
                return
            }

            if habit.timeTiersRule != nil {
                selectedTime = Date()
                isTimePickerPresented = true
                return
            }

            appStore.toggleTodayRecord(for: habit)
            refreshRecordedState()
        } label: {
            HStack(spacing: 12) {
                statusPill
                Image(systemName: habit.iconName ?? (habit.score >= 0 ? "checkmark.seal.fill" : "xmark.seal.fill"))
                    .font(.system(size: metrics.rowValueNumberFont, weight: .semibold))
                    .foregroundStyle(AppColors.color(hex: habit.iconColorHex ?? "") ?? titleColor)
                Text(habit.name)
                    .font(.system(size: metrics.rowTitleFont, weight: .medium))
                    .foregroundStyle(titleColor)
                Spacer()
                if habit.timeTiersRule != nil && !isRecordedToday {
                    Image(systemName: "clock")
                        .font(.system(size: metrics.rowPlusMinusFont, weight: .semibold))
                        .foregroundStyle(AppColors.slate500)
                }
                if let displayScore = displayScore {
                    HStack(spacing: 4) {
                        Image(systemName: displayScore >= 0 ? "plus" : "minus")
                            .font(.system(size: metrics.rowPlusMinusFont, weight: .semibold))
                            .foregroundStyle(displayScore >= 0 ? AppColors.brandGreen : AppColors.red600)
                        Text("\(abs(displayScore))")
                            .font(.system(size: metrics.rowValueNumberFont, weight: .semibold))
                            .foregroundStyle(displayScore >= 0 ? AppColors.brandGreen : AppColors.red600)
                    }
                }
            }
            .padding(metrics.rowPadding)
            // 选中/未选中状态只影响圆点/勾选框/颜色，不改变行高，避免布局跳动。
            .frame(height: metrics.rowHeightDefault)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isTimePickerPresented, arrowEdge: .bottom) {
            let preview = appStore.previewScore(for: habit, completionTime: selectedTime)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("选择时间")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.slate900)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("本次")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.slate500)
                        Text(preview >= 0 ? "+\(preview)分" : "\(preview)分")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(preview >= 0 ? AppColors.brandGreen : AppColors.red600)
                    }
                }

                DatePicker("", selection: $selectedTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
                    .controlSize(.small)

                HStack(spacing: 10) {
                    Button("取消") {
                        isTimePickerPresented = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.slate700)

                    Spacer()

                    Button("记录") {
                        appStore.recordToday(for: habit, completionTime: selectedTime)
                        isTimePickerPresented = false
                        refreshRecordedState()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(AppColors.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(14)
            .frame(width: 240)
            .background(Color.white)
        }
        .contextMenu {
            Button("撤销该事项今日记录") {
                appStore.toggleTodayRecord(for: habit)
                refreshRecordedState()
            }
        }
        .onAppear {
            refreshRecordedState()
        }
    }

    private func refreshRecordedState() {
        isRecordedToday = (appStore.recordForToday(habitId: habit.id) != nil)
    }

    private var displayScore: Int? {
        guard isRecordedToday else { return nil }
        if let record = appStore.recordForToday(habitId: habit.id) {
            return record.score
        }
        return habit.score
    }

    private var statusPill: some View {
        ZStack {
            Circle()
                .fill(isRecordedToday ? (habit.score >= 0 ? AppColors.brandGreen : AppColors.red600) : .white)
                .overlay(
                    Circle()
                        .stroke(isRecordedToday ? .clear : Color(red: 209/255, green: 213/255, blue: 219/255), lineWidth: 1)
                )
            if isRecordedToday {
                Image(systemName: habit.score >= 0 ? "checkmark" : "xmark")
                    .font(.system(size: 10 * metrics.scale, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20 * metrics.scale, height: 20 * metrics.scale)
    }

    private var checkBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isRecordedToday ? (habit.score >= 0 ? AppColors.brandGreen : AppColors.red600) : .white)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isRecordedToday ? .clear : Color(red: 209/255, green: 213/255, blue: 219/255), lineWidth: 1)
                )
            if isRecordedToday {
                Image(systemName: "checkmark")
                    .font(.system(size: 12 * metrics.scale, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20 * metrics.scale, height: 20 * metrics.scale)
    }

    private var backgroundColor: Color {
        if isRecordedToday {
            return habit.score >= 0 ? Color(red: 236/255, green: 253/255, blue: 245/255) : Color(red: 254/255, green: 242/255, blue: 242/255)
        }
        return Color.white
    }

    private var borderColor: Color {
        if isRecordedToday {
            return habit.score >= 0 ? Color(red: 167/255, green: 243/255, blue: 208/255) : Color(red: 254/255, green: 202/255, blue: 202/255)
        }
        return Color(red: 229/255, green: 231/255, blue: 235/255)
    }

    private var titleColor: Color {
        if isRecordedToday {
            return habit.score >= 0 ? Color(red: 6/255, green: 78/255, blue: 59/255) : Color(red: 127/255, green: 29/255, blue: 29/255)
        }
        return AppColors.slate700
    }

    private var scoreColor: Color {
        habit.score >= 0 ? Color(red: 5/255, green: 150/255, blue: 105/255) : Color(red: 220/255, green: 38/255, blue: 38/255)
    }
}

