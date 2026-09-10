import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let supabaseURL = URL(string: "https://ihfdrxfkkcgfnxrlgpuj.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImloZmRyeGZra2NnZm54cmxncHVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5NDQxMTAsImV4cCI6MjEwNDUyMDExMH0.xas4Z7YNcbq4fOniYZKB0PsOeE7CMha03vPUmU3NMvM"

        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }

    // MARK: - Auth Operations

    func sendOTP(email: String) async throws {
        try await client.auth.signInWithOTP(
            email: email,
            redirectTo: nil,
            shouldCreateUser: true
        )
    }

    func verifyOTP(email: String, token: String) async throws {
        try await client.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
    }

    func getCurrentUser() async -> User? {
        return try? await client.auth.session.user
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Profile Operations

    func fetchCurrentProfile() async throws -> Profile? {
        guard let user = try? await client.auth.session.user else {
            return nil
        }

        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: user.id)
            .limit(1)
            .execute()
            .value

        if let existing = profiles.first {
            return existing
        }

        // Initialize default empty profile if none exists
        let newProfile = Profile(id: user.id, email: user.email ?? "")
        try? await saveProfile(newProfile)
        return newProfile
    }

    func saveProfile(_ profile: Profile) async throws {
        try await client
            .from("profiles")
            .upsert(profile)
            .execute()
    }

    // MARK: - Resume Storage Operations

    func uploadResume(fileData: Data, fileName: String) async throws -> String {
        guard let user = try? await client.auth.session.user else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let sanitizedName = fileName.replacingOccurrences(of: " ", with: "_")
        let storagePath = "\(user.id)/\(sanitizedName)"

        try await client.storage
            .from("resumes")
            .upload(
                storagePath,
                data: fileData,
                options: FileOptions(
                    contentType: "application/pdf",
                    upsert: true
                )
            )

        return storagePath
    }

    func getSignedResumeURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        return try await client.storage
            .from("resumes")
            .createSignedURL(path: path, expiresIn: expiresIn)
    }
}
