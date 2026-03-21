import Foundation

struct TimeTiersRule: Codable, Hashable {
    /// 时间分段（仅时间类）：
    /// - 奖励：在某个时间之前，每隔 N 分钟，加 X 分（可开关）
    /// - 惩罚：在某个时间之后，每隔 N 分钟，扣 Y 分（可开关）
    /// 说明：按“分钟-of-day”计算（00:00~24:00）。
    var rewardEnabled: Bool
    var rewardCutoffMinutes: Int
    var rewardIntervalMinutes: Int
    var rewardPoints: Int

    var penaltyEnabled: Bool
    var penaltyCutoffMinutes: Int
    var penaltyIntervalMinutes: Int
    var penaltyPoints: Int

    /// 跨午夜语义（用于“昨晚入睡时间”这类场景）：
    /// - 当为 true 时：把 00:00~overnightSplitMinutes 的时间当作“次日时间轴”（分钟数 +1440）
    ///   例如 01:00 会按 25:00 参与比较与步进计算，从而落入惩罚段。
    var overnightEnabled: Bool
    var overnightSplitMinutes: Int

    private enum CodingKeys: String, CodingKey {
        // New keys (v4)
        case rewardEnabled
        case rewardCutoffMinutes
        case rewardIntervalMinutes
        case rewardPoints
        case penaltyEnabled
        case penaltyCutoffMinutes
        case penaltyIntervalMinutes
        case penaltyPoints
        case overnightEnabled
        case overnightSplitMinutes

        // Previous keys (v2)
        case cutoffMinutes
        case beforeStepMinutes
        case beforeAddPerStep
        case afterStepMinutes
        case afterSubtractPerStep

        // Old keys (compat)
        case cutoff1Minutes
        case lateWindowEndMinutes
        case firstScore
        case secondScore
        case lateStepMinutes
        case latePenaltyPerStep
    }

