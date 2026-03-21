import SwiftUI

struct PageLayout<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical) {
            pageStack
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.bg)
    }

    private var pageStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

