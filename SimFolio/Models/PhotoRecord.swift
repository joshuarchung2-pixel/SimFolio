// PhotoRecord.swift
// SimFolio - Represents an app-owned photo stored in the Documents directory

import Foundation

struct PhotoRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdDate: Date
    var fileSize: Int64
}
