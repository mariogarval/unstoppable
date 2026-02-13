import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @State private var titleAppeared = false
    @State private var actionsAppeared = false

    @State private var appleAppeared = false
    @State private var googleAppeared = false
    @State private var guestAppeared = false
    @State private var isGoogleSigningIn = false
    @State private var authErrorMessage: String?
    @State private var navigateNickname = false
    @State private var navigateHome = false
    @State private var didBootstrap = false
    @State private var didHandleRestoreRouting = false
    @State private var cachedBootstrap: BootstrapResponse?

    private let syncService = UserDataSyncService.shared
    private let authSession = AuthSessionManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // System-adaptive background
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    // Headline
                    VStack(spacing: 8) {
                        Text("No more excuses.")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Text("Unstoppable")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.tint)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Unstoppable")
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Text("You know what to do. This app makes sure you actually do it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.45), value: titleAppeared)

                    Spacer()

                    // Actions
                    VStack(spacing: 10) {
                        // Sign in with Apple — official button
                        SignInWithAppleButton(.continue) { request in
                            // Configure your request scopes if needed
                            // request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            // Handle the result
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(0)
                        .controlSize(.regular)
                        .signInWithAppleButtonStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(Rectangle())
                        .opacity(appleAppeared ? 1 : 0)
                        .offset(y: appleAppeared ? 0 : 8)
                        .animation(.easeOut(duration: 0.45), value: appleAppeared)
                        .accessibilityLabel("Continue with Apple")

                        // Google — neutral, accessible border and contrast
                        Button {
                            Task {
                                await signInWithGoogle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Continue with Google")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(isGoogleSigningIn)
                        .accessibilityLabel("Continue with Google")
                        .buttonStyle(.plain)
                        .opacity(googleAppeared ? 1 : 0)
                        .offset(y: googleAppeared ? 0 : 8)
                        .animation(.easeOut(duration: 0.45).delay(0.06), value: googleAppeared)

                        // Continue without signup — prominent tint outline
                        NavigationLink {
                            NicknameView()
                        } label: {
                            Text("Skip signup. Just start.")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(.tint)
                                .background(.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(.tint, lineWidth: 1.5)
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .accessibilityLabel("Continue without signup")
                        .opacity(guestAppeared ? 1 : 0)
                        .offset(y: guestAppeared ? 0 : 8)
                        .animation(.easeOut(duration: 0.45).delay(0.12), value: guestAppeared)

                        // Sign in link — subtle, secondary emphasis
                        Button {
                            // Sign in action
                        } label: {
                            HStack(spacing: 6) {
                                Text("Been here before?")
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text("Sign In")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .font(.subheadline)
                            .frame(minHeight: 44)
                            .padding(.top, 4)
                        }
                        .buttonStyle(.plain)
                        .opacity(actionsAppeared ? 1 : 0)
                        .offset(y: actionsAppeared ? 0 : 8)
                        .animation(.easeOut(duration: 0.45).delay(0.18), value: actionsAppeared)

                        if let authErrorMessage {
                            Text(authErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.45)) {
                        titleAppeared = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        appleAppeared = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        googleAppeared = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        guestAppeared = true
                    }
                    actionsAppeared = true
                }
                .task {
                    if !didHandleRestoreRouting {
                        didHandleRestoreRouting = true
                        let restored = await authSession.restoreSessionIfPossible()
                        let bootstrap = await bootstrapIfNeeded()
                        if restored {
                            routeAuthenticatedUser(using: bootstrap)
                        }
                    } else {
                        _ = await bootstrapIfNeeded()
                    }
                }
                .dynamicTypeSize(.medium ... .accessibility5)
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $navigateNickname) {
                    NicknameView()
                }
                .navigationDestination(isPresented: $navigateHome) {
                    HomeView()
                }
            }
        }
    }

    @MainActor
    private func bootstrapIfNeeded(force: Bool = false) async -> BootstrapResponse? {
        if !force {
            guard !didBootstrap else { return cachedBootstrap }
        }
        didBootstrap = true
        do {
            let bootstrap = try await syncService.fetchBootstrap()
            cachedBootstrap = bootstrap
            return bootstrap
        } catch {
#if DEBUG
            print("bootstrap failed: \(error.localizedDescription)")
#endif
            return cachedBootstrap
        }
    }

    @MainActor
    private func signInWithGoogle() async {
        guard !isGoogleSigningIn else { return }

        isGoogleSigningIn = true
        authErrorMessage = nil
        defer { isGoogleSigningIn = false }

        do {
            try await authSession.signInWithGoogle()
            let bootstrap = await bootstrapIfNeeded(force: true)
            routeAuthenticatedUser(using: bootstrap)
        } catch {
            authErrorMessage = "Google sign-in failed. Please try again."
#if DEBUG
            print("google sign-in failed: \(error.localizedDescription)")
#endif
        }
    }

    @MainActor
    private func routeAuthenticatedUser(using bootstrap: BootstrapResponse?) {
        navigateHome = false
        navigateNickname = false

        if isOnboarded(bootstrap) {
            navigateHome = true
            return
        }

        navigateNickname = true
    }

    private func isOnboarded(_ bootstrap: BootstrapResponse?) -> Bool {
        guard let paymentOption = profileString("paymentOption", from: bootstrap) else {
            return false
        }

        return !paymentOption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func profileString(_ key: String, from bootstrap: BootstrapResponse?) -> String? {
        guard let value = bootstrap?.profile[key] else { return nil }
        if case .string(let str) = value {
            return str
        }
        return nil
    }
}

#Preview {
    WelcomeView()
}
