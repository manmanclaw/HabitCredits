import SwiftUI

struct SidebarView: View {
    @Binding var selection: MainSection?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            nav
            Spacer(minLength: 0)
            footer
        }
        .padding(14)
        .frame(minWidth: 175, idealWidth: 175)
        .background(AppColors.bg)
    }

    private var header: some View {
        HStack(spacing: 13) {
            AppBrandIconView(size: .sidebar)

            VStack(alignment: .leading, spacing: 2) {
                Text("事项积分")
                        .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.slate900)
            }
        }
        .padding(.bottom, 22)
    }

    private var nav: some View {
        VStack(alignment: .leading, spacing: 10) {
            SidebarItem(
                title: "习惯记录",
                systemImage: "checkmark.circle.fill",
                isSelected: selection == .today
            ) {
                selection = .today
            }

            SidebarItem(
                title: "积分统计",
                systemImage: "chart.bar.xaxis",
                isSelected: selection == .stats
            ) {
                selection = .stats
            }

            SidebarItem(
                title: "习惯管理",
                systemImage: "checklist",
                isSelected: selection == .manage
            ) {
                selection = .manage
            }

            SidebarItem(
                title: "系统设置",
                systemImage: "gearshape",
                isSelected: selection == .settings
            ) {
                selection = .settings
            }
        }
    }

    private var footer: some View {
        TotalScoreCard()
            .padding(.top, 12)
    }
}

private struct SidebarItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AppColors.brandGreen : AppColors.slate500)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color(red: 6/255, green: 95/255, blue: 70/255) : AppColors.slate700)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color(red: 167/255, green: 243/255, blue: 208/255) : .clear, lineWidth: 1)
            )
            // 解决未选中态背景为全透明时，中间区域 hitTest 不生效的问题
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        Group {
            if isSelected {
                LinearGradient(
                    colors: [Color(red: 236/255, green: 253/255, blue: 245/255), Color(red: 240/255, green: 253/255, blue: 250/255)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                // 用极低不透明度占位，保证整个按钮区域可点击
                Color.white.opacity(0.001)
            }
        }
    }
}

