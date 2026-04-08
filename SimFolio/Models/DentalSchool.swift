import Foundation

struct DentalSchool: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let shortName: String
    let state: String

    var displayName: String { "\(name) (\(shortName))" }

    static let allSchools: [DentalSchool] = [
        // Alabama
        DentalSchool(id: "uab", name: "University of Alabama at Birmingham School of Dentistry", shortName: "UAB", state: "AL"),
        // Arizona
        DentalSchool(id: "midwestern-az", name: "Midwestern University College of Dental Medicine – Arizona", shortName: "MWU-AZ", state: "AZ"),
        DentalSchool(id: "atsu", name: "A.T. Still University Arizona School of Dentistry & Oral Health", shortName: "ATSU", state: "AZ"),
        // California
        DentalSchool(id: "llu", name: "Loma Linda University School of Dentistry", shortName: "LLU", state: "CA"),
        DentalSchool(id: "ucsf", name: "University of California San Francisco School of Dentistry", shortName: "UCSF", state: "CA"),
        DentalSchool(id: "ucla", name: "UCLA School of Dentistry", shortName: "UCLA", state: "CA"),
        DentalSchool(id: "usc", name: "Herman Ostrow School of Dentistry of USC", shortName: "USC", state: "CA"),
        DentalSchool(id: "uop", name: "University of the Pacific Arthur A. Dugoni School of Dentistry", shortName: "UOP", state: "CA"),
        DentalSchool(id: "westernu", name: "Western University of Health Sciences College of Dental Medicine", shortName: "WesternU", state: "CA"),
        // Colorado
        DentalSchool(id: "cu", name: "University of Colorado School of Dental Medicine", shortName: "CU", state: "CO"),
        // Connecticut
        DentalSchool(id: "uconn", name: "UConn School of Dental Medicine", shortName: "UConn", state: "CT"),
        // District of Columbia
        DentalSchool(id: "howard", name: "Howard University College of Dentistry", shortName: "Howard", state: "DC"),
        // Florida
        DentalSchool(id: "nova", name: "Nova Southeastern University College of Dental Medicine", shortName: "Nova", state: "FL"),
        DentalSchool(id: "uf", name: "University of Florida College of Dentistry", shortName: "UF", state: "FL"),
        // Pennsylvania (LECOM has campus in FL and PA)
        DentalSchool(id: "lecom", name: "Lake Erie College of Osteopathic Medicine School of Dental Medicine", shortName: "LECOM", state: "PA"),
        // Georgia
        DentalSchool(id: "dcg", name: "Augusta University The Dental College of Georgia", shortName: "DCG", state: "GA"),
        // Illinois
        DentalSchool(id: "uic", name: "University of Illinois Chicago College of Dentistry", shortName: "UIC", state: "IL"),
        DentalSchool(id: "siu", name: "Southern Illinois University School of Dental Medicine", shortName: "SIU", state: "IL"),
        DentalSchool(id: "mwu-il", name: "Midwestern University College of Dental Medicine – Illinois", shortName: "MWU-IL", state: "IL"),
        // Indiana
        DentalSchool(id: "iu", name: "Indiana University School of Dentistry", shortName: "IU", state: "IN"),
        // Iowa
        DentalSchool(id: "iowa", name: "University of Iowa College of Dentistry", shortName: "Iowa", state: "IA"),
        // Kentucky
        DentalSchool(id: "uk", name: "University of Kentucky College of Dentistry", shortName: "UK", state: "KY"),
        DentalSchool(id: "uofl", name: "University of Louisville School of Dentistry", shortName: "UofL", state: "KY"),
        // Louisiana
        DentalSchool(id: "lsu", name: "LSU Health New Orleans School of Dentistry", shortName: "LSU", state: "LA"),
        // Maine
        DentalSchool(id: "une", name: "University of New England College of Dental Medicine", shortName: "UNE", state: "ME"),
        // Maryland
        DentalSchool(id: "umd", name: "University of Maryland School of Dentistry", shortName: "UMD", state: "MD"),
        // Massachusetts
        DentalSchool(id: "bu", name: "Boston University Henry M. Goldman School of Dental Medicine", shortName: "BU", state: "MA"),
        DentalSchool(id: "harvard", name: "Harvard School of Dental Medicine", shortName: "Harvard", state: "MA"),
        DentalSchool(id: "tufts", name: "Tufts University School of Dental Medicine", shortName: "Tufts", state: "MA"),
        // Michigan
        DentalSchool(id: "umich", name: "University of Michigan School of Dentistry", shortName: "UMich", state: "MI"),
        DentalSchool(id: "udm", name: "University of Detroit Mercy School of Dentistry", shortName: "UDM", state: "MI"),
        // Minnesota
        DentalSchool(id: "umn", name: "University of Minnesota School of Dentistry", shortName: "UMN", state: "MN"),
        // Mississippi
        DentalSchool(id: "ummc", name: "University of Mississippi Medical Center School of Dentistry", shortName: "UMMC", state: "MS"),
        // Missouri
        DentalSchool(id: "umkc", name: "University of Missouri – Kansas City School of Dentistry", shortName: "UMKC", state: "MO"),
        DentalSchool(id: "creighton", name: "Creighton University School of Dentistry", shortName: "Creighton", state: "MO"),
        // Nebraska
        DentalSchool(id: "unmc", name: "University of Nebraska Medical Center College of Dentistry", shortName: "UNMC", state: "NE"),
        // Nevada
        DentalSchool(id: "unlv", name: "UNLV School of Dental Medicine", shortName: "UNLV", state: "NV"),
        DentalSchool(id: "roseman-nv", name: "Roseman University of Health Sciences College of Dental Medicine – Nevada", shortName: "Roseman-NV", state: "NV"),
        // New Jersey
        DentalSchool(id: "rutgers", name: "Rutgers School of Dental Medicine", shortName: "Rutgers", state: "NJ"),
        // New York
        DentalSchool(id: "columbia", name: "Columbia University College of Dental Medicine", shortName: "Columbia", state: "NY"),
        DentalSchool(id: "nyu", name: "NYU College of Dentistry", shortName: "NYU", state: "NY"),
        DentalSchool(id: "stonybrook", name: "Stony Brook University School of Dental Medicine", shortName: "Stony Brook", state: "NY"),
        DentalSchool(id: "touro", name: "Touro College of Dental Medicine", shortName: "Touro", state: "NY"),
        DentalSchool(id: "ub", name: "University at Buffalo School of Dental Medicine", shortName: "UB", state: "NY"),
        // North Carolina
        DentalSchool(id: "unc", name: "UNC Adams School of Dentistry", shortName: "UNC", state: "NC"),
        DentalSchool(id: "ecu", name: "East Carolina University School of Dental Medicine", shortName: "ECU", state: "NC"),
        // Ohio
        DentalSchool(id: "cwru", name: "Case Western Reserve University School of Dental Medicine", shortName: "CWRU", state: "OH"),
        DentalSchool(id: "osu", name: "The Ohio State University College of Dentistry", shortName: "OSU", state: "OH"),
        // Oklahoma
        DentalSchool(id: "ou", name: "University of Oklahoma College of Dentistry", shortName: "OU", state: "OK"),
        // Oregon
        DentalSchool(id: "ohsu", name: "Oregon Health & Science University School of Dentistry", shortName: "OHSU", state: "OR"),
        // Pennsylvania
        DentalSchool(id: "temple", name: "Temple University Kornberg School of Dentistry", shortName: "Temple", state: "PA"),
        DentalSchool(id: "penn", name: "University of Pennsylvania School of Dental Medicine", shortName: "Penn", state: "PA"),
        DentalSchool(id: "pitt", name: "University of Pittsburgh School of Dental Medicine", shortName: "Pitt", state: "PA"),
        // South Carolina
        DentalSchool(id: "musc", name: "Medical University of South Carolina James B. Edwards College of Dental Medicine", shortName: "MUSC", state: "SC"),
        // Tennessee
        DentalSchool(id: "meharry", name: "Meharry Medical College School of Dentistry", shortName: "Meharry", state: "TN"),
        DentalSchool(id: "uthsc", name: "University of Tennessee Health Science Center College of Dentistry", shortName: "UTHSC", state: "TN"),
        // Texas
        DentalSchool(id: "tamu", name: "Texas A&M College of Dentistry", shortName: "TAMU", state: "TX"),
        DentalSchool(id: "uthsa", name: "UT Health San Antonio School of Dentistry", shortName: "UTHSA", state: "TX"),
        DentalSchool(id: "uth", name: "UTHealth Houston School of Dentistry", shortName: "UTH", state: "TX"),
        // Utah
        DentalSchool(id: "roseman-ut", name: "Roseman University of Health Sciences College of Dental Medicine – Utah", shortName: "Roseman", state: "UT"),
        // Virginia
        DentalSchool(id: "vcu", name: "Virginia Commonwealth University School of Dentistry", shortName: "VCU", state: "VA"),
        DentalSchool(id: "liberty", name: "Liberty University College of Osteopathic Medicine – Dental", shortName: "Liberty", state: "VA"),
        // Washington
        DentalSchool(id: "uw", name: "University of Washington School of Dentistry", shortName: "UW", state: "WA"),
        // West Virginia
        DentalSchool(id: "wvu", name: "West Virginia University School of Dentistry", shortName: "WVU", state: "WV"),
        // Wisconsin
        DentalSchool(id: "marquette", name: "Marquette University School of Dentistry", shortName: "Marquette", state: "WI"),
        // Puerto Rico
        DentalSchool(id: "upr", name: "University of Puerto Rico School of Dental Medicine", shortName: "UPR", state: "PR"),
    ]

    static let otherSchool = DentalSchool(
        id: "other",
        name: "Other - Request my school",
        shortName: "Other",
        state: ""
    )

    static func school(withId id: String) -> DentalSchool? {
        if id == otherSchool.id { return otherSchool }
        return allSchools.first { $0.id == id }
    }

    static func search(_ query: String) -> [DentalSchool] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return allSchools }
        let lower = trimmed.lowercased()
        return allSchools.filter {
            $0.name.lowercased().contains(lower) ||
            $0.shortName.lowercased().contains(lower) ||
            $0.state.lowercased().contains(lower)
        }
    }
}
