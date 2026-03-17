// EditProfileSheet.swift
// SimFolio - Profile Editing
//
// This sheet allows users to edit their profile information including
// name, school, and class year.
//
// Features:
// - First/Last name fields with validation
// - School picker with search and custom input
// - Class year input with number keyboard
// - Discard changes confirmation
//
// Contents:
// - EditProfileSheet: Main edit profile view
// - ProfileTextField: Styled text field with icon
// - SchoolPickerSheet: Searchable school selector

import SwiftUI

// MARK: - EditProfileSheet

struct EditProfileSheet: View {
    @Binding var isPresented: Bool

    // MARK: - Form State
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var school: String = ""
    @State private var classYear: String = ""

    // MARK: - UI State
    @State private var showDiscardAlert: Bool = false
    @State private var showSchoolPicker: Bool = false

    // MARK: - Predefined Schools
    let dentalSchools: [String] = [
        "Harvard School of Dental Medicine",
        "University of Michigan School of Dentistry",
        "UCLA School of Dentistry",
        "University of Pennsylvania School of Dental Medicine",
        "Columbia University College of Dental Medicine",
        "New York University College of Dentistry",
        "University of Southern California Herman Ostrow School of Dentistry",
        "University of North Carolina Adams School of Dentistry",
        "University of Washington School of Dentistry",
        "University of Florida College of Dentistry",
        "Ohio State University College of Dentistry",
        "University of Texas Health Science Center at San Antonio School of Dentistry",
        "Tufts University School of Dental Medicine",
        "Boston University Henry M. Goldman School of Dental Medicine",
        "University of Illinois at Chicago College of Dentistry",
        "Other"
    ]

    // MARK: - Computed Properties

    var fullName: String {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        return [first, last].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var userInitials: String {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        var initials = ""
        if let firstChar = first.first {
            initials += String(firstChar).uppercased()
        }
        if let lastChar = last.first {
            initials += String(lastChar).uppercased()
        }

        if initials.isEmpty {
            return "DS"
        }
        return initials
    }

    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasChanges: Bool {
        let savedName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let savedSchool = UserDefaults.standard.string(forKey: "userSchool") ?? ""
        let savedClassYear = UserDefaults.standard.string(forKey: "userClassYear") ?? ""

        // Parse saved name into first/last
        let savedComponents = savedName.split(separator: " ", maxSplits: 1)
        let savedFirst = savedComponents.first.map(String.init) ?? ""
        let savedLast = savedComponents.count > 1 ? String(savedComponents[1]) : ""

        return firstName != savedFirst ||
               lastName != savedLast ||
               school != savedSchool ||
               classYear != savedClassYear
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    // Avatar section (initials only)
                    avatarSection

                    // Name fields
                    nameSection

                    // School section
                    schoolSection

                    // Class year section
                    classYearSection

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.lg)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .alert("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    isPresented = false
                }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .sheet(isPresented: $showSchoolPicker) {
                SchoolPickerSheet(
                    schools: dentalSchools,
                    selectedSchool: $school,
                    isPresented: $showSchoolPicker
                )
            }
            .onAppear {
                loadProfile()
            }
        }
    }

    // MARK: - Avatar Section

    var avatarSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Avatar with initials (no photo support)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Text(userInitials)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)

            Text("Your initials are shown above")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
    }

    // MARK: - Name Section

    var nameSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("NAME")
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: 0) {
                // First name
                ProfileTextField(
                    label: "First Name",
                    text: $firstName,
                    placeholder: "Enter your first name",
                    icon: "person"
                )

                Divider()
                    .padding(.leading, 56)

                // Last name
                ProfileTextField(
                    label: "Last Name",
                    text: $lastName,
                    placeholder: "Enter your last name (optional)",
                    icon: "person"
                )
            }
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - School Section

    var schoolSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("SCHOOL")
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            Button(action: { showSchoolPicker = true }) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: "building.columns")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dental School")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        Text(school.isEmpty ? "Select your school" : school)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(school.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Class Year Section

    var classYearSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("CLASS YEAR")
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: 0) {
                ProfileTextField(
                    label: "Graduation Year",
                    text: $classYear,
                    placeholder: "e.g., 2026",
                    icon: "graduationcap",
                    keyboardType: .numberPad
                )
            }
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal, AppTheme.Spacing.md)

            Text("Your expected graduation year")
                .font(AppTheme.Typography.caption2)
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Actions

    func loadProfile() {
        let savedName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let components = savedName.split(separator: " ", maxSplits: 1)
        firstName = components.first.map(String.init) ?? ""
        lastName = components.count > 1 ? String(components[1]) : ""

        school = UserDefaults.standard.string(forKey: "userSchool") ?? ""
        classYear = UserDefaults.standard.string(forKey: "userClassYear") ?? ""
    }

    func saveProfile() {
        UserDefaults.standard.set(fullName, forKey: "userName")
        UserDefaults.standard.set(school, forKey: "userSchool")
        UserDefaults.standard.set(classYear, forKey: "userClassYear")

        // Clean up any existing profile image data (feature removed)
        UserDefaults.standard.removeObject(forKey: "userProfileImage")

        // Ensure created date exists
        if UserDefaults.standard.object(forKey: "userCreatedDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "userCreatedDate")
        }

        isPresented = false
    }

    func handleCancel() {
        if hasChanges {
            showDiscardAlert = true
        } else {
            isPresented = false
        }
    }

}

