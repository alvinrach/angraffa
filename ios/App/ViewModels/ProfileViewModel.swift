import Foundation
import SwiftUI
import Combine

@MainActor
public class ProfileViewModel: ObservableObject {
    @Published public var profile: Profile?
    @Published public var isLoading: Bool = false
    @Published public var isUploadingResume: Bool = false
    @Published public var statusMessage: String?
    @Published public var isErrorMessage: Bool = false

    // Form fields - Personal & Contact
    @Published public var email: String = ""
    @Published public var firstName: String = ""
    @Published public var lastName: String = ""
    @Published public var phoneCountryCode: String = "+971"
    @Published public var phoneNumber: String = ""
    @Published public var city: String = ""
    @Published public var country: String = ""
    @Published public var linkedinURL: String = ""
    @Published public var githubURL: String = ""
    @Published public var portfolioURL: String = ""
    @Published public var resumeFileName: String = ""

    // Work Experience
    @Published public var experiences: [Experience] = []

    // Default Screening Answers
    @Published public var nationality: String = "Indonesian"
    @Published public var visaStatus: String = "Resident Visa"
    @Published public var noticePeriod: String = "1 month"
    @Published public var earliestStartDate: String = "Immediately"
    @Published public var currentSalary: String = "AED 25,000"
    @Published public var expectedSalary: String = "AED 30,000"
    @Published public var maritalStatus: String = "Single"
    @Published public var gender: String = "Male"
    @Published public var skillsetPitch: String = ""

    // Custom Q&A Dictionary
    @Published public var customAnswers: [String: String] = [:]

    public init() {
        Task {
            await loadProfile()
        }
    }

    public func loadProfile() async {
        isLoading = true
        do {
            if let existing = try await SupabaseService.shared.fetchCurrentProfile() {
                self.profile = existing
                self.email = existing.email
                self.firstName = existing.firstName ?? ""
                self.lastName = existing.lastName ?? ""
                self.phoneCountryCode = existing.phoneCountryCode ?? "+971"
                self.phoneNumber = existing.phoneNumber ?? ""
                self.city = existing.city ?? ""
                self.country = existing.country ?? ""
                self.linkedinURL = existing.linkedinURL ?? ""
                self.githubURL = existing.githubURL ?? ""
                self.portfolioURL = existing.portfolioURL ?? ""
                self.resumeFileName = existing.resumeFilename ?? (existing.resumePath?.components(separatedBy: "/").last ?? "")
                self.experiences = existing.experiences ?? []

                // Populate screening answers from answers_json
                let answers = existing.answersJSON ?? [:]
                self.nationality = answers["nationality"] ?? "Indonesian"
                self.visaStatus = answers["visa_status"] ?? "Resident Visa"
                self.noticePeriod = answers["notice_period"] ?? "1 month"
                self.earliestStartDate = answers["start_date"] ?? answers["earliest_start_date"] ?? "Immediately"
                self.currentSalary = answers["current_salary"] ?? "AED 25,000"
                self.expectedSalary = answers["expected_salary"] ?? "AED 30,000"
                self.maritalStatus = answers["marital_status"] ?? "Single"
                self.gender = answers["gender"] ?? "Male"
                self.skillsetPitch = answers["skillset_pitch"] ?? ""

                // Extract any non-standard custom answers
                let standardKeys: Set<String> = [
                    "nationality", "visa_status", "notice_period", "start_date",
                    "earliest_start_date", "current_salary", "expected_salary",
                    "marital_status", "gender", "skillset_pitch"
                ]
                var custom: [String: String] = [:]
                for (k, v) in answers {
                    if !standardKeys.contains(k) {
                        custom[k] = v
                    }
                }
                self.customAnswers = custom
            }
        } catch {
            showStatus("Failed to load profile: \(error.localizedDescription)", isError: true)
        }
        isLoading = false
    }

    public func handleResumeFilePicked(url: URL) async {
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

    public func addExperience(_ experience: Experience) {
        experiences.append(experience)
    }

    public func updateExperience(_ experience: Experience) {
        if let idx = experiences.firstIndex(where: { $0.id == experience.id }) {
            experiences[idx] = experience
        }
    }

    public func deleteExperience(at offsets: IndexSet) {
        experiences.remove(atOffsets: offsets)
    }

    public func saveProfile() async {
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
        current.phoneCountryCode = phoneCountryCode.isEmpty ? "+971" : phoneCountryCode
        current.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        current.city = trimmedCity.isEmpty ? nil : trimmedCity
        current.country = trimmedCountry.isEmpty ? nil : trimmedCountry
        current.location = computedLocation.isEmpty ? nil : computedLocation
        current.linkedinURL = linkedinURL.isEmpty ? nil : linkedinURL
        current.githubURL = githubURL.isEmpty ? nil : githubURL
        current.portfolioURL = portfolioURL.isEmpty ? nil : portfolioURL
        current.experiences = experiences

        // Consolidate standard and custom screening answers
        var combinedAnswers = customAnswers
        combinedAnswers["nationality"] = nationality
        combinedAnswers["visa_status"] = visaStatus
        combinedAnswers["notice_period"] = noticePeriod
        combinedAnswers["start_date"] = earliestStartDate
        combinedAnswers["current_salary"] = currentSalary
        combinedAnswers["expected_salary"] = expectedSalary
        combinedAnswers["marital_status"] = maritalStatus
        combinedAnswers["gender"] = gender
        if !skillsetPitch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            combinedAnswers["skillset_pitch"] = skillsetPitch.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        current.answersJSON = combinedAnswers
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
