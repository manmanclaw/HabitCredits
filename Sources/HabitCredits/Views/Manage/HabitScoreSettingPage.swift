import SwiftUI

struct HabitScoreSettingPage: View {
    let target: HabitEditorTarget

    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var navigationStore: AppNavigationStore

    @State private var name: String = ""
    @State private var scoreText: String = "10"
    @State private var iconNameText: String = ""

    private var editingHabit: Habit? {
        switch target {
        case .create:
            return nil
        case .edit(let id):
            return appStore.activeHabits.first(where: { $0.id == id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(alignment: .leading, spacing: 12) {
                Text("基本信息")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 55/255, green: 65/255, blue: 81/255))

                inputField(title: "事项名称（最多20字）", text: $name)

                inputField(title: "分数（可输入负数）", text: $scoreText)
                    .help("例如：好习惯填 10，坏习惯填 -10")

                inputField(title: "事项图标（SF Symbols 名称）", text: $iconNameText)
                    .help("例如：moon.stars.fill / fork.knife / flame.fill")
            }

            Spacer(minLength: 0)

            quickIconPicker

            HStack(spacing: 12) {
                Button {
                    navigationStore.habitEditorTarget = nil
                } label: {
                    Text("取消")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.slate700)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(red: 241/255, green: 245/255, blue: 249/255))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    save()
                } label: {
                    Text(target == .create ? "添加事项" : "保存设置")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppColors.brandGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .onAppear {
            syncFromEditingHabit()
        }
    }

    private var header: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(AppColors.bg)
                    .overlay(Circle().stroke(AppColors.border, lineWidth: 1))

                Image(systemName: iconNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (target == .create ? "sparkles" : (editingHabit?.iconName ?? "sparkles")) : iconNameText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.brandGreen)
            }
            .frame(width: 32, height: 32)

            Text(target == .create ? "添加事项" : "编辑习惯设置")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.slate900)

            Spacer()

            Button {
                navigationStore.habitEditorTarget = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.slate700)
                    .frame(width: 32, height: 32)
                    .background(Color(red: 241/255, green: 245/255, blue: 249/255))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .background(AppColors.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func inputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.slate500)

            TextField("", text: text)
                .textFieldStyle(.plain)
                .padding(11)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Int(scoreText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func syncFromEditingHabit() {
        switch target {
        case .create:
            name = ""
            scoreText = "10"
            iconNameText = ""
        case .edit:
            if let h = editingHabit {
                name = h.name
                scoreText = String(h.score)
                iconNameText = h.iconName ?? ""
            }
        }
    }

    private func save() {
        guard let score = Int(scoreText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        let trimmedIcon = iconNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let iconName: String? = trimmedIcon.isEmpty ? nil : trimmedIcon
        switch target {
        case .create:
            appStore.createHabit(name: name, score: score, iconName: iconName)
        case .edit(let id):
            if let h = appStore.activeHabits.first(where: { $0.id == id }) {
                appStore.updateHabit(h, name: name, score: score, iconName: iconName)
            }
        }
        navigationStore.habitEditorTarget = nil
    }

    private var quickIconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速选择图标（也可手动输入）")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.slate500)

            let icons: [String] = [
                "moon.stars.fill",
                "sun.max.fill",
                "fork.knife",
                "leaf.fill",
                "figure.run",
                "book.fill",
                "flame.fill",
                "bolt.fill",
                "heart.fill",
                "sparkles",
                "trash.fill"
            ]

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            iconNameText = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(iconNameText == icon ? AppColors.brandGreen : AppColors.slate700)
                                .frame(width: 40, height: 40)
                                .background(iconNameText == icon ? AppColors.bg : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(iconNameText == icon ? AppColors.brandGreen : AppColors.border, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

