import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SchoolPickerView: View {
    let onSelect: (DentalSchool) -> Void

    @State private var searchText = ""
    @State private var showOtherRequest = false
    @State private var otherSchoolName = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredSchools: [DentalSchool] {
        DentalSchool.search(searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.textTertiary)
                TextField("Search schools...", text: $searchText)
                    .font(AppTheme.Typography.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.sm)

            // School list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredSchools) { school in
                        Button {
                            onSelect(school)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(school.name)
                                        .font(AppTheme.Typography.body)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .lineLimit(2)
                                    Text("\(school.shortName) - \(school.state)")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                        }
                        Divider().padding(.leading, AppTheme.Spacing.md)
                    }

                    // "Other" option at bottom
                    Button {
                        showOtherRequest = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Other - Request my school")
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppTheme.Colors.primary)
                                Text("Can't find your school? Let us know")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                    }
                }
            }
        }
        .alert("Request Your School", isPresented: $showOtherRequest) {
            TextField("School name", text: $otherSchoolName)
            Button("Submit") {
                // Submit request to Firestore schoolRequests collection
                Task {
                    // Fire and forget - store in Firestore if authenticated
                    if let userId = FirebaseAuth.Auth.auth().currentUser?.uid {
                        try? await FirebaseFirestore.Firestore.firestore()
                            .collection("schoolRequests")
                            .addDocument(data: [
                                "userId": userId,
                                "schoolName": otherSchoolName,
                                "createdAt": FirebaseFirestore.FieldValue.serverTimestamp()
                            ])
                    }
                }
                onSelect(DentalSchool.otherSchool)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your dental school name and we'll add it to our list.")
        }
    }
}
