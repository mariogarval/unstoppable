import SwiftUI

public struct OnboardingTheme {
    public struct ProgressColors {
        public let tint: Color
        public let track: Color
        public let label: Color
        
        public init(tint: Color, track: Color, label: Color) {
            self.tint = tint
            self.track = track
            self.label = label
        }
    }
    
    public static let dark = ProgressColors(
        tint: .yellow,
        track: Color.white.opacity(0.2),
        label: .white.opacity(0.6)
    )
    
    public static let light = ProgressColors(
        tint: .yellow,
        track: Color(.systemGray4),
        label: .secondary
    )
}

public struct OnboardingPrimaryButton: View {
    let title: String
    let background: Color
    let foreground: Color
    let action: () -> Void
    
    public init(_ title: String, background: Color, foreground: Color = .black, action: @escaping () -> Void) {
        self.title = title
        self.background = background
        self.foreground = foreground
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 4)
                .foregroundStyle(foreground)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// Dummy OnboardingProgressBar for standalone compilation
// Replace with your actual OnboardingProgressBar implementation
public struct OnboardingProgressBar: View {
    public let step: Int
    public let total: Int
    public let tintColor: Color
    public let trackColor: Color
    public let labelColor: Color
    
    public init(step: Int, total: Int, tintColor: Color, trackColor: Color, labelColor: Color) {
        self.step = step
        self.total = total
        self.tintColor = tintColor
        self.trackColor = trackColor
        self.labelColor = labelColor
    }
    
    public var body: some View {
        // Dummy progress bar representation
        VStack {
            Text("Step \(step) of \(total)")
                .foregroundColor(labelColor)
            ProgressView(value: Double(step), total: Double(total))
                .accentColor(tintColor)
                .background(trackColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding()
    }
}

public struct ThemedProgressBar: View {
    let step: Int
    let total: Int
    let colors: OnboardingTheme.ProgressColors
    
    public init(step: Int, total: Int, colors: OnboardingTheme.ProgressColors) {
        self.step = step
        self.total = total
        self.colors = colors
    }
    
    public var body: some View {
        OnboardingProgressBar(step: step, total: total, tintColor: colors.tint, trackColor: colors.track, labelColor: colors.label)
    }
}

public extension ThemedProgressBar {
    static func dark(step: Int, total: Int) -> ThemedProgressBar {
        .init(step: step, total: total, colors: OnboardingTheme.dark)
    }
    static func light(step: Int, total: Int) -> ThemedProgressBar {
        .init(step: step, total: total, colors: OnboardingTheme.light)
    }
}
