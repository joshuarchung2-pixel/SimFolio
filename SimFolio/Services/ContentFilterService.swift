// ContentFilterService.swift
// SimFolio
//
// Stateless text content filter for screening user-generated text.

import Foundation

enum ContentFilterService {
    /// Returns true if the text passes content filtering
    static func isTextClean(_ text: String) -> Bool {
        return filterReason(text) == nil
    }

    /// Returns the reason text was filtered, or nil if clean
    static func filterReason(_ text: String) -> String? {
        let lowered = text.lowercased()
        let words = lowered.components(separatedBy: .whitespacesAndNewlines)

        for word in words {
            // Strip common punctuation from word edges
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if blockedWords.contains(cleaned) {
                return "Your text contains inappropriate language. Please revise and try again."
            }
        }

        return nil
    }

    // Basic profanity/slur word list — check word boundaries only
    private static let blockedWords: Set<String> = [
        // Common profanity
        "fuck", "shit", "ass", "bitch", "damn", "hell",
        "bastard", "dick", "piss", "crap", "cunt",
        // Slurs (abbreviated list — extend as needed)
        "nigger", "nigga", "faggot", "fag", "retard",
        "spic", "chink", "kike", "wetback",
        // Sexual
        "porn", "hentai", "xxx",
        // Compound variations
        "motherfucker", "bullshit", "asshole", "dumbass",
        "dipshit", "jackass", "goddamn",
    ]
}
