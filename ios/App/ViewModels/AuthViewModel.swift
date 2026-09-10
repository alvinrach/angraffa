import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var otpCode: String = ""
    @Published var isCodeSent: Bool = false
    @Published var isLoading: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    init() {
        Task {
            await checkExistingSession()
        }
    }

    func checkExistingSession() async {
        if let user = await SupabaseService.shared.getCurrentUser() {
            self.isAuthenticated = true
            self.email = user.email ?? ""
        } else {
            self.isAuthenticated = false
        }
    }

    func sendOTP() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty && trimmedEmail.contains("@") else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = nil

        do {
            try await SupabaseService.shared.sendOTP(email: trimmedEmail)
            isCodeSent = true
            statusMessage = "An 8-digit verification code was sent to \(trimmedEmail)."
        } catch {
            errorMessage = "Failed to send code: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func verifyOTP() async {
        let trimmedCode = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            errorMessage = "Please enter the verification code."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await SupabaseService.shared.verifyOTP(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), token: trimmedCode)
            isAuthenticated = true
            statusMessage = "Successfully logged in!"
        } catch {
            errorMessage = "Invalid or expired code: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func signOut() async {
        isLoading = true
        try? await SupabaseService.shared.signOut()
        isAuthenticated = false
        isCodeSent = false
        otpCode = ""
        isLoading = false
    }
}