    init(
        rewardEnabled: Bool,
        rewardCutoffMinutes: Int,
        rewardIntervalMinutes: Int,
        rewardPoints: Int,
        penaltyEnabled: Bool,
        penaltyCutoffMinutes: Int,
        penaltyIntervalMinutes: Int,
        penaltyPoints: Int,
        overnightEnabled: Bool = true,
        overnightSplitMinutes: Int = 12 * 60
    ) {
        self.rewardEnabled = rewardEnabled
        self.rewardCutoffMinutes = rewardCutoffMinutes
        self.rewardIntervalMinutes = rewardIntervalMinutes
        self.rewardPoints = rewardPoints
        self.penaltyEnabled = penaltyEnabled
        self.penaltyCutoffMinutes = penaltyCutoffMinutes
        self.penaltyIntervalMinutes = penaltyIntervalMinutes
        self.penaltyPoints = penaltyPoints
        self.overnightEnabled = overnightEnabled
        self.overnightSplitMinutes = overnightSplitMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Prefer newest format (v4/v3)
        if let rewardEnabled = try container.decodeIfPresent(Bool.self, forKey: .rewardEnabled),
           let rewardCutoffMinutes = try container.decodeIfPresent(Int.self, forKey: .rewardCutoffMinutes),
           let rewardIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .rewardIntervalMinutes),
           let rewardPoints = try container.decodeIfPresent(Int.self, forKey: .rewardPoints),
           let penaltyEnabled = try container.decodeIfPresent(Bool.self, forKey: .penaltyEnabled),
           let penaltyCutoffMinutes = try container.decodeIfPresent(Int.self, forKey: .penaltyCutoffMinutes),
           let penaltyIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .penaltyIntervalMinutes),
           let penaltyPoints = try container.decodeIfPresent(Int.self, forKey: .penaltyPoints) {
            self.rewardEnabled = rewardEnabled
            self.rewardCutoffMinutes = rewardCutoffMinutes
            self.rewardIntervalMinutes = rewardIntervalMinutes
            self.rewardPoints = rewardPoints
            self.penaltyEnabled = penaltyEnabled
            self.penaltyCutoffMinutes = penaltyCutoffMinutes
            self.penaltyIntervalMinutes = penaltyIntervalMinutes
            self.penaltyPoints = penaltyPoints
            self.overnightEnabled = (try container.decodeIfPresent(Bool.self, forKey: .overnightEnabled)) ?? true
            self.overnightSplitMinutes = (try container.decodeIfPresent(Int.self, forKey: .overnightSplitMinutes)) ?? (12 * 60)
            return
        }

        // Fallback to previous format (v2)
        if let cutoffMinutes = try container.decodeIfPresent(Int.self, forKey: .cutoffMinutes),
           let beforeStepMinutes = try container.decodeIfPresent(Int.self, forKey: .beforeStepMinutes),
           let beforeAddPerStep = try container.decodeIfPresent(Int.self, forKey: .beforeAddPerStep),
           let afterStepMinutes = try container.decodeIfPresent(Int.self, forKey: .afterStepMinutes),
           let afterSubtractPerStep = try container.decodeIfPresent(Int.self, forKey: .afterSubtractPerStep) {
            self.rewardEnabled = true
            self.rewardCutoffMinutes = cutoffMinutes
            self.rewardIntervalMinutes = beforeStepMinutes
            self.rewardPoints = beforeAddPerStep
            self.penaltyEnabled = true
            self.penaltyCutoffMinutes = cutoffMinutes
            self.penaltyIntervalMinutes = afterStepMinutes
            self.penaltyPoints = afterSubtractPerStep
            self.overnightEnabled = true
            self.overnightSplitMinutes = 12 * 60
            return
        }

        // Fallback to old format:
        // cutoff1Minutes -> cutoffMinutes
        // firstScore -> beforeAddPerStep
        // lateStepMinutes -> afterStepMinutes
        // latePenaltyPerStep -> afterSubtractPerStep
        let cutoff1Minutes = try container.decode(Int.self, forKey: .cutoff1Minutes)
        let firstScore = try container.decode(Int.self, forKey: .firstScore)
        let lateStepMinutes = try container.decode(Int.self, forKey: .lateStepMinutes)
        let latePenaltyPerStep = try container.decode(Int.self, forKey: .latePenaltyPerStep)

        self.rewardEnabled = true
        self.rewardCutoffMinutes = cutoff1Minutes
        self.rewardIntervalMinutes = cutoff1Minutes + 1
        self.rewardPoints = firstScore

        self.penaltyEnabled = true
        self.penaltyCutoffMinutes = cutoff1Minutes
        self.penaltyIntervalMinutes = lateStepMinutes
        self.penaltyPoints = latePenaltyPerStep
        self.overnightEnabled = true
        self.overnightSplitMinutes = 12 * 60
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rewardEnabled, forKey: .rewardEnabled)
        try container.encode(rewardCutoffMinutes, forKey: .rewardCutoffMinutes)
        try container.encode(rewardIntervalMinutes, forKey: .rewardIntervalMinutes)
        try container.encode(rewardPoints, forKey: .rewardPoints)
        try container.encode(penaltyEnabled, forKey: .penaltyEnabled)
        try container.encode(penaltyCutoffMinutes, forKey: .penaltyCutoffMinutes)
        try container.encode(penaltyIntervalMinutes, forKey: .penaltyIntervalMinutes)
        try container.encode(penaltyPoints, forKey: .penaltyPoints)
        try container.encode(overnightEnabled, forKey: .overnightEnabled)
        try container.encode(overnightSplitMinutes, forKey: .overnightSplitMinutes)
    }
}

struct Habit: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var score: Int
    var iconName: String?
    var iconColorHex: String?
    /// 为时间分段规则时的配置；为 nil 表示“简单勾选模式”。
    var timeTiersRule: TimeTiersRule?
    var createdAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        score: Int,
        iconName: String? = nil,
        iconColorHex: String? = nil,
        timeTiersRule: TimeTiersRule? = nil,
        createdAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.score = score
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.timeTiersRule = timeTiersRule
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

