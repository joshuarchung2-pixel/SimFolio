// UserOnboardingProfile.swift
// SimFolio - User Onboarding Data Model
//
// This file contains the data model for storing user onboarding preferences.

import Foundation

/// Model for storing user onboarding profile data
struct UserOnboardingProfile: Codable {
    var displayName: String = ""
    var dentalSchoolAffiliation: String = ""
    var graduationYear: Int?
}
