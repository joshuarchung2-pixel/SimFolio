// HomeView.swift
// Dashboard with quick capture, portfolios, recent photos
//
// Will contain:
//
// HomeView (NEW - does not exist in current codebase):
//
// A new dashboard view inspired by Coinbase/Airbnb home screens.
// This replaces jumping directly to Camera as the default tab.
//
// Sections:
//
// 1. Header:
//    - Greeting with time of day ("Good morning")
//    - Profile avatar button (navigates to Profile)
//    - Notification bell with badge
//
// 2. Quick Capture Card:
//    - Large prominent button to start capture flow
//    - Shows last used procedure/tooth for quick repeat
//    - Animated camera icon
//
// 3. Portfolio Progress:
//    - Horizontal scroll of portfolio cards
//    - Each card shows name, progress ring, due date badge
//    - "View All" link to Portfolios tab
//    - Empty state if no portfolios
//
// 4. Recent Photos:
//    - Grid of last 6 photos taken
//    - Tap to view in Library
//    - "See All" link to Library tab
//
// 5. Quick Stats:
//    - Total photos this week
//    - Portfolios in progress
//    - Upcoming due dates
//
// State:
// - Minimal local state (data from managers)
//
// Navigation:
// - Quick capture -> CaptureFlowView
// - Portfolio card -> PortfolioDetailView
// - Photo thumbnail -> PhotoDetailView
// - Profile button -> ProfileView
//
// Design notes:
// - Clean, spacious layout with clear visual hierarchy
// - Subtle animations on scroll
// - Pull to refresh support

import SwiftUI

// Placeholder - new view to be implemented
