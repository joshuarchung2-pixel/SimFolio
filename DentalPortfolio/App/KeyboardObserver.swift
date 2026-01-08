// KeyboardObserver.swift
// Dental Portfolio - Keyboard Handling
//
// Observable object for tracking keyboard state and helpers for
// keyboard-avoiding layouts and dismissal.
//
// Contents:
// - KeyboardObserver: Observable keyboard state
// - KeyboardAvoidingModifier: Auto-adjust for keyboard
// - Keyboard dismissal helpers

import SwiftUI
import Combine

// MARK: - KeyboardObserver

/// Observable object that tracks keyboard visibility and height
class KeyboardObserver: ObservableObject {
    /// Current keyboard height (0 when hidden)
    @Published var keyboardHeight: CGFloat = 0

    /// Whether the keyboard is currently visible
    @Published var isKeyboardVisible: Bool = false

    /// Animation duration for keyboard changes
    @Published var animationDuration: Double = 0.25

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupKeyboardObservers()
    }

    private func setupKeyboardObservers() {
        // Keyboard will show
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardWillShow(notification)
            }
            .store(in: &cancellables)

        // Keyboard will hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardWillHide(notification)
            }
            .store(in: &cancellables)

        // Keyboard will change frame
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardFrameChange(notification)
            }
            .store(in: &cancellables)
    }

    private func handleKeyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }

        animationDuration = duration

        withAnimation(.easeOut(duration: duration)) {
            keyboardHeight = frame.height
            isKeyboardVisible = true
        }
    }

    private func handleKeyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }

        animationDuration = duration

        withAnimation(.easeOut(duration: duration)) {
            keyboardHeight = 0
            isKeyboardVisible = false
        }
    }

    private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        // Only update if keyboard is visible
        if isKeyboardVisible {
            withAnimation(.easeOut(duration: animationDuration)) {
                keyboardHeight = frame.height
            }
        }
    }
}

// MARK: - Keyboard Avoiding Modifier

/// ViewModifier that adjusts view padding to avoid keyboard
struct KeyboardAvoidingModifier: ViewModifier {
    @StateObject private var keyboardObserver = KeyboardObserver()
    var additionalPadding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardObserver.keyboardHeight + additionalPadding)
            .animation(.easeOut(duration: keyboardObserver.animationDuration), value: keyboardObserver.keyboardHeight)
    }
}

extension View {
    /// Add padding that responds to keyboard visibility
    /// - Parameter additionalPadding: Extra padding to add when keyboard is visible
    func keyboardAvoiding(additionalPadding: CGFloat = 0) -> some View {
        modifier(KeyboardAvoidingModifier(additionalPadding: additionalPadding))
    }
}

// MARK: - Keyboard Responsive Modifier

/// ViewModifier that provides keyboard state to content
struct KeyboardResponsiveModifier: ViewModifier {
    @StateObject private var keyboardObserver = KeyboardObserver()
    let content: (CGFloat, Bool) -> AnyView

    func body(content: Content) -> some View {
        self.content(keyboardObserver.keyboardHeight, keyboardObserver.isKeyboardVisible)
    }
}

// MARK: - Hide Keyboard Extension

extension View {
    /// Dismiss the keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Dismiss Keyboard on Tap Modifier

/// ViewModifier that dismisses keyboard when tapping outside text fields
struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
    }
}

extension View {
    /// Dismiss keyboard when tapping this view
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }
}

// MARK: - Dismiss Keyboard on Drag Modifier

/// ViewModifier that dismisses keyboard when dragging
struct DismissKeyboardOnDragModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            )
    }
}

extension View {
    /// Dismiss keyboard when dragging on this view
    func dismissKeyboardOnDrag() -> some View {
        modifier(DismissKeyboardOnDragModifier())
    }
}

// MARK: - Keyboard Toolbar Modifier

/// ViewModifier that adds a toolbar with done button above keyboard
struct KeyboardToolbarModifier: ViewModifier {
    let title: String?
    let doneAction: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if let title = title {
                        Text(title)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                        doneAction?()
                    }
                    .fontWeight(.semibold)
                }
            }
    }
}

extension View {
    /// Add a keyboard toolbar with optional title and done action
    func keyboardToolbar(title: String? = nil, onDone: (() -> Void)? = nil) -> some View {
        modifier(KeyboardToolbarModifier(title: title, doneAction: onDone))
    }
}

// MARK: - Preview Provider

#if DEBUG
struct KeyboardObserver_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardPreviewContent()
    }

    struct KeyboardPreviewContent: View {
        @State private var text = ""
        @StateObject private var keyboardObserver = KeyboardObserver()

        var body: some View {
            VStack(spacing: 20) {
                Text("Keyboard Observer Demo")
                    .font(.headline)

                Text("Height: \(Int(keyboardObserver.keyboardHeight))")
                Text("Visible: \(keyboardObserver.isKeyboardVisible ? "Yes" : "No")")

                Spacer()

                TextField("Type something...", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Spacer()
            }
            .padding()
            .keyboardAvoiding()
            .dismissKeyboardOnTap()
        }
    }
}
#endif
