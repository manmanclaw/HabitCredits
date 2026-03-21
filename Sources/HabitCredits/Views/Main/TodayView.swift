import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appStore: AppStore

    @State private var isPresentingAddHabit = false
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var isDatePopoverPresented = false

    var body: some View {
        PageLayout {
            header
            todayCard
        }
        .sheet(isPresented: $isPresentingAddHabit) {
            AddHabitSheet()
                .frame(width: 550, height: 560)
        }
    }

    private var habits: [Habit] {
        appStore.activeHabits
    }

    private var header: some View {
        PageHeader(title: "习惯记录", subtitle: "记录与查看所有习惯完成情况") {
            HeaderPrimaryButton(title: "添加事项", systemImage: "plus") {
                isPresentingAddHabit = true
            }
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.brandGreen)
                        .frame(width: 9, height: 9)
                    Text(dayTitle(selectedDay))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.slate900)
                }
                Spacer()

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("当日积分")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.slate500)
                        Text(formattedSigned(appStore.todayScore(today: selectedDay)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.brandGreen)
                    }

                    Button {
                        appStore.undoLastRecord()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("撤销最后一次")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(AppColors.slate700)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Button {
                    shiftSelectedDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.slate700)
                        .frame(width: 28, height: 24)
                        .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    isDatePopoverPresented = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.slate500)
                        Text(dateLabel(selectedDay))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.slate900)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isDatePopoverPresented, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("选择日期")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.slate900)

                        DatePicker(
                            "",
                            selection: Binding(
                                get: { selectedDay },
                                set: { selectedDay = Calendar.current.startOfDay(for: $0) }
                            ),
                            displayedComponents: [.date]
                        )
                        .labelsHidden()
                        .datePickerStyle(.graphical)
                        .frame(width: 280)

                        HStack {
                            Spacer()
                            Button("关闭") { isDatePopoverPresented = false }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.slate700)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                }

                Button {
                    shiftSelectedDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.slate700)
                        .frame(width: 28, height: 24)
                        .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                if !Calendar.current.isDateInToday(selectedDay) {
                    Button("今天") {
                        selectedDay = Calendar.current.startOfDay(for: Date())
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.brandGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 236/255, green: 253/255, blue: 245/255))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Spacer()
            }

            if habits.isEmpty {
                Text("还没有事项，点击右上角“添加事项”开始。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.slate500)
                    .padding(.vertical, 8)
            } else {
                // 两列布局：避免事项名称过长导致显示不全
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(appStore.activeHabits) { habit in
                        TodayHabitChip(habit: habit, day: selectedDay)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 732, alignment: .leading)
    }

    private func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        let prefix = Calendar.current.isDateInToday(date) ? "今日" : "当天"
        return "\(prefix)（\(formatter.string(from: date))）"
    }

    private func formattedSigned(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }

    private func shiftSelectedDay(by delta: Int) {
        if let newDay = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) {
            selectedDay = Calendar.current.startOfDay(for: newDay)
        }
    }
}

private struct TodayHabitChip: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var navigationStore: AppNavigationStore
    let habit: Habit
    let day: Date

    @State private var isTimePickerPresented = false
    @State private var selectedTime = Date()

    var body: some View {
        Button {
            if isRecorded {
                appStore.toggleRecord(for: habit, day: day, completionTime: day)
                return
            }

            if habit.timeTiersRule != nil {
                selectedTime = Date()
                isTimePickerPresented = true
                return
            }

            appStore.toggleRecord(for: habit, day: day, completionTime: day)
        } label: {
            HStack(spacing: 6) {
                checkbox
                Image(systemName: habit.iconName ?? (habit.score >= 0 ? "checkmark.seal.fill" : "xmark.seal.fill"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColors.color(hex: habit.iconColorHex ?? "") ?? AppColors.slate500)
                Text(habit.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.slate900)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let displayScore = displayScore {
                    Text(displayScore >= 0 ? "+\(displayScore)" : "\(displayScore)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(displayScore >= 0 ? Color(red: 4/255, green: 120/255, blue: 87/255) : Color(red: 190/255, green: 18/255, blue: 60/255))
                }
            }
            .padding(8)
            .frame(height: 38)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isRecorded ? (habit.score >= 0 ? Color(red: 167/255, green: 243/255, blue: 208/255) : Color(red: 254/255, green: 202/255, blue: 202/255)) : AppColors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
                        appStore.record(for: habit, completionTime: selectedTime, day: day)
                        isTimePickerPresented = false
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
            Button {
                navigationStore.mainSection = .manage
                navigationStore.habitEditorTarget = .edit(habit.id)
            } label: {
                Text("编辑")
            }

            Button {
                appStore.deleteRecord(habitId: habit.id, day: day)
            } label: {
                Text("撤销该日记录")
            }

            Button(role: .destructive) {
                appStore.deleteHabit(habit)
            } label: {
                Text("删除")
            }
        }
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isRecorded ? (habit.score >= 0 ? AppColors.brandGreen : AppColors.red600) : .white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isRecorded ? .clear : AppColors.border, lineWidth: 1)
                )
            if isRecorded {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
    }

    private var record: HabitRecord? { appStore.record(for: habit.id, day: day) }
    private var isRecorded: Bool { record != nil }

    private var displayScore: Int? {
        guard isRecorded else { return nil }
        return record?.score ?? habit.score
    }
}

