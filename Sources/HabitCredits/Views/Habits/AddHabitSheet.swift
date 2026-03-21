import SwiftUI
import AppKit

struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: AppStore

    let editingHabit: Habit?

    @State private var name: String
    @State private var iconNameText: String
    @State private var iconColorHex: String

    private enum HabitInputKind: Hashable {
        case simple
        case timeTiers
    }

    @State private var inputKind: HabitInputKind

    // Simple
    @State private var scoreText: String

    // TimeTiers（仅时间：奖励/惩罚 两行 + 开关）
    @State private var rewardEnabled: Bool
    @State private var rewardCutoffTime: Date
    @State private var rewardIntervalMinutesText: String
    @State private var rewardPointsText: String
    
    @State private var penaltyEnabled: Bool
    @State private var penaltyCutoffTime: Date
    @State private var penaltyIntervalMinutesText: String
    @State private var penaltyPointsText: String

    // Icon picker
    @State private var isIconPickerPresented: Bool

    private let iconCandidates: [String] = [
        "moon.stars.fill","sun.max.fill","fork.knife","leaf.fill","figure.run","book.fill",
        "flame.fill","flask.fill","bolt.fill","heart.fill","sparkles","trash.fill",
        "checkmark.seal.fill","xmark.seal.fill","star.fill","star.lefthalf.fill","star.righthalf.fill",
        "plus.circle.fill","minus.circle.fill","checkmark.circle.fill","xmark.circle.fill",
        "clock.fill","calendar","calendar.badge.clock","bed.double.fill","alarm.fill",
        "pencil.and.outline","paintbrush.pointed.fill","gamecontroller.fill","music.note",
        "gym.bag.fill","bicycle","figure.walk","figure.wave","flame.circle.fill",
        "drop.fill","water.waves","leaf.circle.fill","hare.fill","brain.head.profile",
        "scissors","wrench.and.screwdriver.fill","hammer.fill","shippingbox.fill",
        "bag.fill","bag.badge.plus.fill","cart.fill","creditcard.fill","shippingbox.fill",
        "shield.fill","shield.checkerboard.2.fill","sparkle","wand.and.rays","hand.raised.fill",
        "hand.tap.fill","sparkles.rectangle.fill","bell.fill","timer","timer.circle.fill",
        "text.book.closed.fill","book.pages.fill","graduationcap.fill","suit.heart.fill",
        "gift.fill","trophy.fill","medal.fill","flag.fill","flag.2.crossed.fill",
        "bolt.circle.fill","camera.fill","camera.rotate.fill","photo.fill",
        "house.fill","building.2.fill","sunrise.fill","sunset.fill","moonphase.waxing.crescent",
        "moonphase.waning.crescent","person.fill","person.crop.circle.fill","person.crop.circle.badge.checkmark.fill",
        "sunrise.circle.fill","sunset.circle.fill","cloud.fill","wind","wind.circle.fill"
    ]

    private let iconColorPaletteHex: [String] = [
        "10B981", "0EA5E9", "6366F1", "A855F7",
        "F43F5E", "EF4444", "F97316", "F59E0B",
        "84CC16", "14B8A6", "64748B", "111827"
    ]

    init(editingHabit: Habit? = nil) {
        self.editingHabit = editingHabit
        _name = State(initialValue: editingHabit?.name ?? "")
        _iconNameText = State(initialValue: editingHabit?.iconName ?? "")
        _iconColorHex = State(initialValue: editingHabit?.iconColorHex ?? "10B981")

        let hasRule = editingHabit?.timeTiersRule != nil
        _inputKind = State(initialValue: hasRule ? .timeTiers : .simple)

        _scoreText = State(initialValue: editingHabit.map { String($0.score) } ?? "10")

        // Defaults
        let cal = Calendar.current
        _rewardEnabled = State(initialValue: true)
        _rewardCutoffTime = State(initialValue: Self.makeTimeDate(hour: 22, minute: 0, calendar: cal))
        _rewardIntervalMinutesText = State(initialValue: "30")
        _rewardPointsText = State(initialValue: "5")
        
        _penaltyEnabled = State(initialValue: true)
        _penaltyCutoffTime = State(initialValue: Self.makeTimeDate(hour: 0, minute: 0, calendar: cal))
        _penaltyIntervalMinutesText = State(initialValue: "30")
        _penaltyPointsText = State(initialValue: "5")

        if let rule = editingHabit?.timeTiersRule {
            _rewardEnabled = State(initialValue: rule.rewardEnabled)
            _rewardCutoffTime = State(initialValue: Self.makeTimeDate(fromMinutes: rule.rewardCutoffMinutes, calendar: cal))
            _rewardIntervalMinutesText = State(initialValue: String(rule.rewardIntervalMinutes))
            _rewardPointsText = State(initialValue: String(rule.rewardPoints))
            
            _penaltyEnabled = State(initialValue: rule.penaltyEnabled)
            _penaltyCutoffTime = State(initialValue: Self.makeTimeDate(fromMinutes: rule.penaltyCutoffMinutes, calendar: cal))
            _penaltyIntervalMinutesText = State(initialValue: String(rule.penaltyIntervalMinutes))
            _penaltyPointsText = State(initialValue: String(rule.penaltyPoints))
        }

        _isIconPickerPresented = State(initialValue: false)
    }

    private var availableIconCandidates: [String] {
        iconCandidates.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            VStack(alignment: .leading, spacing: 8) {
                Text("基本信息")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 55/255, green: 65/255, blue: 81/255))

                VStack(alignment: .leading, spacing: 10) {
                    nameWithIconField

                    habitKindPicker

                    if inputKind == .simple {
                        inputField(title: "分数（可输入负数）", text: $scoreText)
                            .help("例如：好习惯填 10，坏习惯填 -10")
                    } else {
                        timeTiersFields
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("取消")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.slate700)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(red: 241/255, green: 245/255, blue: 249/255))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    save()
                } label: {
                    Text(editingHabit == nil ? "添加事项" : "保存设置")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(canSave ? AppColors.brandGreen : AppColors.brandGreen.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.88)
            }
        }
        .padding(24)
        .background(Color.white)
        .sheet(isPresented: $isIconPickerPresented) {
            IconGridPickerSheet(
                selection: $iconNameText,
                iconCandidates: availableIconCandidates,
                colorHex: $iconColorHex,
                paletteHex: iconColorPaletteHex
            )
            .frame(width: 520, height: 520)
        }
    }

    private var header: some View {
        HStack {
            Text(editingHabit == nil ? "添加事项" : "编辑习惯设置")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.slate900)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.slate700)
                    .frame(width: 32, height: 32)
                    .background(Color(red: 241/255, green: 245/255, blue: 249/255))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func inputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.slate500)

            TextField("", text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var nameWithIconField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("事项名称（最多20字）")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.slate500)

            HStack(spacing: 10) {
                Button {
                    isIconPickerPresented = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.bg)
                            .frame(width: 40, height: 40)
                        Image(systemName: iconNameText.isEmpty ? "checkmark.seal.fill" : iconNameText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColors.color(hex: iconColorHex) ?? AppColors.slate900)
                    }
                }
                .buttonStyle(.plain)

                TextField("", text: $name)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var habitKindPicker: some View {
        HStack(spacing: 10) {
            kindButton(kind: .simple, systemImage: "checkmark.circle.fill", title: "简单勾选")
            kindButton(kind: .timeTiers, systemImage: "clock.fill", title: "时间分段")
        }
    }

    private func kindButton(kind: HabitInputKind, systemImage: String, title: String) -> some View {
        Button {
            inputKind = kind
        } label: {
            let selected = inputKind == kind
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(selected ? AppColors.brandGreen : AppColors.slate700)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(selected ? AppColors.brandGreen.opacity(0.10) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? AppColors.brandGreen : AppColors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var timeTiersFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("时间分段（仅时间）")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.slate500)

            rewardRow
            penaltyRow
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var rewardRow: some View {
        HStack(spacing: 10) {
            Text("奖励")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.slate900)
                .frame(width: 34, alignment: .leading)

            Toggle("", isOn: $rewardEnabled)
                .labelsHidden()
                .toggleStyle(.switch)

            systemTimeField(selection: $rewardCutoffTime, width: 116)
                .opacity(rewardEnabled ? 1 : 0.4)
                .disabled(!rewardEnabled)

            systemNumberField(label: "每隔", text: $rewardIntervalMinutesText, suffix: "分钟", width: 132)
                .opacity(rewardEnabled ? 1 : 0.4)
                .disabled(!rewardEnabled)

            systemNumberField(label: "+", text: $rewardPointsText, suffix: "分", width: 110)
                .opacity(rewardEnabled ? 1 : 0.4)
                .disabled(!rewardEnabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
    }

    private var penaltyRow: some View {
        HStack(spacing: 10) {
            Text("惩罚")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.slate900)
                .frame(width: 34, alignment: .leading)

            Toggle("", isOn: $penaltyEnabled)
                .labelsHidden()
                .toggleStyle(.switch)

            systemTimeField(selection: $penaltyCutoffTime, width: 116)
                .opacity(penaltyEnabled ? 1 : 0.4)
                .disabled(!penaltyEnabled)

            systemNumberField(label: "每隔", text: $penaltyIntervalMinutesText, suffix: "分钟", width: 132)
                .opacity(penaltyEnabled ? 1 : 0.4)
                .disabled(!penaltyEnabled)

            systemNumberField(label: "-", text: $penaltyPointsText, suffix: "分", width: 110)
                .opacity(penaltyEnabled ? 1 : 0.4)
                .disabled(!penaltyEnabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
    }

    private func systemTimeField(selection: Binding<Date>, width: CGFloat) -> some View {
        DatePicker("", selection: selection, displayedComponents: [.hourAndMinute])
            .labelsHidden()
            .datePickerStyle(.stepperField)
            .controlSize(.small)
            .frame(width: width)
    }

    private func systemNumberField(label: String, text: Binding<String>, suffix: String, width: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.slate500)
                .fixedSize()

            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)

            Text(suffix)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.slate500)
                .fixedSize()
        }
        .frame(width: width, height: 40, alignment: .leading)
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        if inputKind == .simple {
            return Int(scoreText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        } else {
            if !rewardEnabled && !penaltyEnabled { return false }
            if rewardEnabled {
                guard
                    let _ = minutes(from: rewardCutoffTime),
                    Int(rewardIntervalMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil,
                    Int(rewardPointsText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
                else { return false }
            }
            if penaltyEnabled {
                guard
                    let _ = minutes(from: penaltyCutoffTime),
                    Int(penaltyIntervalMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil,
                    Int(penaltyPointsText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
                else { return false }
            }
            return true
        }
    }

    private func save() {
        let trimmedIcon = iconNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let iconName: String? = trimmedIcon.isEmpty ? nil : trimmedIcon
        let trimmedColor = iconColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let iconColorHexValue: String? = trimmedColor.isEmpty ? nil : trimmedColor

        if inputKind == .simple {
            guard let score = Int(scoreText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }

            if let editingHabit {
                appStore.updateHabit(editingHabit, name: name, score: score, iconName: iconName, iconColorHex: iconColorHexValue, timeTiersRule: nil)
            } else {
                appStore.createHabit(name: name, score: score, iconName: iconName, iconColorHex: iconColorHexValue, timeTiersRule: nil)
            }
            dismiss()
            return
        }

        if !rewardEnabled && !penaltyEnabled { return }

        let rewardCutoffMinutes = minutes(from: rewardCutoffTime) ?? 0
        let penaltyCutoffMinutes = minutes(from: penaltyCutoffTime) ?? 0

        let rewardIntervalMinutes = Int(rewardIntervalMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
        let penaltyIntervalMinutes = Int(penaltyIntervalMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1

        let rewardPoints = Int(rewardPointsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let penaltyPoints = Int(penaltyPointsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let rule = TimeTiersRule(
            rewardEnabled: rewardEnabled,
            rewardCutoffMinutes: rewardCutoffMinutes,
            rewardIntervalMinutes: max(1, rewardIntervalMinutes),
            rewardPoints: rewardPoints,
            penaltyEnabled: penaltyEnabled,
            penaltyCutoffMinutes: penaltyCutoffMinutes,
            penaltyIntervalMinutes: max(1, penaltyIntervalMinutes),
            penaltyPoints: max(0, penaltyPoints),
            overnightEnabled: true,
            overnightSplitMinutes: 12 * 60
        )

        // UI 展示用 score：优先用奖励分，否则给一个负值表示惩罚。
        let baseScore: Int = rewardEnabled ? rewardPoints : -penaltyPoints

        if let editingHabit {
            appStore.updateHabit(
                editingHabit,
                name: name,
                score: baseScore,
                iconName: iconName,
                iconColorHex: iconColorHexValue,
                timeTiersRule: rule
            )
        } else {
            appStore.createHabit(
                name: name,
                score: baseScore,
                iconName: iconName,
                iconColorHex: iconColorHexValue,
                timeTiersRule: rule
            )
        }
        dismiss()
    }

    private func minutes(from date: Date) -> Int? {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let h = comps.hour, let m = comps.minute else { return nil }
        return h * 60 + m
    }

    private static func makeTimeDate(hour: Int, minute: Int, calendar: Calendar) -> Date {
        let comps = DateComponents(calendar: calendar, year: 2000, month: 1, day: 1, hour: hour, minute: minute)
        return calendar.date(from: comps) ?? Date()
    }

    private static func makeTimeDate(fromMinutes minutes: Int, calendar: Calendar) -> Date {
        let h = max(0, min(23, minutes / 60))
        let m = max(0, min(59, minutes % 60))
        return makeTimeDate(hour: h, minute: m, calendar: calendar)
    }
}

private struct IconGridPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: String
    let iconCandidates: [String]
    @Binding var colorHex: String
    let paletteHex: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("选择 SF Symbols")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.slate900)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.slate700)
                        .frame(width: 32, height: 32)
                        .background(Color(red: 241/255, green: 245/255, blue: 249/255))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Text("颜色")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.slate500)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(paletteHex, id: \.self) { hex in
                        Button {
                            colorHex = hex
                        } label: {
                            let isSelected = colorHex.uppercased() == hex.uppercased()
                            Circle()
                                .fill(AppColors.color(hex: hex) ?? AppColors.slate500)
                                .frame(width: 18, height: 18)
                                .padding(2)
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? AppColors.slate900 : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 44), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(iconCandidates, id: \.self) { icon in
                        Button {
                            selection = icon
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(selection == icon ? (AppColors.color(hex: colorHex) ?? AppColors.brandGreen) : AppColors.slate700)
                                    .frame(width: 36, height: 36)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(selection == icon ? (AppColors.color(hex: colorHex) ?? AppColors.brandGreen).opacity(0.12) : Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selection == icon ? (AppColors.color(hex: colorHex) ?? AppColors.brandGreen) : AppColors.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(18)
        .background(Color.white)
    }
}

