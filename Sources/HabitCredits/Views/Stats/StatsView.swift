import SwiftUI
import Charts

private enum StatsRange: Int, CaseIterable, Identifiable {
    case days7 = 7
    case days30 = 30

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .days7: "近7天"
        case .days30: "近30天"
        }
    }
}

@MainActor
private final class StatsViewModel: ObservableObject {
    struct DailyPoint: Identifiable {
        var id: Date { day }
        let day: Date
        let netScore: Int
        /// 每日正向总分（所有 `score > 0` 的记录求和）
        let positiveScore: Int
        /// 每日扣分绝对值总分（所有 `score < 0` 的记录求和取绝对值）
        let spentScore: Int
        /// 每日获得（仅正分，不抵扣），与 `positiveScore` 口径一致
        let earnedScore: Int
    }

    struct HabitContribution: Identifiable {
        let id: UUID
        let habitName: String
        let iconName: String
        let iconColorHex: String?
        let times: Int
        let netTotalScore: Int
        /// 正向总分（仅正分，不抵扣）
        let earnedTotalScore: Int
        /// 扣分绝对值总分（用于扣分/负分列表）
        let spentTotalScore: Int
    }

    @Published var range: StatsRange = .days7
    /// 趋势图用的日序列：选「近7天」时仍拉 **90 天** 数据，便于横向滑动看更早历史；上方卡片/构成仍按 `range`。
    @Published private(set) var trendDaily: [DailyPoint] = []
    @Published private(set) var rangeNetTotal: Int = 0
    @Published private(set) var rangeEarnedTotal: Int = 0
    /// 期内扣分绝对值之和（用于「总支出」卡片）。
    @Published private(set) var rangeSpentTotal: Int = 0
    @Published private(set) var contributions: [HabitContribution] = []
    @Published private(set) var selectedDayContributions: [HabitContribution] = []

    private let calendar = Calendar.current
    private var recordsByDayInRange: [Date: [HabitRecord]] = [:]

    func refresh(store: AppStore) {
        let days = range.rawValue
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today

        /// 趋势图覆盖天数：近 7 天模式下给足历史，才能向右对齐「最近一周」后向左滑看更早。
        let trendDayCount: Int = {
            switch range {
            case .days7: return 90
            case .days30: return range.rawValue
            }
        }()
        let trendStart = calendar.date(byAdding: .day, value: -(trendDayCount - 1), to: today) ?? today

        let recordInRange = store.records.filter { $0.day >= start && $0.day <= today }
        let trendRecords = store.records.filter { $0.day >= trendStart && $0.day <= today }

        var byDay: [Date: [HabitRecord]] = [:]
        for r in trendRecords {
            byDay[r.day, default: []].append(r)
        }
        recordsByDayInRange = byDay

        var netScoreByDay: [Date: Int] = [:]
        var earnedScoreByDay: [Date: Int] = [:]
        var spentScoreByDay: [Date: Int] = [:]
        for r in recordInRange {
            netScoreByDay[r.day, default: 0] += r.score
            earnedScoreByDay[r.day, default: 0] += max(0, r.score)
            spentScoreByDay[r.day, default: 0] += max(0, -r.score)
        }

        var trendNet: [Date: Int] = [:]
        var trendEarned: [Date: Int] = [:]
        var trendSpent: [Date: Int] = [:]
        for r in trendRecords {
            trendNet[r.day, default: 0] += r.score
            trendEarned[r.day, default: 0] += max(0, r.score)
            trendSpent[r.day, default: 0] += max(0, -r.score)
        }

        var trendPoints: [DailyPoint] = []
        trendPoints.reserveCapacity(trendDayCount)
        for i in 0..<trendDayCount {
            let day = calendar.date(byAdding: .day, value: i, to: trendStart) ?? trendStart
            let d = calendar.startOfDay(for: day)
            let net = trendNet[d, default: 0]
            let earned = trendEarned[d, default: 0]
            let spent = trendSpent[d, default: 0]
            trendPoints.append(.init(day: d, netScore: net, positiveScore: earned, spentScore: spent, earnedScore: earned))
        }
        trendDaily = trendPoints

        var rangePointsNet: Int = 0
        var rangePointsEarned: Int = 0
        for i in 0..<days {
            let day = calendar.date(byAdding: .day, value: i, to: start) ?? start
            let d = calendar.startOfDay(for: day)
            rangePointsNet += netScoreByDay[d, default: 0]
            rangePointsEarned += earnedScoreByDay[d, default: 0]
        }

        rangeNetTotal = rangePointsNet
        rangeEarnedTotal = rangePointsEarned
        rangeSpentTotal = recordInRange.reduce(0) { $0 + max(0, -$1.score) }

        var map: [UUID: (times: Int, netTotal: Int, earnedTotal: Int, spentTotal: Int)] = [:]
        for r in recordInRange {
            let cur = map[r.habitId] ?? (0, 0, 0, 0)
            map[r.habitId] = (
                cur.times + 1,
                cur.netTotal + r.score,
                cur.earnedTotal + max(0, r.score),
                cur.spentTotal + max(0, -r.score)
            )
        }

        contributions = store.activeHabits.compactMap { h in
            guard let v = map[h.id] else { return nil }
            return HabitContribution(
                id: h.id,
                habitName: h.name,
                iconName: h.iconName ?? (h.score >= 0 ? "checkmark.seal.fill" : "xmark.seal.fill"),
                iconColorHex: h.iconColorHex,
                times: v.times,
                netTotalScore: v.netTotal,
                earnedTotalScore: v.earnedTotal,
                spentTotalScore: v.spentTotal
            )
        }
        .sorted { abs($0.netTotalScore) > abs($1.netTotalScore) }

        // 默认：当未选中某天时，事项贡献使用区间统计口径。
        selectedDayContributions = contributions
    }

