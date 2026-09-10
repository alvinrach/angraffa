import Foundation
import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var isLoading: Bool = false
    @Published var isUploadingResume: Bool = false
    @Published var statusMessage: String?
    @Published var isErrorMessage: Bool = false

    // Form fields
    @Published var email: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var phoneCountryCode: String = "+62"
    @Published var phoneNumber: String = ""
    @Published var city: String = ""
    @Published var country: String = ""
    @Published var linkedinURL: String = ""
    @Published var githubURL: String = ""
    @Published var portfolioURL: String = ""
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
            if let existing = try await SupabaseService.shared.fetchCurrentProfile() {
                self.profile = existing
                self.email = existing.email
                self.firstName = existing.firstName ?? ""
                self.lastName = existing.lastName ?? ""
                self.phoneCountryCode = existing.phoneCountryCode ?? "+62"
                self.phoneNumber = existing.phoneNumber ?? ""
                self.city = existing.city ?? ""
                self.country = existing.country ?? ""
                self.linkedinURL = existing.linkedinURL ?? ""
                self.githubURL = existing.githubURL ?? ""
                self.portfolioURL = existing.portfolioURL ?? ""
                self.resumeFileName = existing.resumeFilename ?? (existing.resumePath?.components(separatedBy: "/").last ?? "")
                self.customAnswers = existing.answersJSON ?? [:]
            }
        } catch {
            showStatus("Failed to load profile: \(error.localizedDescription)", isError: true)
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

            if var current = profile {
                current.resumePath = remotePath
                current.resumeFilename = url.lastPathComponent
                self.profile = current
            }
            self.resumeFileName = url.lastPathComponent
            showStatus("Resume uploaded successfully!", isError: false)

            await saveProfile()
        } catch {
            showStatus("Upload failed: \(error.localizedDescription)", isError: true)
        }
        isUploadingResume = false
    }

    func saveProfile() async {
        guard var current = profile else { return }
        isLoading = true

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let computedFullName = [trimmedFirst, trimmedLast].filter { !$0.isEmpty }.joined(separator: " ")

        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let computedLocation = [trimmedCity, trimmedCountry].filter { !$0.isEmpty }.joined(separator: ", ")

        current.firstName = trimmedFirst.isEmpty ? nil : trimmedFirst
        current.lastName = trimmedLast.isEmpty ? nil : trimmedLast
        current.fullName = computedFullName.isEmpty ? nil : computedFullName
        current.phoneCountryCode = phoneCountryCode.isEmpty ? "+62" : phoneCountryCode
        current.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        current.city = trimmedCity.isEmpty ? nil : trimmedCity
        current.country = trimmedCountry.isEmpty ? nil : trimmedCountry
        current.location = computedLocation.isEmpty ? nil : computedLocation
        current.linkedinURL = linkedinURL.isEmpty ? nil : linkedinURL
        current.githubURL = githubURL.isEmpty ? nil : githubURL
        current.portfolioURL = portfolioURL.isEmpty ? nil : portfolioURL
        current.answersJSON = customAnswers.isEmpty ? nil : customAnswers
        current.updatedAt = Date()

        do {
            try await SupabaseService.shared.saveProfile(current)
            self.profile = current
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