struct HabitRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var habitId: UUID
    var day: Date
    var recordedAt: Date
    var score: Int

    init(id: UUID = UUID(), habitId: UUID, day: Date, recordedAt: Date = Date(), score: Int) {
        self.id = id
        self.habitId = habitId
        self.day = day
        self.recordedAt = recordedAt
        self.score = score
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []
    @Published private(set) var records: [HabitRecord] = []
    /// 持久化相关错误：用于 UI 层统一展示（避免 save() 静默失败）。
    @Published var persistenceErrorMessage: String? = nil

    private let fileStore = FileStore()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        load()
        seedIfNeeded()
    }

    // MARK: - Habits

    func createHabit(name: String, score: Int) {
        createHabit(name: name, score: score, iconName: nil, iconColorHex: nil, timeTiersRule: nil)
    }

    func createHabit(
        name: String,
        score: Int,
        iconName: String?,
        iconColorHex: String? = nil,
        timeTiersRule: TimeTiersRule? = nil
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let safeName = String(trimmedName.prefix(20))

        let safeIcon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIcon: String? = {
            guard let safeIcon, !safeIcon.isEmpty else {
                // 未配置图标：给一个稳妥默认图标
                return score >= 0 ? "checkmark.seal.fill" : "xmark.seal.fill"
            }
            return safeIcon
        }()

        let safeColor = iconColorHex?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalColor: String? = {
            guard let safeColor, !safeColor.isEmpty else { return nil }
            return safeColor
        }()

        habits.append(Habit(name: safeName, score: score, iconName: finalIcon, iconColorHex: finalColor, timeTiersRule: timeTiersRule))
        habits.sort { $0.createdAt < $1.createdAt }
        save()
    }

    func updateHabit(_ habit: Habit, name: String, score: Int) {
        updateHabit(habit, name: name, score: score, iconName: habit.iconName, iconColorHex: habit.iconColorHex, timeTiersRule: habit.timeTiersRule)
    }

    func updateHabit(
        _ habit: Habit,
        name: String,
        score: Int,
        iconName: String?,
        iconColorHex: String? = nil,
        timeTiersRule: TimeTiersRule? = nil
    ) {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let safeName = String(trimmedName.prefix(20))

        let safeIcon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIcon: String? = {
            guard let safeIcon, !safeIcon.isEmpty else {
                return score >= 0 ? "checkmark.seal.fill" : "xmark.seal.fill"
            }
            return safeIcon
        }()

        habits[idx].name = safeName
        habits[idx].score = score
        habits[idx].iconName = finalIcon
        let safeColor = iconColorHex?.trimmingCharacters(in: .whitespacesAndNewlines)
        habits[idx].iconColorHex = (safeColor?.isEmpty == false) ? safeColor : nil
        habits[idx].timeTiersRule = timeTiersRule
        save()
    }

    func archiveHabit(_ habit: Habit) {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[idx].isArchived = true
        save()
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        records.removeAll { $0.habitId == habit.id }
        save()
    }

    var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    // MARK: - Records

    func recordForToday(habitId: UUID, today: Date = Date()) -> HabitRecord? {
        record(for: habitId, day: today)
    }

    func toggleTodayRecord(for habit: Habit, today: Date = Date()) {
        toggleRecord(for: habit, day: today, completionTime: today)
    }

    func recordToday(for habit: Habit, completionTime: Date, today: Date = Date()) {
        record(for: habit, completionTime: completionTime, day: today)
    }

    func todayScore(today: Date = Date()) -> Int {
        let day = calendar.startOfDay(for: today)
        return records.filter { $0.day == day }.reduce(0) { $0 + $1.score }
    }

    func totalScore() -> Int {
        records.reduce(0) { $0 + $1.score }
    }

    /// 净积分：包含加分与扣分（可为负）。
    func totalNetScore() -> Int {
        totalScore()
    }

    /// 累计获得：仅累计正向得分（扣分不抵扣）。
    func totalEarnedScore() -> Int {
        records.reduce(0) { $0 + max(0, $1.score) }
    }

    func undoLastRecord() {
        guard let last = records.max(by: { $0.recordedAt < $1.recordedAt }) else { return }
        records.removeAll { $0.id == last.id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        do {
            let snapshot = try fileStore.load()
            habits = snapshot.habits
            records = snapshot.records
        } catch {
            persistenceErrorMessage = "数据加载失败：\(error.localizedDescription)"
            habits = []
            records = []
        }
    }

    private func save() {
        persistenceErrorMessage = nil
        do {
            try fileStore.save(snapshot: .init(habits: habits, records: records))
        } catch {
            persistenceErrorMessage = "数据保存失败：\(error.localizedDescription)"
        }
    }

    enum ImportMode: String, CaseIterable {
        case merge
        case overwrite
    }

    // MARK: - Import / Export (Dev format, no IDs)

    struct ExportHabit: Codable, Hashable {
        var name: String
        var score: Int
        var iconName: String?
        var iconColorHex: String?
        var timeTiersRule: TimeTiersRule?
        var createdAt: Date
        var isArchived: Bool
    }

    struct ExportRecord: Codable, Hashable {
        var day: Date
        var habitName: String
        var recordedAt: Date
        var score: Int
    }

    struct ExportSnapshot: Codable, Hashable {
        var habits: [ExportHabit]
        var records: [ExportRecord]
    }

    private var exportEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var exportDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func exportSnapshotJsonData() throws -> Data {
        let nameById: [UUID: String] = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0.name) })

        // 同一事项同一天，多次操作只保留最后一次（recordedAt 最新）
        var latestByKey: [String: HabitRecord] = [:]
        for r in records {
            let habitName = nameById[r.habitId] ?? ""
            let key = "\(habitName)|\(r.day.timeIntervalSince1970)"
            if let existing = latestByKey[key] {
                if r.recordedAt > existing.recordedAt {
                    latestByKey[key] = r
                }
            } else {
                latestByKey[key] = r
            }
        }

        let exportHabits: [ExportHabit] = habits.sorted { $0.createdAt < $1.createdAt }.map {
            .init(
                name: $0.name,
                score: $0.score,
                iconName: $0.iconName,
                iconColorHex: $0.iconColorHex,
                timeTiersRule: $0.timeTiersRule,
                createdAt: $0.createdAt,
                isArchived: $0.isArchived
            )
        }

        let exportRecords: [ExportRecord] = latestByKey.values
            .map { r in
                ExportRecord(
                    day: r.day,
                    habitName: nameById[r.habitId] ?? "",
                    recordedAt: r.recordedAt,
                    score: r.score
                )
            }
            .sorted { $0.recordedAt > $1.recordedAt }

        return try exportEncoder.encode(ExportSnapshot(habits: exportHabits, records: exportRecords))
    }

    func importSnapshotJsonData(_ data: Data, mode: ImportMode) throws {
        let snapshot = try exportDecoder.decode(ExportSnapshot.self, from: data)
        importExportSnapshot(snapshot, mode: mode)
    }

    func importExportSnapshot(_ snapshot: ExportSnapshot, mode: ImportMode) {
        let cal = calendar

        func normalizeName(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        switch mode {
        case .overwrite:
            // 重建 habits（新 id）
            var newHabits: [Habit] = []
            newHabits.reserveCapacity(snapshot.habits.count)
            var idByName: [String: UUID] = [:]
            for h in snapshot.habits {
                let name = String(normalizeName(h.name).prefix(20))
                let id = UUID()
                idByName[name] = id
                newHabits.append(
                    Habit(
                        id: id,
                        name: name,
                        score: h.score,
                        iconName: h.iconName,
                        iconColorHex: h.iconColorHex,
                        timeTiersRule: h.timeTiersRule,
                        createdAt: h.createdAt,
                        isArchived: h.isArchived
                    )
                )
            }
            habits = newHabits.sorted { $0.createdAt < $1.createdAt }

            // 重建 records（按 habitName 关联）
            var newRecords: [HabitRecord] = []
            var latest: [String: ExportRecord] = [:]
            for r in snapshot.records {
                let name = String(normalizeName(r.habitName).prefix(20))
                let day = cal.startOfDay(for: r.day)
                let key = "\(name)|\(day.timeIntervalSince1970)"
                if let existing = latest[key] {
                    if r.recordedAt > existing.recordedAt {
                        latest[key] = r
                    }
                } else {
                    latest[key] = r
                }
            }
            for r in latest.values {
                let name = String(normalizeName(r.habitName).prefix(20))
                guard let habitId = idByName[name] else { continue }
                let day = cal.startOfDay(for: r.day)
                newRecords.append(.init(habitId: habitId, day: day, recordedAt: r.recordedAt, score: r.score))
            }
            records = newRecords.sorted { $0.recordedAt > $1.recordedAt }
            save()

        case .merge:
            // 建立或复用现有 habit（按名称匹配）
            var idByName: [String: UUID] = Dictionary(uniqueKeysWithValues: habits.map { ($0.name, $0.id) })

            for h in snapshot.habits {
                let name = String(normalizeName(h.name).prefix(20))
                if idByName[name] == nil {
                    let id = UUID()
                    idByName[name] = id
                    habits.append(
                        Habit(
                            id: id,
                            name: name,
                            score: h.score,
                            iconName: h.iconName,
                            iconColorHex: h.iconColorHex,
                            timeTiersRule: h.timeTiersRule,
                            createdAt: h.createdAt,
                            isArchived: h.isArchived
                        )
                    )
                }
            }
            habits.sort { $0.createdAt < $1.createdAt }

            // records 合并：同一事项同一天，保留 recordedAt 最新
            var latestByKey: [String: HabitRecord] = [:]
            var habitNameById: [UUID: String] = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0.name) })
            for r in records {
                let name = habitNameById[r.habitId] ?? ""
                let day = cal.startOfDay(for: r.day)
                let key = "\(name)|\(day.timeIntervalSince1970)"
                latestByKey[key] = r
            }

            for r in snapshot.records {
                let name = String(normalizeName(r.habitName).prefix(20))
                guard let habitId = idByName[name] else { continue }
                let day = cal.startOfDay(for: r.day)
                let key = "\(name)|\(day.timeIntervalSince1970)"

                let incoming = HabitRecord(habitId: habitId, day: day, recordedAt: r.recordedAt, score: r.score)
                if let existing = latestByKey[key] {
                    if incoming.recordedAt > existing.recordedAt {
                        latestByKey[key] = incoming
                    }
                } else {
                    latestByKey[key] = incoming
                }
            }

            records = Array(latestByKey.values).sorted { $0.recordedAt > $1.recordedAt }
            save()
        }
    }

    func exportRecordsCsvString() -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var habitNameById: [UUID: String] = [:]
        for h in habits {
            habitNameById[h.id] = h.name
        }

        func esc(_ s: String) -> String {
            if s.contains(",") || s.contains("\"") || s.contains("\n") {
                return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            return s
        }

        var lines: [String] = []
        lines.append("day,habitName,recordedAt,score")

        // 同一事项同一天，保留 recordedAt 最新
        var latestByKey: [String: HabitRecord] = [:]
        for r in records {
            let name = habitNameById[r.habitId] ?? ""
            let key = "\(name)|\(r.day.timeIntervalSince1970)"
            if let existing = latestByKey[key] {
                if r.recordedAt > existing.recordedAt {
                    latestByKey[key] = r
                }
            } else {
                latestByKey[key] = r
            }
        }

        for r in latestByKey.values.sorted(by: { $0.recordedAt > $1.recordedAt }) {
            let day = iso.string(from: r.day)
            let recordedAt = iso.string(from: r.recordedAt)
            let habitName = habitNameById[r.habitId] ?? ""
            lines.append("\(day),\(esc(habitName)),\(recordedAt),\(r.score)")
        }
        return lines.joined(separator: "\n")
    }

    private func seedIfNeeded() {
        guard habits.isEmpty && records.isEmpty else { return }
        createHabit(
            name: "早睡",
            score: 20,
            iconName: "moon.stars.fill",
            iconColorHex: "10B981",
            timeTiersRule: TimeTiersRule(
                rewardEnabled: true,
                rewardCutoffMinutes: 22 * 60,            // 22:00 前奖励
                rewardIntervalMinutes: 22 * 60 + 1,       // 近似固定 +20
                rewardPoints: 20,
                penaltyEnabled: true,
                penaltyCutoffMinutes: 0,                 // 00:00 后惩罚（今日 00:00）
                penaltyIntervalMinutes: 30,
                penaltyPoints: 5,
                overnightEnabled: true,
                overnightSplitMinutes: 12 * 60
            )
        )
        createHabit(name: "吃早餐", score: 10, iconName: "fork.knife", iconColorHex: "F59E0B")
        createHabit(name: "吃垃圾食品", score: -10, iconName: "flame.fill", iconColorHex: "EF4444")
    }

    private func scoreForCompletion(habit: Habit, completionTime: Date) -> Int {
        guard let rule = habit.timeTiersRule else { return habit.score }
        let hour = calendar.component(.hour, from: completionTime)
        let minute = calendar.component(.minute, from: completionTime)
        let rawMinutes = hour * 60 + minute

        func normalize(_ minutes: Int) -> Int {
            guard rule.overnightEnabled else { return minutes }
            let split = max(0, min(24 * 60, rule.overnightSplitMinutes))
            if minutes < split {
                return minutes + 24 * 60
            }
            return minutes
        }

        let minutesOfDay = normalize(rawMinutes)
        let rewardCutoff = normalize(rule.rewardCutoffMinutes)
        let penaltyCutoff = normalize(rule.penaltyCutoffMinutes)

        var score = 0

        if rule.rewardEnabled {
            let interval = max(1, rule.rewardIntervalMinutes)
            let points = max(0, rule.rewardPoints)
            if minutesOfDay < rewardCutoff {
                let diff = rewardCutoff - minutesOfDay
                let steps = Int(ceil(Double(diff) / Double(interval)))
                score += steps * points
            }
        }

        if rule.penaltyEnabled {
            let interval = max(1, rule.penaltyIntervalMinutes)
            let points = max(0, rule.penaltyPoints)
            if minutesOfDay > penaltyCutoff {
                let diff = minutesOfDay - penaltyCutoff
                let steps = Int(ceil(Double(diff) / Double(interval)))
                score -= steps * points
            }
        }

        return score
    }

    func previewScore(for habit: Habit, completionTime: Date) -> Int {
        scoreForCompletion(habit: habit, completionTime: completionTime)
    }

    func record(for habitId: UUID, day: Date) -> HabitRecord? {
        let d = calendar.startOfDay(for: day)
        return records.first(where: { $0.habitId == habitId && $0.day == d })
    }

    func deleteRecord(habitId: UUID, day: Date) {
        let d = calendar.startOfDay(for: day)
        records.removeAll { $0.habitId == habitId && $0.day == d }
        save()
    }

    func toggleRecord(for habit: Habit, day: Date, completionTime: Date) {
        let d = calendar.startOfDay(for: day)
        if let existing = records.firstIndex(where: { $0.habitId == habit.id && $0.day == d }) {
            records.remove(at: existing)
            save()
            return
        }
        record(for: habit, completionTime: completionTime, day: day)
    }

    func record(for habit: Habit, completionTime: Date, day: Date) {
        let d = calendar.startOfDay(for: day)
        let computedScore = scoreForCompletion(habit: habit, completionTime: completionTime)

        if let existing = records.firstIndex(where: { $0.habitId == habit.id && $0.day == d }) {
            records[existing].recordedAt = completionTime
            records[existing].score = computedScore
        } else {
            records.append(HabitRecord(habitId: habit.id, day: d, recordedAt: completionTime, score: computedScore))
        }

        records.sort { $0.recordedAt > $1.recordedAt }
        save()
    }
}