    func refreshSelectedDayContributions(store: AppStore, day: Date?) {
        guard let day else {
            selectedDayContributions = contributions
            return
        }

        let d = calendar.startOfDay(for: day)
        let recordsForDay = recordsByDayInRange[d] ?? store.records.filter { $0.day == d }

        var map: [UUID: (times: Int, netTotal: Int, earnedTotal: Int, spentTotal: Int)] = [:]
        for r in recordsForDay {
            let cur = map[r.habitId] ?? (0, 0, 0, 0)
            map[r.habitId] = (
                times: cur.times + 1,
                netTotal: cur.netTotal + r.score,
                earnedTotal: cur.earnedTotal + max(0, r.score),
                spentTotal: cur.spentTotal + max(0, -r.score)
            )
        }

        selectedDayContributions = store.activeHabits.compactMap { h in
            guard let v = map[h.id] else { return nil }
            return HabitContribution(
                id: h.id,
                habitName: h.name,
                iconName: h.iconName ?? (h.score >= 0 ? "checkmark.seal.fill" : "xmark.seal.fill"),
                iconColorHex: h.iconColorHex,
                times: v.times,
                netTotalScore: v.netTotal,
                earnedTotalScore: v.earnedTotal,
                spentTotalScore: v.spentTotal
            )
        }
        .sorted { abs($0.netTotalScore) > abs($1.netTotalScore) }
    }
}

private enum ContributionMetric: Hashable {
    case net
    case earned
}

struct StatsView: View {
    @EnvironmentObject private var appStore: AppStore
    @StateObject private var vm = StatsViewModel()
    /// 趋势图选中的柱子（`index-日期`），与右侧「积分构成」联动。
    @State private var selectedTrendDayKey: String?

