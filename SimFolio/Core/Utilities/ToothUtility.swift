// ToothUtility.swift
// SimFolio
//
// Centralized utility for tooth number to anatomical name mapping.
// Based on Universal Numbering System used in the United States.

import Foundation

/// Utility struct providing tooth-related helper functions
struct ToothUtility {

    /// Get the anatomical name for a tooth number (Universal Numbering System)
    /// - Parameter number: Tooth number (1-32)
    /// - Returns: Anatomical name of the tooth
    static func name(for number: Int) -> String {
        switch number {
        // Upper right (1-8) - Maxillary Right
        case 1: return "Maxillary Right 3rd Molar"
        case 2: return "Maxillary Right 2nd Molar"
        case 3: return "Maxillary Right 1st Molar"
        case 4: return "Maxillary Right 2nd Premolar"
        case 5: return "Maxillary Right 1st Premolar"
        case 6: return "Maxillary Right Canine"
        case 7: return "Maxillary Right Lateral Incisor"
        case 8: return "Maxillary Right Central Incisor"
        // Upper left (9-16) - Maxillary Left
        case 9: return "Maxillary Left Central Incisor"
        case 10: return "Maxillary Left Lateral Incisor"
        case 11: return "Maxillary Left Canine"
        case 12: return "Maxillary Left 1st Premolar"
        case 13: return "Maxillary Left 2nd Premolar"
        case 14: return "Maxillary Left 1st Molar"
        case 15: return "Maxillary Left 2nd Molar"
        case 16: return "Maxillary Left 3rd Molar"
        // Lower left (17-24) - Mandibular Left
        case 17: return "Mandibular Left 3rd Molar"
        case 18: return "Mandibular Left 2nd Molar"
        case 19: return "Mandibular Left 1st Molar"
        case 20: return "Mandibular Left 2nd Premolar"
        case 21: return "Mandibular Left 1st Premolar"
        case 22: return "Mandibular Left Canine"
        case 23: return "Mandibular Left Lateral Incisor"
        case 24: return "Mandibular Left Central Incisor"
        // Lower right (25-32) - Mandibular Right
        case 25: return "Mandibular Right Central Incisor"
        case 26: return "Mandibular Right Lateral Incisor"
        case 27: return "Mandibular Right Canine"
        case 28: return "Mandibular Right 1st Premolar"
        case 29: return "Mandibular Right 2nd Premolar"
        case 30: return "Mandibular Right 1st Molar"
        case 31: return "Mandibular Right 2nd Molar"
        case 32: return "Mandibular Right 3rd Molar"
        default: return "Tooth \(number)"
        }
    }

    /// Get the abbreviated anatomical name for a tooth number
    /// - Parameter number: Tooth number (1-32)
    /// - Returns: Abbreviated name (e.g., "UR 3rd Molar" instead of "Maxillary Right 3rd Molar")
    static func abbreviatedName(for number: Int) -> String {
        let fullName = name(for: number)
        return fullName
            .replacingOccurrences(of: "Maxillary Right", with: "UR")
            .replacingOccurrences(of: "Maxillary Left", with: "UL")
            .replacingOccurrences(of: "Mandibular Left", with: "LL")
            .replacingOccurrences(of: "Mandibular Right", with: "LR")
    }

    /// Check if a tooth number is in the upper arch (maxillary)
    /// - Parameter number: Tooth number (1-32)
    /// - Returns: True if tooth is in upper arch
    static func isUpperArch(_ number: Int) -> Bool {
        return number >= 1 && number <= 16
    }

    /// Check if a tooth number is in the lower arch (mandibular)
    /// - Parameter number: Tooth number (1-32)
    /// - Returns: True if tooth is in lower arch
    static func isLowerArch(_ number: Int) -> Bool {
        return number >= 17 && number <= 32
    }

    /// Check if a tooth number is on the right side
    /// - Parameter number: Tooth number (1-32)
    /// - Returns: True if tooth is on right side
    static func isRightSide(_ number: Int) -> Bool {
        return (number >= 1 && number <= 8) || (number >= 25 && number <= 32)
    }

    /// Check if a tooth number is valid
    /// - Parameter number: Tooth number to validate
    /// - Returns: True if number is between 1 and 32
    static func isValid(_ number: Int) -> Bool {
        return number >= 1 && number <= 32
    }
}
