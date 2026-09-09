import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let supabaseURL = URL(string: "https://ihfdrxfkkcgfnxrlgpuj.supabase.co")!
        // Anon key for client-side queries
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImloZmRyeGZra2NnZm54cmxncHVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5NDQxMTAsImV4cCI6MjEwNDUyMDExMH0.xas4Z7YNcbq4fOniYZKB0PsOeE7CMha03vPUmU3NMvM"

        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }

    // MARK: - Profile Operations

    func fetchLatestProfile() async throws -> Profile? {
        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        return profiles.first
    }

    func saveProfile(_ profile: Profile) async throws {
        try await client
            .from("profiles")
            .upsert(profile)
            .execute()
    }

    // MARK: - Resume Storage Operations

    func uploadResume(fileData: Data, fileName: String) async throws -> String {
        // Clean filename and create unique storage path
        let sanitizedName = fileName.replacingOccurrences(of: " ", with: "_")
        let storagePath = "resumes/\(UUID().uuidString)_\(sanitizedName)"

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
