// AppTourView.swift
// SimFolio - Post-Onboarding App Tour
//
// A lightweight click-through overlay that introduces users to the app's
// main tabs and features. Shown once after onboarding (and after the
// optional paywall is dismissed).

import SwiftUI

// MARK: - Tour Step Model

struct TourStep: Identifiable {
    let id: Int
    let tab: MainTab
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
}

// MARK: - AppTourView

struct AppTourView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: MainTab

    @State private var currentStep = 0

    private let steps: [TourStep] = [
        TourStep(
            id: 0,
            tab: .home,
            title: "Your Dashboard",
            description: "See your recent photos, portfolio progress, and quick stats at a glance.",
            icon: "house.fill",
            iconColor: AppTheme.Colors.primary
        ),
        TourStep(
            id: 1,
            tab: .capture,
            title: "Capture Photos",
            description: "Tag your photos before you shoot \u{2014} procedure, stage, angle, and tooth number.",
            icon: "camera.fill",
            iconColor: .orange
        ),
        TourStep(
            id: 2,
            tab: .library,
            title: "Your Photo Library",
            description: "Browse, filter, and sort all your photos. Tap any photo to view details or rate it.",
            icon: "photo.on.rectangle.fill",
            iconColor: .purple
        ),
        TourStep(
            id: 3,
            tab: .profile,
            title: "Profile & Settings",
            description: "View your stats, manage portfolios, and customize the app to your needs.",
            icon: "person.fill",
            iconColor: AppTheme.Colors.success
        ),
        TourStep(
            id: 4,
            tab: .home,
            title: "You're All Set!",
            description: "Start by capturing your first photo or creating a portfolio.",
            icon: "checkmark.circle.fill",
            iconColor: AppTheme.Colors.success
        )
    ]

    private var isLastStep: Bool {
        currentStep == steps.count - 1
    }

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { } // Block taps through

            VStack {
                Spacer()

                // Tour card
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(steps[currentStep].iconColor.opacity(0.15))
                            .frame(width: 72, height: 72)

                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 30))
                            .foregroundStyle(steps[currentStep].iconColor)
                    }

                    // Title + description
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text(steps[currentStep].title)
                            .font(AppTheme.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text(steps[currentStep].description)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Step dots
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentStep ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary.opacity(0.3))
                                .frame(width: index == currentStep ? 10 : 8, height: index == currentStep ? 10 : 8)
                                .animation(.easeInOut(duration: 0.2), value: currentStep)
                        }
                    }

                    // Buttons
                    HStack {
                        // Skip button
                        Button {
                            completeTour(skipped: true)
                        } label: {
                            Text("Skip")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.sm)
                        }

                        // Next / Get Started button
                        Button {
                            if isLastStep {
                                completeTour(skipped: false)
                            } else {
                                withAnimation {
                                    currentStep += 1
                                }
                            }
                        } label: {
                            Text(isLastStep ? "Get Started" : "Next")
                                .font(AppTheme.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.sm)
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(AppTheme.CornerRadius.small)
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.large)
                .shadowLarge()
                .padding(.horizontal, AppTheme.Spacing.lg)

                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .onChange(of: currentStep) { newStep in
            if newStep < steps.count {
                selectedTab = steps[newStep].tab
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("App tour step \(currentStep + 1) of \(steps.count)")
    }

    // MARK: - Actions

    private func completeTour(skipped: Bool) {
        UserDefaults.standard.set(true, forKey: "hasCompletedAppTour")

        if skipped {
            AnalyticsService.logEvent(.appTourSkipped, parameters: [
                "step_reached": currentStep + 1,
                "total_steps": steps.count
            ])
        } else {
            AnalyticsService.logEvent(.appTourCompleted, parameters: [
                "total_steps": steps.count
            ])
        }

        // Return to home tab
        selectedTab = .home

        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AppTourView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            AppTourView(
                isPresented: .constant(true),
                selectedTab: .constant(.home)
            )
        }
    }
}
#endif
