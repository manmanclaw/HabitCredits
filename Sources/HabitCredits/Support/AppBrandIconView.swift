import SwiftUI

/// 应用品牌图标（MVVM 下仅作纯展示组件）。
/// 引用工程内已有语义：`checkmark.seal`（习惯完成）、`star`（积分）、绿/青渐变（`AppColors`）。
struct AppBrandIconView: View {
    enum Size {
        /// 侧栏 Logo 区，约 44pt。
        case sidebar
        /// 菜单栏状态栏，约 18pt。
        case menuBar
    }

    let size: Size

    private var edge: CGFloat {
        switch size {
        case .sidebar: 44
        case .menuBar: 18
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .sidebar: 14
        case .menuBar: 5
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(brandGradient)
                .shadow(
                    color: .black.opacity(size == .sidebar ? 0.10 : 0.06),
                    radius: size == .sidebar ? 4 : 2,
                    x: 0,
                    y: size == .sidebar ? 2 : 1
                )

            switch size {
            case .sidebar:
                sidebarMark
            case .menuBar:
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: edge, height: edge)
        .accessibilityLabel("事项积分")
    }

    /// 侧栏：主图形为「完成印章」，角标为金色星星表示积分。
    private var sidebarMark: some View {
        ZStack {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)

            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(starGradient)
                .offset(x: 11, y: -10)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
        }
    }

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.brandGreen.opacity(0.96),
                AppColors.brandTeal.opacity(0.94),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var starGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1, green: 0.93, blue: 0.55),
                Color(red: 1, green: 0.72, blue: 0.15),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#if DEBUG
#Preview("品牌图标") {
    HStack(spacing: 16) {
        AppBrandIconView(size: .sidebar)
        AppBrandIconView(size: .menuBar)
    }
    .padding()
    .background(AppColors.bg)
}
#endif
