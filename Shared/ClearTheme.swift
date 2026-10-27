import SwiftUI

enum ClearTheme {
    static let teal = Color(red: 0.125, green: 0.749, blue: 0.663)
    static let tealDark = Color(red: 0.067, green: 0.537, blue: 0.478)
    static let forest = Color(red: 0.090, green: 0.247, blue: 0.227)
    static let cream = Color(red: 1.000, green: 0.976, blue: 0.929)
    static let creamDeep = Color(red: 0.973, green: 0.941, blue: 0.863)
    static let mint = Color(red: 0.800, green: 0.953, blue: 0.875)
    static let yellow = Color(red: 1.000, green: 0.831, blue: 0.353)
    static let coral = Color(red: 0.973, green: 0.424, blue: 0.333)
    static let muted = Color(red: 0.408, green: 0.494, blue: 0.471)
    /// The unwritten stretch of the bar: mental sludge waiting to be eaten.
    static let rot = Color(red: 0.478, green: 0.494, blue: 0.310)
    static let rotDeep = Color(red: 0.325, green: 0.353, blue: 0.204)
    static let rotSpeck = Color(red: 0.216, green: 0.243, blue: 0.129)
}

extension View {
    func clearstateScreen() -> some View {
        self
            .fontDesign(.rounded)
            .foregroundStyle(ClearTheme.forest)
            .background(ClearTheme.cream.ignoresSafeArea())
    }

    func clearCard(radius: CGFloat = 24) -> some View {
        self
            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(ClearTheme.creamDeep, lineWidth: 1)
            }
            .shadow(color: ClearTheme.forest.opacity(0.05), radius: 12, y: 5)
    }

    @ViewBuilder
    func clearNavigationTitle(_ title: String) -> some View {
        #if os(iOS)
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

struct ClearTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ClearTheme.tealDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