// MARK: - ProfileTextField

/// Styled text field with icon, label, and clear button
struct ProfileTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var icon: String = "pencil"
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.primary.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.Colors.primary)
            }

            // Text field
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                TextField(placeholder, text: $text)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .keyboardType(keyboardType)
                    .focused($isFocused)
            }

            Spacer()

            // Clear button
            if !text.isEmpty && isFocused {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(isFocused ? AppTheme.Colors.primary.opacity(0.03) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - SchoolPickerSheet

/// Searchable school selector with custom input option
struct SchoolPickerSheet: View {
    let schools: [String]
    @Binding var selectedSchool: String
    @Binding var isPresented: Bool

    @State private var searchText: String = ""
    @State private var customSchool: String = ""
    @State private var showCustomInput: Bool = false

    var filteredSchools: [String] {
        if searchText.isEmpty {
            return schools
        }
        return schools.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.Colors.textTertiary)

                    TextField("Search schools...", text: $searchText)
                        .font(AppTheme.Typography.subheadline)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                    }
                }
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.surfaceSecondary)
                .cornerRadius(AppTheme.CornerRadius.small)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)

                // School list
                List {
                    ForEach(filteredSchools, id: \.self) { school in
                        Button(action: {
                            if school == "Other" {
                                showCustomInput = true
                            } else {
                                selectSchool(school)
                            }
                        }) {
                            HStack {
                                Text(school)
                                    .font(AppTheme.Typography.subheadline)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                Spacer()

                                if selectedSchool == school {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(PlainListStyle())
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Select School")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Enter School Name", isPresented: $showCustomInput) {
                TextField("School name", text: $customSchool)
                Button("Cancel", role: .cancel) {
                    customSchool = ""
                }
                Button("Done") {
                    if !customSchool.isEmpty {
                        selectSchool(customSchool)
                    }
                }
            } message: {
                Text("Enter the name of your dental school")
            }
        }
    }

    func selectSchool(_ school: String) {
        selectedSchool = school
        isPresented = false
    }
}

// MARK: - Preview Provider

#if DEBUG
struct EditProfileSheet_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileSheet(isPresented: .constant(true))
    }
}

struct ProfileTextField_Previews: PreviewProvider {
    @State static var text = "John"

    static var previews: some View {
        VStack(spacing: 0) {
            ProfileTextField(
                label: "First Name",
                text: $text,
                placeholder: "Enter your first name",
                icon: "person"
            )

            Divider()
                .padding(.leading, 56)

            ProfileTextField(
                label: "Last Name",
                text: .constant(""),
                placeholder: "Enter your last name",
                icon: "person"
            )
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .padding()
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}

struct SchoolPickerSheet_Previews: PreviewProvider {
    static var previews: some View {
        SchoolPickerSheet(
            schools: [
                "Harvard School of Dental Medicine",
                "UCLA School of Dentistry",
                "Other"
            ],
            selectedSchool: .constant(""),
            isPresented: .constant(true)
        )
    }
}
#endif
