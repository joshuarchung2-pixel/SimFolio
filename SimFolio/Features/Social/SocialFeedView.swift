import SwiftUI
import FirebaseFirestore

struct SocialFeedView: View {
    @ObservedObject private var authService = AuthenticationService.shared
    @ObservedObject private var profileService = UserProfileService.shared
    @ObservedObject private var sharingService = PhotoSharingService.shared
    @ObservedObject private var moderationService = ModerationService.shared

    @State private var posts: [SharedPost] = []
    @State private var isLoading = false
    @State private var lastDocument: DocumentSnapshot?
    @State private var hasMorePosts = true
    @State private var selectedFilter: String? = nil
    @State private var showSignIn = false
    @State private var showSocialOnboarding = false
    @State private var selectedPost: SharedPost?
    @State private var showNewPostsBanner = false
    @State private var lastLoadedTimestamp: Date?

    private let procedureFilters = ["Class 1", "Class 2", "Class 3", "Crown"]

    var body: some View {
        Group {
            if authService.authState == .signedOut {
                signedOutView
            } else if profileService.userProfile?.socialOptIn != true {
                optInPromptView
            } else {
                feedContentView
            }
        }
        .navigationTitle("Class Feed")
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showSocialOnboarding) {
            SocialOnboardingSheet()
        }
        .sheet(item: $selectedPost) { post in
            NavigationView {
                PostDetailView(post: post)
            }
        }
    }

    // MARK: - Signed Out View

    private var signedOutView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.primary.opacity(0.6))
            Text("Sign in to see your class feed")
                .font(AppTheme.Typography.title2)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("Share simulation photos and connect with classmates")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            DPButton(title: "Sign In", style: .primary, size: .large) {
                showSignIn = true
            }
            .frame(width: 200)
            Spacer()
        }
        .padding(AppTheme.Spacing.lg)
    }

    // MARK: - Opt-in Prompt

    private var optInPromptView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.primary.opacity(0.6))
            Text("Join the Class Feed")
                .font(AppTheme.Typography.title2)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("Share your simulation work and see what your classmates are working on")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            DPButton(title: "Get Started", style: .primary, size: .large) {
                showSocialOnboarding = true
            }
            .frame(width: 200)
            Spacer()
        }
        .padding(AppTheme.Spacing.lg)
    }

    // MARK: - Feed Content

    private var feedContentView: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // New posts banner
                if showNewPostsBanner {
                    Button {
                        Task { await loadFeed(refresh: true) }
                        showNewPostsBanner = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up")
                            Text("New posts available")
                        }
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(AppTheme.CornerRadius.full)
                    }
                    .padding(.top, AppTheme.Spacing.sm)
                }

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        filterChip("All", isSelected: selectedFilter == nil) {
                            selectedFilter = nil
                            Task { await loadFeed(refresh: true) }
                        }
                        ForEach(procedureFilters, id: \.self) { procedure in
                            filterChip(procedure, isSelected: selectedFilter == procedure) {
                                selectedFilter = procedure
                                Task { await loadFeed(refresh: true) }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }

                // Posts
                if isLoading && posts.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in
                        skeletonCard
                    }
                } else if posts.isEmpty {
                    emptyFeedView
                } else {
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        ForEach(filteredPosts) { post in
                            FeedPostCard(post: post) {
                                selectedPost = post
                            }
                            .onAppear {
                                if post.id == filteredPosts.last?.id && hasMorePosts {
                                    Task { await loadMorePosts() }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
        }
        .refreshable {
            await loadFeed(refresh: true)
        }
        .task {
            if posts.isEmpty { await loadFeed(refresh: true) }
        }
        .task {
            await checkForNewPosts()
        }
        .trackScreen("Social Feed")
    }

    private var filteredPosts: [SharedPost] {
        posts.filter { !moderationService.isUserBlocked($0.userId) }
    }

    // MARK: - Helpers

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surfaceSecondary)
                .cornerRadius(AppTheme.CornerRadius.full)
        }
    }

    private var emptyFeedView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textTertiary)
            Text("No posts yet")
                .font(AppTheme.Typography.title3)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("Be the first to share your simulation work!")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.top, 100)
    }

    private var skeletonCard: some View {
        DPCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Circle().fill(AppTheme.Colors.surfaceSecondary).frame(width: 36, height: 36)
                    VStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(AppTheme.Colors.surfaceSecondary).frame(width: 120, height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(AppTheme.Colors.surfaceSecondary).frame(width: 60, height: 10)
                    }
                    Spacer()
                }
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(AppTheme.Colors.surfaceSecondary)
                    .frame(height: 200)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Data Loading

    private func loadFeed(refresh: Bool) async {
        if refresh {
            lastDocument = nil
            hasMorePosts = true
        }

        isLoading = true
        defer { isLoading = false }

        guard let school = profileService.userProfile?.school else { return }

        do {
            let (newPosts, lastDoc) = try await sharingService.getSchoolFeed(
                school: school,
                limit: 20,
                afterDocument: nil
            )
            posts = newPosts
            lastDocument = lastDoc
            hasMorePosts = newPosts.count == 20
            lastLoadedTimestamp = newPosts.first?.createdAt

            AnalyticsService.logEvent(.feedViewed)
        } catch {
            // Handle error silently for now
        }
    }

    private func loadMorePosts() async {
        guard hasMorePosts, !isLoading else { return }
        guard let school = profileService.userProfile?.school else { return }

        do {
            let (newPosts, lastDoc) = try await sharingService.getSchoolFeed(
                school: school,
                limit: 20,
                afterDocument: lastDocument
            )
            posts.append(contentsOf: newPosts)
            lastDocument = lastDoc
            hasMorePosts = newPosts.count == 20
        } catch {
            // Handle error silently
        }
    }

    private func checkForNewPosts() async {
        guard let school = profileService.userProfile?.school,
              let lastTimestamp = lastLoadedTimestamp else { return }

        // Poll every 30 seconds
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)

            if let latestTimestamp = try? await sharingService.getLatestPostTimestamp(school: school) {
                if latestTimestamp > lastTimestamp {
                    showNewPostsBanner = true
                }
            }
        }
    }
}

// MARK: - Temporary Stubs
// Remove when real implementations exist (Tasks 12 and 17)

struct PostDetailView: View {
    let post: SharedPost
    var body: some View { Text("Post Detail") }
}

struct SocialOnboardingSheet: View {
    var body: some View { Text("Social Onboarding") }
}
