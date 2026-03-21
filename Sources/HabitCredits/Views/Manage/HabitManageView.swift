import SwiftUI

struct HabitManageView: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var navigationStore: AppNavigationStore

    private var isCreatePresented: Binding<Bool> {
        Binding<Bool>(
            get: { navigationStore.habitEditorTarget == .create },
            set: { presented in
                if !presented {
                    navigationStore.habitEditorTarget = nil
                }
            }
        )
    }

    private var editHabitBinding: Binding<Habit?> {
        Binding<Habit?>(
            get: {
                guard case .edit(let id) = navigationStore.habitEditorTarget else { return nil }
                return appStore.activeHabits.first(where: { $0.id == id })
            },
            set: { _ in
                navigationStore.habitEditorTarget = nil
            }
        )
    }

    private var positiveHabits: [Habit] {
        appStore.activeHabits.filter { $0.score >= 0 }.sorted { $0.createdAt < $1.createdAt }
    }

    private var negativeHabits: [Habit] {
        appStore.activeHabits.filter { $0.score < 0 }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        HabitManageListPage(
            positiveHabits: positiveHabits,
            negativeHabits: negativeHabits,
            onCreate: { navigationStore.habitEditorTarget = .create },
            onEdit: { habit in navigationStore.habitEditorTarget = .edit(habit.id) }
        )
        .sheet(isPresented: isCreatePresented) {
            AddHabitSheet()
                .frame(width: 550, height: 560)
        }
        .sheet(item: editHabitBinding) { habit in
            AddHabitSheet(editingHabit: habit)
                .frame(width: 550, height: 560)
        }
    }
}

private struct HabitManageListPage: View {
    let positiveHabits: [Habit]
    let negativeHabits: [Habit]
    let onCreate: () -> Void
    let onEdit: (Habit) -> Void

    var body: some View {
        PageLayout {
            header
            habitList
        }
    }

    private var header: some View {
        PageHeader(title: "习惯管理", subtitle: "管理自定义习惯及分数规则") {
            HeaderPrimaryButton(title: "添加事项", systemImage: "plus") {
                onCreate()
            }
        }
    }

    private var habitList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if positiveHabits.isEmpty && negativeHabits.isEmpty {
                Text("暂无习惯。点击“添加事项”开始。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.slate500)
            } else {
                if !positiveHabits.isEmpty {
                    sectionHeader(color: AppColors.brandGreen, title: "正向习惯")
                    VStack(spacing: 8) {
                        ForEach(positiveHabits) { habit in
                            HabitManageRow(habit: habit, kind: .positive)
                                .onTapGesture { onEdit(habit) }
                        }
                    }
                }

                if !negativeHabits.isEmpty {
                    sectionHeader(color: AppColors.red600, title: "负向习惯（惩罚项）")
                    VStack(spacing: 8) {
                        ForEach(negativeHabits) { habit in
                            HabitManageRow(habit: habit, kind: .negative)
                                .onTapGesture { onEdit(habit) }
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.slate900)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private enum HabitKind {
    case positive
    case negative
}

private struct HabitManageRow: View {
    let habit: Habit
    let kind: HabitKind

    private var scoreText: String {
        habit.score >= 0 ? "+\(habit.score)" : "\(habit.score)"
    }

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    let iconColor = AppColors.color(hex: habit.iconColorHex ?? "")
                    Circle()
                        .fill((iconColor ?? (kind == .positive ? Color(red: 37/255, green: 99/255, blue: 235/255) : AppColors.red600)).opacity(0.22))
                        Image(systemName: habit.iconName ?? (kind == .positive ? "checkmark.seal.fill" : "xmark.seal.fill"))
                            .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconColor ?? (kind == .positive ? Color(red: 37/255, green: 99/255, blue: 235/255) : AppColors.red600))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.slate900)

                    Text(kind == .positive ? "简单勾选类 · 每日可完成1次" : "简单勾选类 · 记录即扣分")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.slate500)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text("完成得分")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.slate500)
                    Text(scoreText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(kind == .positive ? AppColors.brandGreen : AppColors.red600)
                }
            }
        }
        .padding(12)
        .frame(height: 60)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