    var body: some View {
        PageLayout {
            statsHeader
            metricsRow
            calculationNote
            mainSplitSection
        }
        .onAppear {
            vm.refresh(store: appStore)
            syncTrendDayContributions()
        }
        .onChange(of: vm.range) { _, _ in
            selectedTrendDayKey = nil
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                vm.refresh(store: appStore)
            }
            syncTrendDayContributions()
        }
        .onChange(of: appStore.records.count) { _, _ in
            vm.refresh(store: appStore)
            syncTrendDayContributions()
        }
        .onChange(of: selectedTrendDayKey) { _, _ in
            syncTrendDayContributions()
        }
    }

    /// 按当前选中的柱子刷新右侧「积分构成」（`refresh` 会重置为区间口径，这里再对齐）。
    private func syncTrendDayContributions() {
        if let key = selectedTrendDayKey,
           let idx = Int(key.split(separator: "-").first ?? ""),
           vm.trendDaily.indices.contains(idx) {
            vm.refreshSelectedDayContributions(store: appStore, day: vm.trendDaily[idx].day)
        } else {
            vm.refreshSelectedDayContributions(store: appStore, day: nil)
        }
    }

    /// 设计稿：页面标题 + 时间范围选择器（与 Calicat「积分统计页」头部一致）。
    private var statsHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("积分统计")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.slate900)
                Text("查看积分趋势与构成")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.slate500)
            }
            Spacer(minLength: 12)
            Picker("", selection: $vm.range) {
                ForEach(StatsRange.allCases) { r in
                    Text(r.title).tag(r)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 180)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 设计稿：数据卡片组 — 总积分、总收入、总支出、净收入。
    private var metricsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                metricTile(
                    title: "总积分",
                    caption: "累计净分（全局）",
                    valueText: signed(appStore.totalNetScore()),
                    valueColor: appStore.totalNetScore() >= 0 ? AppColors.brandGreen : AppColors.red600
                )
                metricTile(
                    title: "总收入",
                    caption: "期内获得",
                    valueText: earnedSigned(vm.rangeEarnedTotal),
                    valueColor: AppColors.brandTeal
                )
                metricTile(
                    title: "总支出",
                    caption: "期内扣分",
                    valueText: vm.rangeSpentTotal == 0 ? "0" : "−\(vm.rangeSpentTotal)",
                    valueColor: vm.rangeSpentTotal == 0 ? AppColors.slate500 : AppColors.red600
                )
                metricTile(
                    title: "净收入",
                    caption: "期内净分",
                    valueText: signed(vm.rangeNetTotal),
                    valueColor: vm.rangeNetTotal >= 0 ? AppColors.brandGreen : AppColors.red600
                )
            }
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    metricTile(
                        title: "总积分",
                        caption: "累计净分（全局）",
                        valueText: signed(appStore.totalNetScore()),
                        valueColor: appStore.totalNetScore() >= 0 ? AppColors.brandGreen : AppColors.red600
                    )
                    metricTile(
                        title: "总收入",
                        caption: "期内获得",
                        valueText: earnedSigned(vm.rangeEarnedTotal),
                        valueColor: AppColors.brandTeal
                    )
                }
                HStack(spacing: 12) {
                    metricTile(
                        title: "总支出",
                        caption: "期内扣分",
                        valueText: vm.rangeSpentTotal == 0 ? "0" : "−\(vm.rangeSpentTotal)",
                        valueColor: vm.rangeSpentTotal == 0 ? AppColors.slate500 : AppColors.red600
                    )
                    metricTile(
                        title: "净收入",
                        caption: "期内净分",
                        valueText: signed(vm.rangeNetTotal),
                        valueColor: vm.rangeNetTotal >= 0 ? AppColors.brandGreen : AppColors.red600
                    )
                }
            }
        }
    }

    private var calculationNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("口径说明")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.slate700)
            Text("每日正分收入=当日所有 `score>0` 之和；每日负分支出=当日所有扣分绝对值之和；净分=正分收入-负分支出；获得=只累计正分（不抵扣）；总支出=扣分绝对值之和。")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.slate500)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private func metricTile(title: String, caption: String, valueText: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.slate700)
                Text(caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.slate500.opacity(0.85))
            }
            Text(valueText)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    /// 设计稿：左侧「积分趋势图」+ 右侧「积分构成统计」。
    private var mainSplitSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                trendPanel
                    .frame(maxWidth: .infinity, minHeight: 360)
                compositionPanel
                    .frame(width: 260, alignment: .top)
            }
            VStack(alignment: .leading, spacing: 16) {
                trendPanel
                compositionPanel
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 趋势数据或区间变化时，让图表重新滚到「最新」一侧。
    private var trendScrollAlignToken: String {
        let last = vm.trendDaily.last?.day.timeIntervalSince1970 ?? 0
        return "\(vm.range.rawValue)-\(vm.trendDaily.count)-\(last)"
    }

    /// 一屏内可见的「日期柱」数量（与分段一致：近 7 天=7；近 30 天=最多 15）。
    private var trendVisibleBarCount: Int {
        switch vm.range {
        case .days7:
            return 7
        case .days30:
            return min(15, max(vm.trendDaily.count, 1))
        }
    }

    private var trendPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("积分变化趋势")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.slate900)
            }
            if vm.trendDaily.count > trendVisibleBarCount {
                Text("一屏显示 \(trendVisibleBarCount) 天，可左右滑动查看更多。")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.slate500)
            }

            TrendBarChart(
                points: vm.trendDaily,
                scrollResetToken: trendScrollAlignToken,
                visibleBars: trendVisibleBarCount,
                selectedDayKey: $selectedTrendDayKey
            )
                .frame(maxWidth: .infinity)
                .frame(height: 220)

            trendLegend
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var trendLegend: some View {
        HStack(spacing: 20) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppColors.brandGreen)
                    .frame(width: 8, height: 8)
                Text("正分收入")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.slate700)
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(AppColors.red600)
                    .frame(width: 8, height: 8)
                Text("负分支出")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.slate700)
            }
        }
        .padding(.top, 4)
    }

    private var compositionPanel: some View {
        let rows = vm.selectedDayContributions
        let subtitle: String = {
            if let key = selectedTrendDayKey,
               let idx = Int(key.split(separator: "-").first ?? ""),
               vm.trendDaily.indices.contains(idx) {
                let d = vm.trendDaily[idx].day
                let c = Calendar.current
                return "\(c.component(.month, from: d))月\(c.component(.day, from: d))日 · 当日习惯贡献"
            }
            return "当前时间范围内的习惯贡献"
        }()

        return VStack(alignment: .leading, spacing: 12) {
            Text("积分构成统计")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.slate900)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.slate500)

            if rows.isEmpty {
                Text("暂无数据。先在任意日期记录一些事项。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.slate500)
                    .padding(.vertical, 6)
            } else {
                ContributionSplitList(contributions: rows)
                    .frame(minHeight: 220, maxHeight: 320)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func signed(_ v: Int) -> String {
        v >= 0 ? "+\(v)" : "\(v)"
    }

    private func earnedSigned(_ v: Int) -> String {
        "+\(v)"
    }

}

// MARK: - 趋势柱状图（横向滚动 + 点击联动）

private struct TrendBarChart: View {
    let points: [StatsViewModel.DailyPoint]
    let scrollResetToken: String
    let visibleBars: Int
    @Binding var selectedDayKey: String?

    private static let plotTopInset: CGFloat = 12
    private static let yAxisLeading: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let layout = makeLayout(viewportWidth: max(geo.size.width, 1))
            let keys = dayKeys

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    chart(keys: keys, layout: layout)
                        .frame(width: layout.contentWidth, height: geo.size.height)
                        .id("trendChartScroll")
                }
                .onAppear { scrollToEnd(proxy) }
                .onChange(of: scrollResetToken) { _, _ in
                    scrollToEnd(proxy)
                }
            }
        }
        .frame(height: 220)
    }

    private var dayKeys: [String] {
        let cal = Calendar.current
        return points.enumerated().map { i, p in
            let m = cal.component(.month, from: p.day)
            let d = cal.component(.day, from: p.day)
            return "\(i)-\(m)月 \(d)日"
        }
    }

    private func makeLayout(viewportWidth: CGFloat) -> (slotWidth: CGFloat, contentWidth: CGFloat, barWidth: Double) {
        let n = max(points.count, 1)
        let barsToShow = min(visibleBars, n)
        let slot = floor((viewportWidth - Self.yAxisLeading) / CGFloat(barsToShow))
        let content = floor(CGFloat(n) * max(slot, 1) + Self.yAxisLeading)
        let barW = min(Double(max(slot, 1)) * 0.68, 36)
        return (max(slot, 1), max(content, 1), barW)
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo("trendChartScroll", anchor: .trailing)
        }
    }

    private func chart(keys: [String], layout: (slotWidth: CGFloat, contentWidth: CGFloat, barWidth: Double)) -> some View {
        let dayLabelByKey = Dictionary(uniqueKeysWithValues: zip(keys, points.map { pt in
            let c = Calendar.current
            return "\(c.component(.month, from: pt.day))月 \(c.component(.day, from: pt.day))日"
        }))

        return Chart {
            ForEach(0..<points.count, id: \.self) { idx in
                let pt = points[idx]
                let k = keys[idx]
                BarMark(
                    x: .value("DayKey", k),
                    yStart: .value("基线", 0),
                    yEnd: .value("正分", Double(pt.positiveScore)),
                    width: .fixed(layout.barWidth)
                )
                .foregroundStyle(AppColors.brandGreen.opacity(selectedDayKey == k ? 1 : 0.88))
                BarMark(
                    x: .value("DayKey", k),
                    yStart: .value("基线", 0),
                    yEnd: .value("扣分", -Double(pt.spentScore)),
                    width: .fixed(layout.barWidth)
                )
                .foregroundStyle(AppColors.red600.opacity(selectedDayKey == k ? 1 : 0.88))
            }
            RuleMark(y: .value("0", 0))
                .foregroundStyle(Color.black.opacity(0.12))
                .lineStyle(.init(lineWidth: 1))
        }
        .chartYScale(domain: -Double(tickMax)...Double(tickMax))
        .chartXSelection(value: $selectedDayKey)
        .chartPlotStyle { plot in
            plot.padding(.top, Self.plotTopInset).padding(.leading, 0).padding(.trailing, 0)
        }
        .chartXAxis {
            if points.count <= 14 {
                AxisMarks(values: keys) { value in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisTick()
                    AxisValueLabel {
                        if let key = value.as(String.self), let t = dayLabelByKey[key] {
                            Text(t).font(.system(size: 9, weight: .medium)).foregroundStyle(AppColors.slate500)
                        }
                    }
                }
            } else {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisTick()
                    AxisValueLabel {
                        if let key = value.as(String.self), let t = dayLabelByKey[key] {
                            Text(t).font(.system(size: 9, weight: .medium)).foregroundStyle(AppColors.slate500)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: tickValues.map { Double($0) }) { value in
                AxisGridLine().foregroundStyle(Color.black.opacity(0.06))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        let i = Int(v.rounded())
                        let text = i == 0 ? "0" : (i > 0 ? "+\(i)" : "\(i)")
                        Text(text).font(.system(size: 9, weight: .medium)).foregroundStyle(AppColors.slate500)
                    }
                }
            }
        }
    }

    private var tickMax: Int {
        let maxPos = points.map(\.positiveScore).max() ?? 0
        let maxSpent = points.map(\.spentScore).max() ?? 0
        let maxAbs = max(maxPos, maxSpent, 1)
        let rounded = Int(ceil(Double(maxAbs) / 50.0) * 50.0)
        return max(50, rounded)
    }

    private var tickValues: [Int] {
        let half = tickMax / 2
        return [-tickMax, -half, 0, half, tickMax].filter { $0 != 0 || tickMax >= 50 }
    }
}

