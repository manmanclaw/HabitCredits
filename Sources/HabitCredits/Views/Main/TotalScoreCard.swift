import SwiftUI

struct TotalScoreCard: View {
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("累计总积分")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.slate500)
                Spacer()
                Image(systemName: "star.fill")
                    .foregroundStyle(AppColors.amber600)
            }
            Text(appStore.totalNetScore().formatted())
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.slate900)
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

