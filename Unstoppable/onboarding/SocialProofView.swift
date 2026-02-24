import SwiftUI

struct SocialProofView: View {
    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 3, total: 6)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 8) {
                Text("5M+ people")
                    .font(.title.bold())
                    .foregroundStyle(.orange)
                Text("stopped making excuses")
                    .font(.title.bold())
                Text("5AM Club \u{2022} Atomic Habits \u{2022} Deep Work \u{2022} Life Change")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.bottom, 32)

            // Testimonial card
            VStack(spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.callout)
                            .foregroundStyle(.yellow)
                    }
                }

                Text("\u{201C}This is probably the best routine planner app I\u{2019}ve seen! Really helps me stay motivated and achieve healthy habits every single day. Thank you Unstoppable Me! \u{1F49C}\u{201D}")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("\u{2014} Matty&Mu")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .padding(.horizontal, 32)

            Spacer()

            // Backed by section
            VStack(spacing: 14) {
                Text("Backed by research")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Studies show structured morning routines increase productivity by 40%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 32) {
                    Text("Harvard Business Review")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.5))

                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(.systemGray4))
                        .frame(width: 1, height: 24)

                    Text("MIT Sloan")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
            .padding(.bottom, 24)

            NavigationLink {
                NicknameView()
            } label: {
                Text("Next")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityHint("Proceeds to goal selection.")
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGray6).opacity(0.5))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                OnboardingBackButton(color: .primary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SocialProofView()
    }
}
