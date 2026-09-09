import Foundation
import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: Profile = Profile()
    @Published var isLoading: Bool = false
    @Published var isUploadingResume: Bool = false
    @Published var statusMessage: String?
    @Published var isErrorMessage: Bool = false

    // Form fields
    @Published var fullName: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var linkedinURL: String = ""
    @Published var githubURL: String = ""
    @Published var resumeFileName: String = ""
    @Published var customAnswers: [String: String] = [:]

    init() {
        Task {
            await loadProfile()
        }
    }

    func loadProfile() async {
        isLoading = true
        do {
            if let existing = try await SupabaseService.shared.fetchLatestProfile() {
                self.profile = existing
                self.fullName = existing.fullName ?? ""
                self.email = existing.email ?? ""
                self.phone = existing.phone ?? ""
                self.linkedinURL = existing.linkedinURL ?? ""
                self.githubURL = existing.githubURL ?? ""
                self.resumeFileName = existing.resumePath?.components(separatedBy: "/").last ?? ""
                self.customAnswers = existing.answersJSON ?? [:]
            }
        } catch {
            showStatus("Note: Initial profile load (empty or needs RLS policy).", isError: false)
        }
        isLoading = false
    }

    func handleResumeFilePicked(url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            showStatus("Failed to access selected file.", isError: true)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            isUploadingResume = true
            showStatus("Uploading resume to Supabase...", isError: false)

            let remotePath = try await SupabaseService.shared.uploadResume(
                fileData: data,
                fileName: url.lastPathComponent
            )

            profile.resumePath = remotePath
            resumeFileName = url.lastPathComponent
            showStatus("Resume uploaded successfully!", isError: false)

            // Auto save profile with new resume path
            await saveProfile()
        } catch {
            showStatus("Upload failed: \(error.localizedDescription)", isError: true)
        }
        isUploadingResume = false
    }

    func saveProfile() async {
        isLoading = true
        profile.fullName = fullName.isEmpty ? nil : fullName
        profile.email = email.isEmpty ? nil : email
        profile.phone = phone.isEmpty ? nil : phone
        profile.linkedinURL = linkedinURL.isEmpty ? nil : linkedinURL
        profile.githubURL = githubURL.isEmpty ? nil : githubURL
        profile.answersJSON = customAnswers.isEmpty ? nil : customAnswers
        profile.updatedAt = Date()

        do {
            try await SupabaseService.shared.saveProfile(profile)
            showStatus("Profile saved to Supabase!", isError: false)
        } catch {
            showStatus("Save error: \(error.localizedDescription)", isError: true)
        }
        isLoading = false
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusMessage = message
        isErrorMessage = isError
    }
}