private struct ContributionSplitList: View {
    let contributions: [StatsViewModel.HabitContribution]

    private var positiveItems: [StatsViewModel.HabitContribution] {
        contributions
            .filter { $0.earnedTotalScore > 0 }
            .sorted { $0.earnedTotalScore > $1.earnedTotalScore }
    }

    private var negativeItems: [StatsViewModel.HabitContribution] {
        contributions
            .filter { $0.spentTotalScore > 0 }
            .sorted { $0.spentTotalScore > $1.spentTotalScore }
    }

    private var maxPositive: Int { max(1, positiveItems.map { $0.earnedTotalScore }.max() ?? 1) }
    private var maxNegative: Int { max(1, negativeItems.map { $0.spentTotalScore }.max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !positiveItems.isEmpty {
                ForEach(positiveItems.prefix(6)) { c in
                    ContributionSignRow(
                        name: c.habitName,
                        iconName: c.iconName,
                        iconColorHex: c.iconColorHex,
                        value: c.earnedTotalScore,
                        isPositive: true,
                        maxAbs: maxPositive
                    )
                }
            }

            if !negativeItems.isEmpty {
                Text("负分项")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.red600)
                    .padding(.top, positiveItems.isEmpty ? 0 : -6)

                ForEach(negativeItems.prefix(6)) { c in
                    ContributionSignRow(
                        name: c.habitName,
                        iconName: c.iconName,
                        iconColorHex: c.iconColorHex,
                        value: c.spentTotalScore,
                        isPositive: false,
                        maxAbs: maxNegative
                    )
                }
            }
        }
    }
}

private struct ContributionSignRow: View {
    let name: String
    let iconName: String
    let iconColorHex: String?
    let value: Int
    let isPositive: Bool
    let maxAbs: Int

    private var iconColor: Color {
        AppColors.color(hex: iconColorHex ?? "") ?? (isPositive ? AppColors.brandGreen : AppColors.red600)
    }

    private var barColor: Color { iconColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.slate900)

                Spacer()

                Text(isPositive ? "+\(value)" : "-\(value)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isPositive ? AppColors.brandGreen : AppColors.red600)
            }

            GeometryReader { geo in
                let ratio = CGFloat(max(0, value)) / CGFloat(max(1, maxAbs))
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(barColor)
                        .frame(width: max(6, width * ratio), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct ContributionBarChart: View {
    let contributions: [StatsViewModel.HabitContribution]
    let metric: ContributionMetric

    private var topItems: [StatsViewModel.HabitContribution] {
        let sorted: [StatsViewModel.HabitContribution]
        switch metric {
        case .net:
            sorted = contributions.sorted { abs($0.netTotalScore) > abs($1.netTotalScore) }
        case .earned:
            sorted = contributions.sorted { $0.earnedTotalScore > $1.earnedTotalScore }
        }
        return Array(sorted.prefix(8))
    }

    var body: some View {
        let items = topItems

        Chart {
            ForEach(items) { c in
                let valueInt: Int = (metric == .net) ? c.netTotalScore : c.earnedTotalScore
                let value = Double(valueInt)
                BarMark(
                    x: .value("分", value),
                    y: .value("事项", c.habitName)
                )
                .foregroundStyle(barColor(for: valueInt))
                .cornerRadius(5)
            }

            if metric == .net {
                RuleMark(x: .value("0", 0))
                    .foregroundStyle(Color.black.opacity(0.12))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.black.opacity(0.05))
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        let i = Int(v.rounded())
                        Text(xLabelText(i))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.slate500)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(Color.black.opacity(0.04))
                AxisValueLabel {
                    if let s = value.as(String.self) {
                        Text(s)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.slate500)
                            .lineLimit(1)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func barColor(for value: Int) -> Color {
        switch metric {
        case .net:
            return value >= 0 ? AppColors.brandGreen : AppColors.red600
        case .earned:
            return AppColors.brandTeal
        }
    }

    private func xLabelText(_ value: Int) -> String {
        switch metric {
        case .net:
            if value == 0 { return "0" }
            return value > 0 ? "+\(value)" : "\(value)"
        case .earned:
            if value == 0 { return "0" }
            return "+\(value)"
        }
    }
}

private enum TrendMetric {
    case net
    case earned
}

private struct TrendChart: View {
    let points: [StatsViewModel.DailyPoint]
    let metric: TrendMetric
    @Binding var selectedDay: Date?

    var body: some View {
        Group {
            if metric == .net {
                let maxAbs = max(1, points.map { abs($0.netScore) }.max() ?? 1)
                let top = Double(maxAbs)
                let bottom = -Double(maxAbs)

                Chart {
                ForEach(points) { pt in
                    let positive = Double(max(pt.netScore, 0))
                    AreaMark(
                        x: .value("日期", pt.day),
                        yStart: .value("基线", 0),
                        yEnd: .value("正向净分", positive)
                    )
                    .opacity(pt.netScore > 0 ? 1 : 0)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.brandGreen.opacity(0.22),
                                AppColors.brandGreen.opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                ForEach(points) { pt in
                    let negative = Double(min(pt.netScore, 0))
                    AreaMark(
                        x: .value("日期", pt.day),
                        yStart: .value("基线", 0),
                        yEnd: .value("负向净分", negative)
                    )
                    .opacity(pt.netScore < 0 ? 1 : 0)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.red600.opacity(0.20),
                                AppColors.red600.opacity(0.02),
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }

                ForEach(points) { pt in
                    let positive = Double(max(pt.netScore, 0))
                    LineMark(
                        x: .value("日期", pt.day),
                        y: .value("正向折线", positive)
                    )
                    .opacity(pt.netScore > 0 ? 1 : 0)
                    .foregroundStyle(AppColors.brandGreen.opacity(0.9))
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                ForEach(points) { pt in
                    let negative = Double(min(pt.netScore, 0))
                    LineMark(
                        x: .value("日期", pt.day),
                        y: .value("负向折线", negative)
                    )
                    .opacity(pt.netScore < 0 ? 1 : 0)
                    .foregroundStyle(AppColors.red600.opacity(0.9))
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("0", 0))
                    .foregroundStyle(Color.black.opacity(0.10))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 3]))

                if let selectedDay,
                   let selected = nearestPoint(to: selectedDay) {
                    RuleMark(x: .value("选中", selected.day))
                        .foregroundStyle(Color.black.opacity(0.12))
                    PointMark(
                        x: .value("选中日期", selected.day),
                        y: .value("选中净分", selected.netScore)
                    )
                    .symbolSize(55)
                    .foregroundStyle(selected.netScore >= 0 ? AppColors.brandGreen : AppColors.red600)
                    .annotation(position: .top, alignment: .center) {
                        HStack(spacing: 6) {
                            Text(shortLabel(selected.day))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.slate700)
                            Text(selected.netScore >= 0 ? "+\(selected.netScore)" : "\(selected.netScore)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(selected.netScore >= 0 ? AppColors.brandGreen : AppColors.red600)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    }
                }
                }
                .chartYScale(domain: bottom ... top)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.black.opacity(0.05))
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(dayOnly(date))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AppColors.slate500)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.black.opacity(0.06))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(v == 0 ? "0" : (v > 0 ? "+\(v)" : "\(v)"))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AppColors.slate500)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot
                        .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                let maxEarned = max(1, points.map { $0.earnedScore }.max() ?? 1)
                let top = Double(maxEarned)

                Chart {
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("日期", pt.day),
                        yStart: .value("基线", 0),
                        yEnd: .value("累计获得", Double(pt.earnedScore))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.brandTeal.opacity(0.26),
                                AppColors.brandTeal.opacity(0.03),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                ForEach(points) { pt in
                    LineMark(
                        x: .value("日期", pt.day),
                        y: .value("累计获得折线", Double(pt.earnedScore))
                    )
                    .foregroundStyle(AppColors.brandTeal.opacity(0.95))
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("0", 0))
                    .foregroundStyle(Color.black.opacity(0.10))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 3]))

                if let selectedDay,
                   let selected = nearestPoint(to: selectedDay) {
                    RuleMark(x: .value("选中", selected.day))
                        .foregroundStyle(Color.black.opacity(0.12))
                    PointMark(
                        x: .value("选中日期", selected.day),
                        y: .value("选中累计获得", selected.earnedScore)
                    )
                    .symbolSize(55)
                    .foregroundStyle(AppColors.brandTeal)
                    .annotation(position: .top, alignment: .center) {
                        HStack(spacing: 6) {
                            Text(shortLabel(selected.day))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.slate700)
                            Text("+\(selected.earnedScore)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColors.brandTeal)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    }
                }
            }
                .chartYScale(domain: 0 ... top)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.black.opacity(0.05))
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(dayOnly(date))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AppColors.slate500)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.black.opacity(0.06))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(v == 0 ? "0" : "+\(v)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AppColors.slate500)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot
                        .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
        // 吞掉拖拽手势，避免 Charts 的横向交互被触发（让交互只保留 tap）。
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in }
        )
            }
        }
    }

    private func nearestPoint(to date: Date) -> StatsViewModel.DailyPoint? {
        guard !points.isEmpty else { return nil }
        return points.min(by: { abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date)) })
    }

    private func dayOnly(_ date: Date) -> String {
        let d = Calendar.current.component(.day, from: date)
        return "\(d)"
    }

    private func shortLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

